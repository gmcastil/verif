# VRF Development Log

---

## Session 6  -  2026-05-14

### What Was Decided

- **Logger macro split: `log_*` vs `report_*`.**
  Two macro families cover all four severities (info, warn, error, fatal):
  - `log_*` macros are for class scope. They insert `this.get_full_name()` automatically
    as the name argument; the caller never touches the name string.
  - `report_*` macros are for module and interface scope where `this` does not exist.
    The caller supplies an explicit string literal as the first argument.

- **String interface retained; `vrf_object` base class rejected.**
  The idea of a `vrf_object` base class with `get_full_name()` was explored as a way to
  prevent callers from logging under false names. It was rejected: the masquerade
  problem is theoretical for an internal verification tool, and the string interface is
  simpler and more uniform. The `log_*` macros enforce honest naming for all class-based
  code by inserting `this.get_full_name()` at the call site; direct calls to
  `vrf_logger::log()` with an arbitrary string are the designated back door for
  non-class contexts.

- **Sequences require `get_full_name()`.**
  The `log_*` macros rely on `this.get_full_name()` compiling in sequence `body()` tasks.
  `vrf_sequence` must therefore carry a name field set at construction and expose
  `get_full_name()`. For sequences the method returns a flat name (e.g.,
  `"uart_send_frame_seq"`), not a hierarchical path.

### Open Design Decisions

- `get_full_name()` vs `get_full_path()` - exact method name not yet pinned.

### Next Steps

1. Write SVUnit tests for `vrf_logger`
2. Implement `vrf_logger`
3. Define `vrf_component` base class interface
4. Define `vrf_sequence_item` base class
5. Define `vrf_objection` interface
6. Add `make docs` target to Makefile
7. Write tests for `vrf_config_db`
8. Design `+config` mechanism (future session)

---

## Session 5  -  2026-05-13

### What Was Decided

- **`vrf_logger` design finalized (interface TBD, next step this session).**
  Two orthogonal axes: severity (`INFO/WARNING/ERROR/FATAL`) and verbosity
  (`LOG_NONE/LOG_LOW/LOG_HIGH/LOG_TRACE`). The binary enable flag from Session 4
  is replaced by the verbosity axis with four levels. `ERROR` and `FATAL` are
  immune to verbosity suppression. A compiled-in global default applies when no
  other entry matches.

- **Verbosity table lives in the logger, not on components.**
  The logger owns two associative arrays keyed by hierarchical name strings.
  Components pass their full name string on every log call; the logger does the
  lookup. No per-component report handler object. No circular dependency with
  `vrf_component`. Usable from sequences and other non-component code.

- **Two-table override model.**
  - User table: populated by components during `config` phase by calling
    `vrf_logger::set_verbosity(name, level)`. Agents set their own entry using
    the verbosity field from their config object.
  - Override table: populated at time zero by parsing plusargs. Never modified
    after that. Lookup checks override table first, then user table, with parent
    walk applied to both. Override table always wins.

- **Plusarg format.**
  `+vrf_verbosity=LOG_LOW` sets the global default. `+vrf_set_verbosity=<path>:<level>`
  sets a per-component override; repeatable for multiple entries.

- **Parent walk on name strings.**
  Verbosity lookup strips the trailing `.component` segment iteratively until a
  match is found or the string is exhausted. Same parent-walk idea as
  `vrf_config_db`. The empty string signals exhaustion; fall back to global
  default.

- **Config object pattern clarified.**
  Config objects are plain SV classes, not structs (reference semantics needed
  for config_db). Test creates env config with top-level settings. Env creates
  agent configs from the env config during `config` phase and registers them in
  `vrf_config_db` under agent names. Agents retrieve their own config and call
  `vrf_logger::set_verbosity` using the verbosity field on the config object.

- **`vrf_logger` interface spec written.** Full spec at `docs/vrf_logger.md`.
  Enums: `vrf_severity_e` (`LOG_INFO/LOG_WARN/LOG_ERROR/LOG_FATAL`) and
  `vrf_verbosity_e` (`LOG_NONE/LOG_LOW/LOG_HIGH/LOG_DEBUG`). Public interface:
  `log(name, severity, verbosity, msg, filename, line_number)` and
  `set_verbosity(name, level)`. Output format matches UVM: full hierarchical path,
  file/line on every message, raw `$time`. `is_enabled()` pre-check dropped as
  premature optimization. Log file via `+vrf_log_file=<path>` plusarg.

- **`+config` mechanism noted as unspecified.**
  The `+config` plusarg (mentioned in `framework_design.md`) is intended to
  separate configuration data from test behavior but has not been fully
  designed. Flagged for a future design session.

### Open Design Decisions

None from this session.

### Next Steps

1. Write SVUnit tests for `vrf_logger`
2. Implement `vrf_logger`
3. Define `vrf_component` base class interface
4. Define `vrf_sequence_item` base class
5. Define `vrf_objection` interface
6. Add `make docs` target to Makefile
7. Write tests for `vrf_config_db`
8. Design `+config` mechanism (future session)

