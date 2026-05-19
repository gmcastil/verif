## vrf_logger

A singleton static class providing simulation-wide diagnostic logging. Two orthogonal
axes control whether a message is emitted: severity (how serious the message is) and
verbosity (how detailed the message is). Severity filtering applies to all messages;
verbosity filtering applies only to `INFO` messages.

The logger has no dependency on `vrf_component`. All callers identify themselves with
a hierarchical name string. This makes the logger usable from sequences, sequence items,
static utility classes, and any other context where a class handle is not available.

---

### Enumerations

```systemverilog
typedef enum {
    LOG_INFO,
    LOG_WARN,
    LOG_ERROR,
    LOG_FATAL
} vrf_severity_e;

typedef enum {
    LOG_NONE   = 0,
    LOG_LOW    = 1,
    LOG_MEDIUM = 2,
    LOG_HIGH   = 3,
    LOG_FULL   = 4,
    LOG_DEBUG  = 5
} vrf_verbosity_e;
```

Verbosity filtering applies only to `LOG_INFO` messages. A `LOG_INFO` message is
emitted when its verbosity value is less than or equal to the active threshold.
`LOG_DEBUG` (5) requires the threshold to be explicitly set to `LOG_DEBUG`. The
compiled-in global default threshold is `LOG_MEDIUM`. `LOG_WARN`, `LOG_ERROR`, and
`LOG_FATAL` are never compared against the verbosity threshold; they always emit.

| Level        | Value | Typical use                                          |
| ------------ | ----- | ---------------------------------------------------- |
| `LOG_NONE`   | 0     | Suppresses all INFO output when used as a threshold  |
| `LOG_LOW`    | 1     | Key milestones: start/end of test, major phase events|
| `LOG_MEDIUM` | 2     | General messages; default threshold                  |
| `LOG_HIGH`   | 3     | Per-transaction detail, data values                  |
| `LOG_FULL`   | 4     | Very verbose; state dumps, buffer contents           |
| `LOG_DEBUG`  | 5     | Trace-level detail; internal state, FSM transitions  |

---

### Interface

```systemverilog
class vrf_logger;

    // Return the singleton instance, creating it on first call.
    // All callers go through this method; no public constructor.
    static function vrf_logger get_inst();

    // Primary log entry point. Called by macros; direct calls are reserved for
    // module and interface scope where macros are unavailable.
    function void log(string name, vrf_severity_e severity,
                      vrf_verbosity_e verbosity, string id, string msg,
                      string filename, int line_number);

    // Return the number of messages emitted at the given severity level.
    // Only counts messages that passed the verbosity filter and were actually
    // emitted; suppressed messages are not counted.
    function int get_severity_count(vrf_severity_e severity);

    // Print per-severity message counts to console (and log file if open).
    // Called by vrf_phase_manager at the end of the report phase. Not intended
    // for direct use; the framework calls it automatically.
    function void summarize();

`ifdef VRF_SVUNIT
    // Destroy the singleton instance and clear all internal state. Only
    // available in SVUnit builds. Resets: override table, global default,
    // log file handle, initialized flag, and singleton handle.
    // The next call to get_inst() re-initializes from scratch.
    // +define+VRF_SVUNIT is set by the test build; it must not appear in
    // production builds. Plusargs are frozen at time zero and do not change,
    // so reset() is only meaningful when test code is manufacturing state
    // that would otherwise come from plusargs.
    static function void reset();

    // Returns the last formatted message string produced by log(). Inside
    // log(), a single `ifdef VRF_SVUNIT block stores the formatted string
    // into an internal variable before the $display call. Tests call
    // last_msg() after calling log() to assert on message contents without
    // needing to capture $display output.
    function string last_msg();
`endif

endclass
```

---

### Macros

Two macro families cover all four severities. Both expand to `vrf_logger::get_inst().log()`.

```systemverilog
// Class scope - name derived from this.get_full_name() automatically.
// Use from any class that implements get_full_name().
`log_info(id, verbosity, msg)
`log_warn(id, msg)
`log_error(id, msg)
`log_fatal(id, msg)

// Module/interface scope - caller supplies an identifying string.
// Use from tb.sv, interface initial blocks, and other non-class contexts.
`report_info(name, id, verbosity, msg)
`report_warn(name, id, msg)
`report_error(name, id, msg)
`report_fatal(name, id, msg)
```

`log_warn`, `log_error`, `log_fatal` and their `report_*` equivalents take no verbosity
argument; verbosity filtering does not apply to these severities.

`id` is a short caller-supplied string used to categorize messages (e.g., `"UART_DRV"`).
Pass `""` when no category is needed; the logger renders it as `[]`. A single component
may use multiple ids to distinguish message categories.

---

### Verbosity Lookup

The logger maintains one internal table, an associative array keyed by hierarchical
name strings:

- **Override table** - populated from `+vrf_set_verbosity` at initialization. Never
  modified after that.

Lookup order for a given `name`:

1. Exact match in override table
2. Parent walk in override table (strip trailing `.segment` iteratively)
3. Global default: `LOG_MEDIUM` (compiled-in; overridden by `+vrf_verbosity`)

