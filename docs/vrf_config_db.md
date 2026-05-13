## vrf_config_db #(T)

A static, parameterized typed key-value store. Each type specialization maintains
independent storage. Objects are stored and retrieved using a component handle and a
short field name string.

This replaces UVM's `uvm_config_db`. Wildcard matching and hierarchical path string
arguments are omitted. Lookup walks the component's ancestry chain until a match is
found or the root is reached.

### Interface

```systemverilog
class vrf_config_db #(type T = int);
    static function void set(vrf_component cntxt, string field_name, T value);
    static function bit  get(vrf_component cntxt, string field_name, ref T value);
endclass
```

### Key Structure

The composite key is `(type, path, field_name)`:

- `type` - the type parameter `T`; each specialization has independent storage
- `path` - derived internally from `cntxt.get_full_name()`; callers never construct
  path strings manually
- `field_name` - a short name identifying the specific entry

For global entries (`cntxt == null`), the key is `(type, field_name)` - a flat
namespace with no path component.

### Behavior

**set:**

- Stores `value` under the composite key for type `T`
- If the key already exists, overwrites and logs a WARNING:
  `"<path>: overwriting existing entry '<field_name>'"`
- Called during `build` phase with the target component's handle as `cntxt`

**get:**

- Looks for `(type, this.get_full_name(), field_name)` first
- On miss, walks up the parent chain repeating the lookup at each ancestor
- If the root is reached without a match, logs a WARNING:
  `"<path>: no entry found for '<field_name>'"` and returns 0
- On hit at any level: populates `value`, returns 1
- The caller decides whether a miss is fatal
- A miss is not a normal condition; the database always logs on a miss, so failures
  are never silent

**cntxt:**

- A `vrf_component` handle; the database derives the path via `cntxt.get_full_name()`
- May be null for global entries; log messages substitute `"[global]"` in that case

### Phase Contract

`set` is called during `build` phase after all components have been constructed.
`get` is called during `config` phase, which runs after `build` completes. This
guarantees every entry is registered before any component attempts to retrieve it.
After `config` phase the database is not written to again.

Phase order: build -> config -> connect -> run -> report.

### Usage

```systemverilog
// Test build phase - construct all components, then register configs under
// the appropriate ancestor handle. The avalon driver walks up to its agent
// and finds "avl_cfg" there; works identically for any number of instances.
vrf_config_db #(uart_agent_config)::set(m_uart_agent,    "cfg",     uart_cfg);
vrf_config_db #(avalon_agent_config)::set(m_avl_agent_0, "avl_cfg", avl_cfg_0);
vrf_config_db #(avalon_agent_config)::set(m_avl_agent_1, "avl_cfg", avl_cfg_1);

// Global registration - accessible to any component by passing null
vrf_config_db #(int)::set(null, "timeout", 1000);

// Component config phase - retrieve using own handle; parent walk finds
// entries registered at any ancestor level
if (!vrf_config_db #(avalon_agent_config)::get(this, "avl_cfg", m_cfg))
    vrf_logger::fatal(get_full_name(), "avl_cfg not found");
```

### Notes

- Two agents at different paths may each store an entry named `"avl_cfg"` without
  collision; each component's parent walk is confined to its own ancestry chain
- The parent walk is bounded by the component tree; it never crosses into a sibling
  or cousin's subtree, so unintended matches between parallel agent instances cannot
  occur
- There are no wildcards; all lookups are exact matches on the composite key at
  each level of the walk
- Global entries (null context) form a separate namespace from scoped entries and
  are not searched during a scoped lookup

