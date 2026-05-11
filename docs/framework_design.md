# VRF Framework Design

## Overview

VRF is a lightweight, SystemVerilog verification framework inspired by UVM. It preserves
the architectural value of UVM — component hierarchy, phasing, stimulus sequences,
transaction-level monitoring — while deliberately omitting the complexity that makes UVM
difficult to understand, maintain, and extend.

The framework is designed around a UART DUT as the initial verification target, with
planned support for AXI, Avalon, and eventually HDMI interfaces.

---

## Design Philosophy

- **Design first** — interfaces and data structures are agreed before any code is written
- **Tests second** — tests define expected behavior before implementation
- **Implementation last** — code is written to make tests pass
- **Explicit over implicit** — no runtime string-path lookups, no hidden wiring
- **Simple over general** — complexity is only added when a concrete use case demands it

---

## Explicitly Out of Scope

The following UVM features are intentionally excluded:

| Feature | Reason |
|---------|--------|
| Factory / type overrides | Runtime type substitution adds complexity with limited practical benefit |
| Functional coverage | Not needed for this use case |
| Formal verification | Outside Questa standard license |
| Assertion-based verification | Outside Questa standard license |
| `uvm_config_db` string-path matching | Replaced by a typed, name-keyed registry |
| 12-phase UVM phase schedule | Replaced by four phases: build, connect, run, report |

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
vrf_component
  vrf_driver #(T)        - drives transactions onto the bus via BFM
  vrf_monitor #(T)       - observes bus via BFM; broadcasts transactions
  vrf_sequencer #(T)     - arbitrates sequences; implements get_next_item/item_done
  vrf_agent              - groups driver + sequencer + monitor (active) or monitor only (passive)
  vrf_env                - contains agents and scoreboard; wires analysis connections
  vrf_test               - top of hierarchy; builds env, configures, runs sequences
  vrf_scoreboard         - subscribes to monitors; checks correctness
```

Sequences and sequence items are **not** components — they have no phases and do not
live in the component tree. They run *on* components (sequencers).

```
vrf_sequence_item        - base transaction class
vrf_sequence #(T)        - defines stimulus in body() task; started on a sequencer
```

---

## Phase Mechanism

Four phases execute in order across the entire component tree before the next phase begins:

| Phase | Purpose |
|-------|---------|
| `build` | Instantiate child components |
| `connect` | Wire analysis ports to subscribers |
| `run` | Execute stimulus (blocking; ends via objection mechanism) |
| `report` | Print results and summaries |

`vrf_phase_manager` drives phase execution. It calls each phase method on every
registered component in top-down order (build, connect) or bottom-up order (report), and
manages the objection count for `run`.

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
abstract BFM class. This follows the pattern described in *"Abstract BFMs Outshine Virtual
Interfaces for Advanced SystemVerilog Testbenches"* (Rich & Bromley, DVCon 2008).

**Structure:**

- An abstract base class (e.g., `uart_bfm`) is declared in a package. It contains only
  `pure virtual` tasks defining the protocol API — no signal references.
- The `interface` declares the bus signals, a `default clocking` block for timing
  abstraction, and a concrete class extending the abstract BFM. The concrete class
  implements the API using signals directly in scope.
- An instance of the concrete class is created inside the interface at elaboration.
- The driver and monitor hold a handle of the abstract base class type. They call
  protocol methods (e.g., `bfm.send_byte()`) without any knowledge of signal names.

**Handle delivery:**

The concrete BFM handle is registered in `vrf_config_db` by the interface's `initial`
block at time zero. The driver and monitor retrieve it by type and name during `build`.

**Clocking blocks:**

Every interface uses a `default clocking` block. The concrete BFM implementation uses
`##n` cycle notation for all timing. Nanosecond-level timing details do not appear
anywhere in the class-based testbench.

---

## Active and Passive Agents

`vrf_agent` supports two modes controlled by a flag in the agent's config object:

| Mode | Contents | Use case |
|------|----------|---------|
| Active | sequencer + driver + monitor | Driving stimulus onto a bus the testbench controls |
| Passive | monitor only | Observing a bus driven by the DUT or another agent |

A single testbench may contain both modes simultaneously (e.g., active agent driving the
UART RX pin; passive agent monitoring the UART TX pin).

---

## Sequence / Sequencer / Driver Handshake

Stimulus is generated by sequence objects that run on a sequencer:

1. A sequence's `body()` task creates transaction items and calls `start_item()` /
   `finish_item()` on the sequencer
2. The driver calls `get_next_item(item)` — blocks until a transaction is available
3. The driver passes the transaction to the BFM to drive on the bus
4. The driver calls `item_done()` — signals completion back to the sequence

This explicit handshake solves the "when is the driver done?" problem that arises with
mailbox-only approaches.

Sequences are composable: a `uart_send_two_frames_seq` can instantiate and start a
`uart_send_frame_seq` twice. A test reduces to: create config, start the right sequence.

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

---

## Configuration

### `vrf_config_db #(T)`

A static, parameterized class that acts as a typed object registry. Each type
specialization has independent storage. Objects are stored and retrieved by a short name
string (not a hierarchical path).

```
vrf_config_db #(uart_bfm)::set("uart0", bfm_handle);   // interface initial block
vrf_config_db #(uart_bfm)::get("uart0", bfm_handle);   // driver build phase
```

This replaces UVM's `uvm_config_db`. There are no wildcard path matches, no runtime
scope resolution, and no silent failures from path mismatches. A `get()` call either
finds the name or returns a fatal error (or a status flag — TBD at implementation).

Primary contents:
- Abstract BFM handles (registered by interfaces, retrieved by drivers/monitors)
- Agent config objects (registered by the test, retrieved by agents)

### Config Objects

Each agent type has a typed config object (e.g., `uart_agent_config`) that carries all
parameters needed to configure that agent: protocol settings (baud rate, data width,
etc.) and testbench settings (active vs. passive).

The test creates config objects, populates them, and stores them in `vrf_config_db`.
Agents retrieve them during `build`.

### DUT Initialization

Configuring the DUT's registers is done via an initialization sequence (e.g.,
`uart_init_seq`). This sequence reads the same config object used to configure the
agent, ensuring the BFM and the DUT are always configured identically from a single
source of truth. The init sequence is protocol-specific and lives in the protocol agent
package, not the framework.

---

## Logger

`vrf_logger` is a singleton static class providing simulation-wide logging with two
independent controls:

- **Severity:** `DEBUG`, `INFO`, `WARNING`, `ERROR`, `FATAL`. Higher severities cannot
  be suppressed. `FATAL` halts simulation.
- **Per-component verbosity threshold:** Each `vrf_component` carries a verbosity level.
  Messages below the component's threshold are dropped before reaching the logger output.

```
vrf_logger::set_verbosity("uart_driver", DEBUG);    // verbose for this component
vrf_logger::set_verbosity("axi_agent.*", WARNING);  // quiet for all AXI components
```

Output destinations: console, file, or both simultaneously.

---

## Package Structure

```
vrf_pkg                  - all framework base classes (vrf_component, vrf_driver, etc.)
                           vrf_config_db, vrf_logger, vrf_phase_manager, vrf_objection
                           vrf_analysis_port, vrf_subscriber

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
