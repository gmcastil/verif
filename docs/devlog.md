# VRF Development Log

---

## Session 9  -  2026-05-19

### What Was Decided

- **Basic unit test suite for `vrf_logger` completed.**
  All eight tests in `vrf_logger_basic_unit_test.sv` are passing. Tests call `log()`
  directly (no macros) and assert against `last_msg()` using `FAIL_UNLESS_STR_EQUAL`.

- **`last_msg()` retains the previous value on a suppressed call.**
  A suppressed `log()` call returns immediately without touching `m_last_msg`. The
  suppression tests verify this by asserting the previous message is still held after
  a suppressed call.

- **Log file closed in `summarize()`, not `reset()`.**
  `summarize()` is the natural end of the logger lifecycle. `reset()` only nulls
  `m_inst`; file cleanup belongs with the final output.

- **`$fatal(1)` called from within `log()` for `LOG_FATAL`.**
  The log file is closed before `$fatal(1)`. This is the sole point of early
  termination in the framework.

- **`get_threshold()` renamed to `get_verbosity(name)`.**
  More caller-facing: returns the verbosity level that applies to the named component.

- **`parse_set_verbosity()` renamed to `populate_override_table(entries)`.**
  Name describes what it produces, not how. Called once from `new()` when
  `+vrf_set_verbosity` is present. `entries` is the raw comma-delimited string.

- **`severity_to_str()`, `get_verbosity()`, `populate_override_table()` are all `local`.**
  Implementation details with no reason to be visible outside the class.

### Open Design Decisions

None.

### Next Steps

1. Implement `get_verbosity()` and `populate_override_table()`
2. Replace direct `m_global_default` reference in `log()` with `get_verbosity(name)`
3. Implement `summarize()`
4. Make `severity_to_str()` `local`
5. Clean up remaining comments in `vrf_logger.svh`
6. Fill in `vrf_logger_verbosity_none_unit_test.sv` test bodies
7. Fill in `vrf_logger_set_verbosity_unit_test.sv` test bodies
8. Define `vrf_component` base class interface
9. Define `vrf_sequence_item` base class
10. Define `vrf_objection` interface
11. Add `make docs` target to Makefile
12. Write tests for `vrf_config_db`
13. Design test factory for runtime test selection
14. Design `+config` mechanism (future session)

---

## Session 8  -  2026-05-18

### What Was Decided

- **Verbosity levels reworked to match UVM.**
  `vrf_verbosity_e` gains two new levels (`LOG_MEDIUM`, `LOG_FULL`) and explicit integer
  values (0-5). Full set: `LOG_NONE=0`, `LOG_LOW=1`, `LOG_MEDIUM=2`, `LOG_HIGH=3`,
  `LOG_FULL=4`, `LOG_DEBUG=5`. Semantics: LOW for key milestones (start/end of test,
  major phase events), MEDIUM for general messages, HIGH for per-transaction detail,
  FULL for state dumps, DEBUG for trace-level internal state. Global default threshold
  changed from `LOG_LOW` to `LOG_MEDIUM`.

- **`get_severity_count()` added to the main public interface.**
  Not placed under `ifdef VRF_SVUNIT`. Rationale: the counts must already exist as
  internal state for `summarize()` to work; `get_severity_count()` just exposes that
  state via an accessor with no additional storage. Only messages that pass the
  verbosity filter and are actually emitted are counted; suppressed messages are not.

- **Output format documented as an annotated example.**
  The format section now shows a single example string with a field-by-field table
  (severity, file/line, sim time, context, ID tag, message). All four severities
  produce the same format.

- **`$timeformat` behavior settled.**
  The logger uses `%t` and inherits whatever `$timeformat` the simulation environment
  has set. The logger does not call `$timeformat` and has no mechanism to detect
  whether it has been set. If unset, the simulator default applies (tool-dependent,
  typically no unit suffix and wide padding). Testbenches set `$timeformat` in `tb.sv`;
  SVUnit tests set it in `setup()`. Documented as a recommendation, not enforced.

