# VRF Framework Design

## Overview

VRF is a lightweight, SystemVerilog verification framework inspired by UVM. It preserves
the architectural value of UVM - component hierarchy, phasing, stimulus sequences,
transaction-level monitoring - while deliberately omitting the complexity that makes UVM
difficult to understand, maintain, and extend.

The framework is designed around a UART DUT as the initial verification target, with
planned support for AXI, Avalon, and eventually HDMI interfaces.

---

## Design Philosophy

- **Design first** - interfaces and data structures are agreed before any code is written
- **Tests second** - tests define expected behavior before implementation
- **Implementation last** - code is written to make tests pass
- **Explicit over implicit** - no runtime string-path lookups, no hidden wiring
- **Simple over general** - complexity is only added when a concrete use case demands it

---

## Explicitly Out of Scope

The following UVM features are intentionally excluded:

| Feature                              | Reason                                                                   |
| ------------------------------------ | ------------------------------------------------------------------------ |
| Factory / type overrides             | Runtime type substitution adds complexity with limited practical benefit |
| Functional coverage                  | Not needed for this use case                                             |
| Formal verification                  | Outside Questa standard license                                          |
| Assertion-based verification         | Outside Questa standard license                                          |
| `uvm_config_db` string-path matching | Replaced by a typed, name-keyed registry                                 |
| 12-phase UVM phase schedule          | Replaced by five phases: build, config, connect, run, report             |

---

## Tooling

- **Language:** SystemVerilog (IEEE 1800)
- **Simulator:** Questa (standard license)
- **OOP model:** Full use of SV classes, virtual classes, parameterized classes, inheritance

---

## Naming Convention

All framework base classes use the `vrf_` prefix. Protocol-specific classes (e.g., UART,
AXI) use their own prefix and live in separate packages.

---

## Component Hierarchy

All components extend `vrf_component` and participate in the phase mechanism.

```
vrf_root                 - hidden singleton; root of the component tree; parent of vrf_test
  vrf_test               - top of user hierarchy; builds env, configures, runs sequences
    vrf_env              - contains agents and scoreboard; wires analysis connections
      vrf_agent          - groups driver + sequencer + monitor (active) or monitor only (passive)
        vrf_driver #(T)  - drives transactions onto the bus via BFM
        vrf_monitor #(T) - observes bus via BFM; broadcasts transactions
        vrf_sequencer #(T) - arbitrates sequences; implements get_next_item/item_done
      vrf_scoreboard     - subscribes to monitors; checks correctness
```

`vrf_root` mirrors UVM's hidden `uvm_top`. It is never instantiated by user code - the
bootstrap creates it, instantiates the test as its child, and passes it to
`vrf_phase_manager`. This ensures the test has a parent and phase traversal has a
single known root.

Sequences and sequence items are **not** components - they have no phases and do not
live in the component tree. They run _on_ components (sequencers).

```
vrf_sequence_item        - base transaction class
vrf_sequence #(T)        - defines stimulus in body() task; started on a sequencer
```

---

## Phase Mechanism

Five phases execute in order across the entire component tree before the next phase begins:

| Phase     | Purpose                                                   | Order     |
| --------- | --------------------------------------------------------- | --------- |
| `build`   | Instantiate child components                              | top-down  |
| `config`  | Retrieve configuration from `vrf_config_db`               | top-down  |
| `connect` | Wire analysis ports to subscribers                        | top-down  |
| `run`     | Execute stimulus (blocking; ends via objection mechanism) | top-down  |
| `report`  | Print results and summaries                               | bottom-up |

`vrf_phase_manager` drives phase execution by walking the component tree from `vrf_root`.
It recursively visits each component, calling the phase method on a parent before
descending to its children (top-down), or after (bottom-up). This makes phase execution
order a structural property of the component hierarchy, not dependent on construction
order.

Each component registers itself with its parent at construction by adding itself to the
parent's child list. `vrf_phase_manager` traverses this tree; components do not
self-register with the manager directly.

---

## Objection Mechanism

The `run` phase ends when all raised objections have been dropped. This avoids hardcoded
simulation delays or polling.

- A component calls `raise_objection()` before it has work to do
- A component calls `drop_objection()` when it is finished
- `vrf_phase_manager` monitors the outstanding count and ends `run` when it reaches zero

`vrf_objection` encapsulates raise/drop logic. Components interact with it through their
base class.

---

## Abstract BFM Pattern

Drivers and monitors never reference signals directly. Instead they operate through an
abstract BFM class. This follows the pattern described in _"Abstract BFMs Outshine Virtual
Interfaces for Advanced SystemVerilog Testbenches"_ (Rich & Bromley, DVCon 2008).

**Structure:**

- An abstract base class (e.g., `uart_bfm`) is declared in a package. It contains only
  `pure virtual` tasks defining the protocol API - no signal references.
