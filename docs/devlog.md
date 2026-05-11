# VRF Development Log

---

## Session 2  -  2026-05-11

### What Was Decided

- **SVUnit** added as a shallow submodule at `extern/svunit`, pinned to `v3.38.1`.
  This is the test runner for VRF unit tests.
- **UVM 1800.2-2020** added as a shallow submodule at `extern/uvm`. Read-only
  reference for resolving design decisions  -  not compiled or run.
- Both fetched via `git submodule update --init`. Neither is loaded at session
  start.
- CLAUDE.md updated with context loading protocol and ASCII-only rule.

### Open Design Decisions

The six decisions from Session 1 remain open. No progress made this session.

### Next Steps

(same as Session 1)

---

## Session 1  -  2026-05-10

### What Was Decided

A full design session establishing the framework architecture. All decisions are
captured in detail in `docs/framework_design.md`. Summary:

- **Language / tooling:** SystemVerilog, Questa standard license
- **Prefix:** `vrf_` for all framework base classes
- **No factory**  -  explicit instantiation only
- **No coverage**  -  out of scope entirely
- **Abstract BFM pattern**  -  concrete BFM lives in the interface alongside signals and
  a clocking block; drivers/monitors hold an abstract class handle; no virtual interfaces
- **4 phases:** build, connect, run, report
- **Objection mechanism** for run-phase termination
- **Sequencer/driver handshake:** `get_next_item` / `item_done`
- **Analysis ports + subscribers:** observer pattern; monitors broadcast, scoreboard and
  logger subscribe
- **Active and passive agents** both supported
- **`vrf_config_db #(T)`:** static, typed, keyed by short name string  -  no hierarchical
  path matching
- **`vrf_logger`:** singleton, severity levels + per-component verbosity threshold,
  console and/or file output
- **Config objects** as single source of truth: testbench and DUT init sequence both
  read the same config object
- **Layer boundary:** framework -> protocol agent -> DUT-specific; no upward dependencies

---

### Open Design Decisions

These need to be resolved before writing tests or implementation code for the
corresponding components.

**1. Phase propagation**
How does `vrf_phase_manager` discover all components? Options:
- Components self-register with the phase manager at construction
- Phase manager walks the component tree top-down from a known root

Decision affects: `vrf_component` constructor, `vrf_phase_manager` interface.

**2. Component naming and path**
How are component names assigned and does a component know its full hierarchical path?
- Constructor argument (parent + local name -> derived path)?
- Or flat name only?

Decision affects: `vrf_component` constructor, logger output format, config_db name
conventions.

**3. Virtual sequences**
When a test needs to coordinate stimulus across multiple interfaces simultaneously (e.g.,
AXI + UART + register bus), where does that coordination live? UVM uses a virtual
sequence running on a null sequencer. VRF needs a pattern for this.

Decision affects: `vrf_sequence` interface, whether a null sequencer is needed.

**4. Simulation bootstrap**
How does simulation start? UVM calls `run_test("test_class_name")` from the top module.
VRF needs an equivalent entry point that constructs the test object, triggers phases,
and hands control to the framework.

Decision affects: top-level module structure and `vrf_phase_manager` startup.

**5. Response items**
Some protocols return response data from the driver back to the sequence (e.g., AXI
BRESP, register read data). Does `item_done()` carry a response object, or is response
handling out of scope for the initial framework?

Decision affects: `vrf_sequencer` and `vrf_driver` interfaces.

**6. Scoreboard base class interface**
What does `vrf_scoreboard` actually provide beyond being a subscriber? Options:
- Just a base class with `write()`  -  user implements all checking logic
- A predict/compare pattern  -  scoreboard has a `predict(item)` and `check(item)` split
- Something else

Decision affects: `vrf_scoreboard` interface and how tests wire up checking.

---

### Next Steps

1. Resolve the six open design decisions above
2. Define the `vrf_component` base class interface (fields, constructor signature,
   phase method signatures)
3. Define `vrf_sequence_item` base class
4. Define `vrf_config_db` interface
5. Write tests for `vrf_component` before implementing it