- **Test factory identified as a future design item.**
  The "build once, run many" constraint requires runtime test selection without
  recompilation. Without the UVM factory, a lightweight test registry (string-to-
  constructor map, self-registration macro, `+vrf_testname` plusarg) is the planned
  approach. Needs a dedicated design session before the bootstrap mechanism can be
  finalized. Does not block logger work.

- **`vrf_logger` independence from `vrf_component` confirmed.**
  Unlike UVM where `uvm_info` macros require a `uvm_report_object` context, the VRF
  logger takes a plain name string and has no dependency on `vrf_component`. The
  masquerade risk (a caller lying about their name) is acceptable for an internal tool;
  the `log_*` macros enforce honest naming for all class-based code. Direct calls to
  `log()` are the intentional back door for non-class contexts.

- **Verbosity filtering is LOG_INFO-only; LOG_NONE semantics clarified.**
  WARN, ERROR, and FATAL bypass the verbosity filter entirely -- they are never
  compared against the threshold and always emit. The previous spec described this
  by fixing their verbosity to LOG_NONE (0), which was an implementation leak that
  created confusing dual semantics for LOG_NONE. The correct model: the verbosity
  check is skipped for any severity other than INFO. LOG_NONE as a threshold cleanly
  means "suppress all INFO output from this component." No special-case value needed.

- **Intended verbosity usage model clarified; user table removed.**
  The primary use case for per-component verbosity is: set the global default to
  `LOG_NONE` or `LOG_LOW`, then selectively raise verbosity for the components under
  active development or investigation. Fine-grained filtering of a fully-verbose log is
  handled by the `[id]` field via grep, not by verbosity manipulation.
  The user table (populated by `set_verbosity()` during `config` phase from config
  object fields) was removed as unnecessary. The test author is the same person setting
  plusargs; two mechanisms for the same thing add complexity without value. The
  `set_verbosity()` method is removed from the public interface. Verbosity lookup
  simplifies to: override table (exact match, then parent walk), then global default.
  Per-component overrides are set via `+vrf_set_verbosity` using a delimited string:
  `+vrf_set_verbosity=path1:level1,path2:level2`. This avoids DPI, indexed plusargs, and
  external files while supporting an arbitrary number of entries. UVM uses DPI to work
  around the `$value$plusargs` single-match limitation; VRF avoids that dependency by
  encoding all entries in the value string of a single plusarg.
  Level strings in both plusargs omit the `LOG_` prefix: `NONE`, `LOW`, `MEDIUM`,
  `HIGH`, `FULL`, `DEBUG`. This is consistent with the output format where severity
  labels appear as `INFO`, `WARN`, etc. without a prefix.

### Open Design Decisions

None.

### Test Modules Written

Three SVUnit test modules exist under `tests/vrf_logger/` with stub test cases:

- `vrf_logger_basic_unit_test.sv` - default plusarg environment; covers filter behavior,
  singleton, id rendering, severity counts
- `vrf_logger_verbosity_none_unit_test.sv` - requires `+vrf_verbosity=LOG_NONE`;
  covers global threshold override suppressing INFO, WARN/ERROR still emit
- `vrf_logger_set_verbosity_unit_test.sv` - requires
  `+vrf_set_verbosity=root.env.uart_agent:LOG_HIGH`; covers per-component override,
  non-overridden component falls back to global default, parent walk inheritance

### Next Steps

1. Implement `vrf_logger`
2. Fill in SVUnit test bodies
3. Define `vrf_component` base class interface
4. Define `vrf_sequence_item` base class
5. Define `vrf_objection` interface
6. Add `make docs` target to Makefile
7. Write tests for `vrf_config_db`
8. Design test factory for runtime test selection
9. Design `+config` mechanism (future session)

---

## Session 7  -  2026-05-17

### What Was Decided