- The `interface` declares the bus signals, a `default clocking` block for timing
  abstraction, and a concrete class extending the abstract BFM. The concrete class
  implements the API using signals directly in scope.
- An instance of the concrete class is created inside the interface at elaboration.
- The driver and monitor hold a handle of the abstract base class type. They call
  protocol methods (e.g., `bfm.send_byte()`) without any knowledge of signal names.

**Handle delivery:**

The concrete BFM handle is passed into the driver and monitor via their constructors.
`tb.sv` creates the concrete BFM instance (or retrieves it from the interface) and
supplies it at elaboration time. This avoids any dependency on `vrf_config_db` for
handle delivery.

**Clocking blocks:**

Every interface uses a `default clocking` block. The concrete BFM implementation uses
`##n` cycle notation for all timing. Nanosecond-level timing details do not appear
anywhere in the class-based testbench.

---

## Active and Passive Agents

`vrf_agent` supports two modes controlled by a flag in the agent's config object:

| Mode    | Contents                     | Use case                                           |
| ------- | ---------------------------- | -------------------------------------------------- |
| Active  | sequencer + driver + monitor | Driving stimulus onto a bus the testbench controls |
| Passive | monitor only                 | Observing a bus driven by the DUT or another agent |

A single testbench may contain both modes simultaneously (e.g., active agent driving the
UART RX pin; passive agent monitoring the UART TX pin).

---

## Sequence / Sequencer / Driver Handshake

Stimulus is generated by sequence objects that run on a sequencer:

1. A sequence's `body()` task creates a transaction item, populates its outbound fields,
   and calls `start_item()` / `finish_item()` on the sequencer
2. The driver calls `get_next_item(item)` - blocks until a transaction is available
3. The driver passes the transaction to the BFM to drive on the bus
4. The driver populates any response or status fields on the same transaction item
5. The driver calls `item_done()` - signals completion back to the sequence
6. The sequence resumes after `finish_item()` and may inspect response fields on the item

`item_done()` takes no response argument. The driver and sequence share a handle to the
same transaction object; the driver writes response data into it before calling
`item_done()`, and the sequence reads those fields immediately after `finish_item()`
returns.

This explicit handshake solves the "when is the driver done?" problem that arises with
mailbox-only approaches.

Sequences are composable: a `uart_send_two_frames_seq` can instantiate and start a
`uart_send_frame_seq` twice. A test reduces to: create config, start the right sequence.

### Virtual Sequences

When a test must coordinate stimulus across multiple interfaces simultaneously, a virtual
sequence handles the coordination. A virtual sequence extends `vrf_sequence` and holds
handles to multiple real sequencers. Its `body()` starts sub-sequences on those
sequencers directly, using fork/join as needed.

A virtual sequence runs on a null sequencer - a `vrf_sequencer` instantiated with no
driver attached. The null sequencer is a placeholder to satisfy the type system; the
virtual sequence never actually uses it for item handshake.

No additional framework machinery is required beyond `vrf_sequence::start()` accepting
a sequencer handle and sequences being startable from within another sequence's `body()`.

---

## Component Naming

Every `vrf_component` knows its full hierarchical path. The path is derived at
construction from the parent's path and the local name passed to the constructor:

```
// parent path "env.uart_agent" + local name "driver" -> full path "env.uart_agent.driver"
```

`vrf_root` has the fixed path `"root"`. The test's path is `"root.<test_name>"`. All
descendant paths follow from there. The full path is used in logger output and as the
key convention for `vrf_config_db` lookups.

---

## Simulation Bootstrap

`tb.sv` reads the `+testname` plusarg and delegates to `vrf_test_registry`:

1. `tb.sv` calls `vrf_phase_manager::run_test(name)` (or equivalent entry point)
2. The entry point creates `vrf_root`
3. `vrf_test_registry::create(name, vrf_root)` constructs the named test as a child
   of `vrf_root`
4. `vrf_phase_manager` walks the tree from `vrf_root` and drives all five phases

`vrf_test_registry` is a static name-to-constructor map. Each test class registers
itself by name using a static initializer or macro in its include file. There are no
type overrides - the registry maps names to constructors only.

A `+config` plusarg selects the active configuration object by name using the same
include-file self-registration pattern.

---

## Analysis Ports and Subscribers

Monitors broadcast observed transactions to any number of subscribers using the observer
pattern. Monitors do not know who is listening; subscribers do not know which monitor
fed them.

**`vrf_analysis_port #(T)`**

- Owned by a monitor
- Holds a list of registered subscribers
- `write(T item)` iterates the list and calls `write()` on each subscriber

**`vrf_subscriber #(T)`**

- Abstract base class with one pure virtual method: `write(T item)`
- Implemented by: `vrf_scoreboard`, logger adapters, and any other consumer
- Subscribers register with an analysis port during `connect` phase