The parent walk strips one `.segment` at a time from the right of the name string
until a match is found or the string is empty. An empty string exhausts the chain;
the global default applies.

Setting `"root.env.uart_agent"` in the override table covers all descendants
(`"root.env.uart_agent.driver"`, `"root.env.uart_agent.monitor"`, etc.) via the
parent walk, with no individual entries required.

---

### Severity Behavior

| Severity    | Verbosity filtered | Halts simulation  |
| ----------- | ------------------ | ----------------- |
| `LOG_INFO`  | yes                | no                |
| `LOG_WARN`  | no - always emits  | no                |
| `LOG_ERROR` | no - always emits  | no                |
| `LOG_FATAL` | no - always emits  | yes (`$fatal(1)`) |

---

### Output Format

```
INFO uart_driver.sv(55) @ 100 ns: root.env.uart_agent.driver [UART_DRV] driving byte 0xA5
```

| Field    | Example                          | Description                                                      |
| -------- | -------------------------------- | ---------------------------------------------------------------- |
| Severity | `INFO`                           | One of `INFO`, `WARN`, `ERROR`, `FATAL`                          |
| File/line| `uart_driver.sv(55)`             | Source file and line; supplied by `__FILE__` and `__LINE__`      |
| Sim time | `@ 100 ns`                       | Simulation time at point of call; formatted by `$timeformat`     |
| Context  | `root.env.uart_agent.driver`     | Full hierarchical name of the caller                             |
| ID tag   | `[UART_DRV]`                     | Caller-supplied category string; renders as `[]` if empty        |
| Message  | `driving byte 0xA5`              | The log message text                                             |

All four severities produce the same format. The testbench sets `$timeformat` in `tb.sv`
before any phase runs; the logger does not set or modify it.

### Report Summary

At the end of the report phase, `vrf_phase_manager` calls `vrf_logger::get_inst().summarize()`.
The logger prints a count of messages emitted at each severity:

```
--- VRF Report Summary ---
INFO: 142   WARN: 3   ERROR: 2   FATAL: 0
```

The summary is always printed, even when all counts are zero. Users do not call
`summarize()` directly; the phase manager does it automatically.

Output goes to console (`$display`) always. If `+vrf_log_file` is provided, output
is written to that file simultaneously.

---

### Plusarg Interface

| Plusarg                                      | Effect                                                        |
| -------------------------------------------- | ------------------------------------------------------------- |
| `+vrf_verbosity=<level>`                     | Override global default (NONE/LOW/MEDIUM/HIGH/FULL/DEBUG)     |
| `+vrf_set_verbosity=<path>:<level>[,...]`    | Populate override table; comma-delimited, arbitrary entries   |
| `+vrf_log_file=<filepath>`                   | Write all output to file in addition to console               |

Plusargs are parsed once during logger initialization before any phase runs.
All per-component overrides are encoded in a single `+vrf_set_verbosity` value,
comma-delimited. Each entry is `<path>:<level>`. Level strings omit the `LOG_`
prefix: `NONE`, `LOW`, `MEDIUM`, `HIGH`, `FULL`, `DEBUG`. This matches the
convention used in output messages (`INFO`, `WARN`, etc.) where the prefix is
omitted as noise.

Example:

```
+vrf_verbosity=NONE
+vrf_set_verbosity=root.env.uart_agent:HIGH,root.env.uart_agent.driver:DEBUG
+vrf_log_file=sim.log
```

---


### Initialization

The logger initializes on first use. Initialization:

1. Parses `+vrf_verbosity` and sets the global default if present
2. Parses `+vrf_set_verbosity`, splits on `,`, and loads each `path:level` pair into the override table
3. Opens the log file if `+vrf_log_file` is present

Initialization happens before any phase runs, so the override table is fully
populated before any component calls `log()`.

---

### Usage

```systemverilog
// tb.sv - set time units before any phase runs
initial $timeformat(-9, 0, " ns", 0);

// class scope - name and id supplied by caller
`log_info("UART_DRV", LOG_HIGH, "driving transaction");
`log_fatal("UART_DRV", "BFM handle not found");

// module/interface scope - caller supplies name and id strings
`report_info("tb", "TB", LOG_LOW, "simulation started");
`report_fatal("tb.uart_if", "CLK", "clk not detected");
```

---

### Notes

- `LOG_WARN`, `LOG_ERROR`, and `LOG_FATAL` are not subject to verbosity filtering;
  the verbosity check is skipped entirely for these severities
- The logger is intentionally free of any dependency on `vrf_component`; it can be
  instantiated and used before any component exists
- Non-component callers (sequences, static classes) pass any identifying string as
  `name`; the parent walk applies to them identically
- An unrecognized plusarg level string is ignored and the default is retained
- The logger is foundational framework infrastructure; all framework components
  communicate to the user through it. The dependency from `vrf_phase_manager` and
  all components onto `vrf_logger` is intentional and one-way
- Time formatting is the testbench's responsibility. Set `$timeformat` in `tb.sv`
  before any phase runs. The logger does not set or modify `$timeformat`
- `reset()` (SVUnit only) clears the per-severity message counts along with all
  other internal state

