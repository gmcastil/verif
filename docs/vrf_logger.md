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
    LOG_NONE,
    LOG_LOW,
    LOG_HIGH,
    LOG_DEBUG
} vrf_verbosity_e;
```

`LOG_NONE` suppresses all `INFO` messages for a component. `LOG_DEBUG` passes all
`INFO` messages. `LOG_WARN`, `LOG_ERROR`, and `LOG_FATAL` are never suppressed by
the verbosity threshold.

---

### Interface

```systemverilog
class vrf_logger;

    // Primary log entry point. Called by macros; direct calls are reserved for
    // module and interface scope where macros are unavailable.
    static function void log(string name, vrf_severity_e severity,
                             vrf_verbosity_e verbosity, string msg,
                             string filename, int line_number);

    // Write a verbosity threshold entry to the user table.
    // Called by components during config phase using their config object's
    // verbosity field.
    static function void set_verbosity(string name, vrf_verbosity_e level);

endclass
```

---

### Macros

Two macro families cover all four severities. Both expand to `vrf_logger::log()`.

```systemverilog
// Class scope - name derived from this.get_full_name() automatically.
// Use from any class that implements get_full_name().
`log_info(verbosity, msg)
`log_warn(msg)
`log_error(msg)
`log_fatal(msg)

// Module/interface scope - caller supplies an identifying string.
// Use from tb.sv, interface initial blocks, and other non-class contexts.
`report_info(name, verbosity, msg)
`report_warn(name, msg)
`report_error(name, msg)
`report_fatal(name, msg)
```

`log_warn`, `log_error`, `log_fatal` and their `report_*` equivalents take no verbosity
argument; the macro fixes verbosity to `LOG_NONE` so they always pass the filter.

---

### Verbosity Lookup

The logger maintains two internal tables, both associative arrays keyed by
hierarchical name strings:

- **Override table** - populated from plusargs at initialization. Never modified
  after that. Always takes precedence.
- **User table** - populated by calls to `set_verbosity()` during `config` phase.

Lookup order for a given `name`:

1. Exact match in override table
2. Parent walk in override table (strip trailing `.segment` iteratively)
3. Exact match in user table
4. Parent walk in user table
5. Global default: `LOG_LOW` (compiled-in)

The parent walk strips one `.segment` at a time from the right of the name string
until a match is found or the string is empty. An empty string exhausts the chain;
the global default applies.

Setting `"root.env.uart_agent"` in either table covers all descendants
(`"root.env.uart_agent.driver"`, `"root.env.uart_agent.monitor"`, etc.) via the
parent walk, with no individual entries required.

---

### Severity Behavior

| Severity    | Verbosity filtered | Halts simulation  |
| ----------- | ------------------ | ----------------- |
| `LOG_INFO`  | yes                | no                |
| `LOG_WARN`  | no                 | no                |
| `LOG_ERROR` | no                 | no                |
| `LOG_FATAL` | no                 | yes (`$fatal(1)`) |

---

### Output Format

All messages:

```
<SEVERITY> <filename>(<line>) @ <time>: <full_name> <message>
```

File and line are always present; macros supply them via `__FILE__` and `__LINE__`.
Time is the raw `$time` value. Full name is the complete hierarchical path of the
caller.

Example:

```
INFO uart_driver.sv(55) @ 100: root.env.uart_agent.driver driving byte 0xA5
WARN uart_monitor.sv(42) @ 200: root.env.uart_agent.monitor unexpected idle
ERROR uart_driver.sv(99) @ 300: root.env.uart_agent.driver protocol violation
FATAL uart_driver.sv(10) @ 400: root.env.uart_agent.driver BFM handle not found
```

Output goes to console (`$display`) always. If `+vrf_log_file` is provided, output
is written to that file simultaneously.

---

### Plusarg Interface

| Plusarg                             | Effect                                            |
| ----------------------------------- | ------------------------------------------------- |
| `+vrf_verbosity=<level>`            | Override global default (LOG_NONE/LOW/HIGH/DEBUG) |
| `+vrf_set_verbosity=<path>:<level>` | Add entry to override table; repeatable           |
| `+vrf_log_file=<filepath>`          | Write all output to file in addition to console   |

Plusargs are parsed once during logger initialization before any phase runs.
`+vrf_set_verbosity` may appear multiple times; each instance adds one entry.

Example:

```
+vrf_verbosity=LOG_LOW
+vrf_set_verbosity=root.env.uart_agent:LOG_DEBUG
+vrf_set_verbosity=root.env.axi_agent:LOG_NONE
+vrf_log_file=sim.log
```

---

### Initialization

The logger initializes on first use. Initialization:

1. Parses `+vrf_verbosity` and sets the global default if present
2. Parses all `+vrf_set_verbosity` entries into the override table
3. Opens the log file if `+vrf_log_file` is present

Initialization happens before any phase runs, so the override table is fully
populated before any component calls `set_verbosity()` or `log()`.

---

### Usage

```systemverilog
// config phase - agent registers its verbosity from its config object
vrf_logger::set_verbosity(this.get_full_name(), m_cfg.verbosity);

// class scope - name supplied automatically
`log_info(LOG_HIGH, "driving transaction");
`log_fatal("BFM handle not found");

// module/interface scope - caller supplies name string
`report_info("tb", LOG_LOW, "simulation started");
`report_fatal("tb.uart_if", "clk not detected");
```

---

### Notes

- `LOG_WARN`, `LOG_ERROR`, and `LOG_FATAL` never require a verbosity argument at
  the semantic level; macros will fix the verbosity to `LOG_NONE` for these severities
  so they always pass the `is_enabled()` check
- The logger is intentionally free of any dependency on `vrf_component`; it can be
  instantiated and used before any component exists
- Non-component callers (sequences, static classes) pass any identifying string as
  `name`; the parent walk applies to them identically
- `set_verbosity()` writes to the user table only; the override table is read-only
  after initialization
- An unrecognized plusarg level string is ignored and the default is retained