**`vrf_scoreboard`**

- Extends `vrf_subscriber`
- `write(T item)` is pure virtual - the user implements all checking and comparison
  logic; expected value computation is always protocol-specific and lives in the
  concrete subclass
- Provides `pass()` and `fail()` methods that increment internal counters and log at
  INFO and ERROR severity respectively; called by the user from within `write()`
- Provides a default `report_phase()` that prints a standardized pass/fail summary;
  may be overridden for custom reporting

---

## Configuration

### `vrf_config_db #(T)`

A static, parameterized class that acts as a typed object registry. Each type
specialization has independent storage. Objects are stored and retrieved using a
component handle and a short field name string. The composite key is
`(type, path, field_name)` where path is derived internally from
`cntxt.get_full_name()`.

```
vrf_config_db #(uart_agent_config)::set(m_uart_agent, "cfg", uart_cfg);   // test build phase
vrf_config_db #(uart_agent_config)::get(this,         "cfg", m_cfg);      // agent config phase
```

This replaces UVM's `uvm_config_db`. There are no wildcard path matches and no runtime
scope resolution. On a miss, `get()` logs a WARNING and returns 0; the caller decides
whether to treat the miss as fatal. `set()` during `build` phase registers entries;
`get()` during `config` phase retrieves them, guaranteeing all entries exist before any
lookup occurs. A null context writes to a flat global namespace accessible to any caller.

Primary contents:

- Agent config objects (registered by the test during `build`, retrieved by agents during `config`)

### Config Objects

Each agent type has a typed config object (e.g., `uart_agent_config`) that carries all
parameters needed to configure that agent: protocol settings (baud rate, data width,
etc.) and testbench settings (active vs. passive).

The test creates config objects, populates them, and stores them in `vrf_config_db`
during `build` phase. Agents retrieve them during `config` phase.

### DUT Initialization

Configuring the DUT's registers is done via an initialization sequence (e.g.,
`uart_init_seq`). This sequence reads the same config object used to configure the
agent, ensuring the BFM and the DUT are always configured identically from a single
source of truth. The init sequence is protocol-specific and lives in the protocol agent
package, not the framework.

---

## Logger

`vrf_logger` is a singleton static class providing simulation-wide logging with two
independent axes:

- **Severity:** `LOG_INFO`, `LOG_WARN`, `LOG_ERROR`, `LOG_FATAL`. Higher severities
  cannot be suppressed. `LOG_FATAL` halts simulation.
- **Verbosity:** `LOG_NONE`, `LOG_LOW`, `LOG_MEDIUM`, `LOG_HIGH`, `LOG_FULL`,
  `LOG_DEBUG`. Controls filtering of `LOG_INFO` messages. Default threshold is
  `LOG_MEDIUM`. The logger owns one override table keyed by hierarchical name strings,
  populated from plusargs at initialization and never modified after that. Components
  are not responsible for storing their own verbosity level. `LOG_WARN`, `LOG_ERROR`,
  and `LOG_FATAL` are never suppressed by verbosity.

```
vrf_logger::get_inst().set_verbosity("root.env.uart_agent.driver", LOG_DEBUG);  // verbose for this component
vrf_logger::get_inst().set_verbosity("root.env.axi_agent",         LOG_NONE);   // quiet for all AXI components
```

The second call covers all descendants of `root.env.axi_agent` via the parent-walk
lookup; no per-component entries are needed.

Output destinations: console, file, or both simultaneously.

---

## Package Structure

```
vrf_pkg                  - all framework base classes (vrf_component, vrf_driver, etc.)
                           vrf_config_db, vrf_logger, vrf_phase_manager, vrf_objection
                           vrf_analysis_port, vrf_subscriber, vrf_scoreboard
                           vrf_root, vrf_test_registry

uart_bfm_pkg             - abstract uart_bfm class (pure virtual tasks only)
uart_agent_pkg           - uart_agent_config, uart_agent, uart_driver, uart_monitor,
                           uart_sequencer, uart_sequence_item, uart_init_seq, sequences

axi_bfm_pkg              - abstract axi_bfm class
axi_agent_pkg            - axi agent, driver, monitor, config, sequences

<dut>_tb_pkg             - DUT-specific env, scoreboard, test classes
```

Interfaces (with concrete BFM implementations) are separate design units, not packages.

---

## Layer Boundary

The critical boundary is between the framework layer and protocol-specific layers:

```
framework layer    vrf_component, vrf_sequence, vrf_config_db, ...
      |
protocol layer     uart_bfm, uart_driver, uart_agent_config, uart_init_seq, ...
      |
DUT layer          <dut>_env, <dut>_scoreboard, <dut>_test, ...
```

No framework class may reference any protocol-specific type. Protocol classes extend
framework base classes but the framework has no knowledge of them.