- **`[id]` field added to the logger interface.**
  All log calls now carry a caller-supplied `id` string that is rendered as `[id]`
  between the component name and the message. This allows grepping a large simulation
  log by category (`grep '\[UART_DRV\]'`) rather than chaining `grep -v` calls against
  the full hierarchical name. An empty string renders as `[]`; the field is always
  present and the format does not change shape. Confirmed against UVM 1.2 source
  (`compose_report_message` in `uvm_report_server.svh`): UVM hardcodes `[` and `]` as
  string literals with no conditional, so `[]` for an empty id is the UVM-idiomatic
  behavior.

- **All eight macro signatures updated to include `id`.**
  `log_info`, `log_warn`, `log_error`, `log_fatal` and their `report_*` equivalents
  each gain `id` as a required argument. The `warn`/`error`/`fatal` variants still fix
  verbosity to `LOG_NONE` internally; `id` is the only addition.

- **Time units via `$timeformat`, not raw `$time`.**
  The output format changes from `@ <time>` to `@ <time><unit>`. The logger formats
  time with `%0t` (respecting whatever `$timeformat` is active). Setting `$timeformat`
  is the testbench's responsibility; `tb.sv` calls it in an `initial` block before any
  phase runs. SVUnit tests must also set `$timeformat` before the first log call.
  Confirmed from UVM source: `$swrite(time_str, "%0t", $time)` is how UVM does it.

- **`VRF_INFO`-style severity prefix and `WARNING` spelling rejected.**
  Considered for UVM familiarity; rejected as visual noise. Severity labels remain
  `INFO`, `WARN`, `ERROR`, `FATAL`.

- **Per-severity message counts and `summarize()` added.**
  The logger tracks a count of messages emitted at each severity level. At the end of
  the report phase, `vrf_phase_manager` calls `vrf_logger::get_inst().summarize()`,
  which prints a one-line summary to console (and log file if open). Users do not call
  `summarize()` directly. `reset()` (SVUnit only) clears the counts along with all
  other state.

- **Logger established as foundational framework infrastructure.**
  All framework components communicate to the user through the logger. The dependency
  from `vrf_phase_manager` and all components onto `vrf_logger` is intentional,
  one-way, and documented. The phase manager calling `summarize()` is the first
  instance of a broader pattern: framework-level bookkeeping belongs in the phase
  machinery so users are not required to remember it.

### Open Design Decisions

None.

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

- **`get_full_name()` chosen as the canonical method name.**
  Consistent with UVM, which provides `get_name()` (local name) and `get_full_name()`
  (full hierarchical path). There is no `get_full_path()` in the UVM API. All framework
  components and sequences expose `get_full_name()`.

- **`vrf_logger::reset()` added for SVUnit test isolation.**
  SVUnit runs all tests in a single simulation, so static logger state leaks between
  tests. `reset()` destroys the singleton instance and clears all internal state: both
  verbosity tables, the global default, the log file handle, the initialized flag, and
  the singleton handle. The next call to `log()` or `set_verbosity()` re-initializes
  from scratch. The entire function definition is guarded by `ifdef VRF_SVUNIT` so it
  does not exist in production builds and cannot be called accidentally. `+define+VRF_SVUNIT`
  is set by the test build only. Tests that require different plusarg-derived state go
  in separate test modules, each run as a separate simulation with its own plusarg set.

- **Project directory structure established.**
  Framework source lives in `vrf_pkg/`. SVUnit tests live in `tests/`, with one
  subdirectory per component under test (e.g., `tests/vrf_logger/`,
  `tests/vrf_config_db/`). Each subdirectory contains all test modules for that
  component; test modules that require different plusarg sets are separate files,
  each run as its own simulation. A top-level Makefile runs all suites.

- **Package structure established.**
  All framework base classes compile into a single `vrf_pkg`. No sub-packages.
  Protocol-specific packages (`uart_bfm_pkg`, `uart_agent_pkg`, etc.) are separate
  and live outside `vrf_pkg`. The user-facing interface is two lines, consistent
  with the UVM pattern:
  ```
  import vrf_pkg::*;
  `include "vrf_pkg.svh"
  ```
  `vrf_pkg.svh` contains all macro definitions (`log_*`, `report_*`, etc.) that
  cannot live inside a package.

### Open Design Decisions

None.

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