---

## Session 4  -  2026-05-12

### What Was Decided

- **Five phases, not four.** A `config` phase is inserted between `build` and
  `connect`. Phase order is: build -> config -> connect -> run -> report.
  `build` strictly constructs the component hierarchy. `config` is where each
  component retrieves its configuration from `vrf_config_db`. This separation
  guarantees all entries are registered before any component calls `get`.

- **`vrf_config_db` interface finalized.**
  Three-argument interface: `set(cntxt, field_name, value)` and
  `get(cntxt, field_name, value)`. `cntxt` is a component handle; the database
  derives the path via `get_full_name()` internally. No `inst_name` argument, no
  wildcards. Parent walk retained: `get` walks the ancestry chain on miss; most
  specific entry wins. This enables reusable components (e.g. Avalon BFM) to
  always look up the same field name regardless of how many instances exist.
  Null context writes to a flat global namespace. `set` overwrites on collision
  and logs a WARNING. `get` logs a WARNING on miss and returns 0; caller decides
  fatality. BFM handles are passed via constructors from `tb.sv`, not config_db.
  Full spec in `docs/vrf_config_db.md`.

- **`vrf_logger` design direction established (spec TBD, next session).**
  Two orthogonal controls: severity threshold (DEBUG/INFO/WARNING/ERROR/FATAL)
  and a per-component enable flag (binary on/off). Both driven by plusargs at
  simulation startup - no recompilation needed. Logger owns a verbosity table
  mapping name strings to levels; components pass their full hierarchical name
  string, not a handle. No circular dependency with `vrf_component`. Parent walk
  applies to verbosity lookup - if a component has no specific entry, walk up the
  name path to find an ancestor entry or fall back to global default. Enable flag
  allows silencing everything except one targeted component, solving the
  grep-chain problem encountered in practice. Usable from non-component code
  (sequences, sequence items) via any identifying name string.

- **Documentation structure established.**
  One markdown file per framework component under `docs/`. Files use `##` as the
  top-level header. `make docs` assembles them into a single combined document.
  `docs/preamble.md` carries the `#` title. `docs/framework_design.md` will
  eventually be decomposed into per-component files as specs mature.

### Open Design Decisions

None from this session.

### Next Steps

1. Define `vrf_component` base class interface
2. Define `vrf_sequence_item` base class
3. Define `vrf_logger` interface (prerequisite for `vrf_component`)
4. Define `vrf_objection` interface (prerequisite for `vrf_component`)
5. Add `make docs` target to Makefile
6. Write tests for `vrf_config_db`

---

## Session 3  -  2026-05-11

### What Was Decided

- **Decision #1 resolved: phase propagation via tree walk from a known root.**
  `vrf_phase_manager` holds a reference to `vrf_root` and walks the component tree
  top-down (build, connect) or bottom-up (report). Execution order is a structural
  property of the hierarchy, not dependent on construction order.

- **`vrf_root` singleton introduced.**
  Mirrors UVM's hidden `uvm_top`. The test object is a child of `vrf_root`, not a
  parentless root itself. The bootstrap entry point creates `vrf_root`, instantiates
  the test as its child, and passes `vrf_root` to the phase manager.

- **Decision #2 resolved: hierarchical naming path.**
  Components know their full hierarchical path, derived from parent name + local name
  at construction. Details TBD when `vrf_component` interface is defined.

- **Decision #6 resolved: vrf_scoreboard provides pass/fail infrastructure.**
  `vrf_scoreboard` extends `vrf_subscriber`. `write(T item)` is pure virtual --
  the user implements all checking and comparison logic. The base class provides
  `pass()` and `fail()` methods that increment counters and log at INFO/ERROR
  respectively, and a default `report_phase()` that prints a standardized
  pass/fail summary. Expected value computation is always user responsibility.

- **Decision #5 resolved: item_done() carries no response argument.**
  The driver populates status and response fields directly on the transaction item
  before calling item_done(). The sequence checks those fields after finish_item()
  returns. No separate response channel or second sequencer queue needed.

- **Decision #3 resolved: virtual sequences follow the UVM pattern.**
  A virtual sequence extends `vrf_sequence` and holds handles to real sequencers.
  It runs on a null sequencer -- a `vrf_sequencer` instantiated with no driver
  attached. No new framework machinery required beyond `vrf_sequence::start()`
  accepting a sequencer handle and sequences being startable from within `body()`.

- **Decision #4 partially resolved: simulation bootstrap.**
  The entry point creates `vrf_root`, instantiates the named test class as a child of
  it, and calls `vrf_phase_manager::run(vrf_root)`. Full interface TBD.

### Open Design Decisions

None. All six decisions resolved this session.

### Next Steps

(same as Session 1, minus decisions #1, #2, and #4)

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
