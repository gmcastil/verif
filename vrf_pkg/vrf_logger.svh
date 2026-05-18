class vrf_logger;

    static local vrf_logger   m_inst = null;

    local vrf_verbosity_e     m_override_table[string];
    local vrf_verbosity_e     m_user_table[string];
    local vrf_verbosity_e     m_global_default;
    local int                 m_log_fd;

`ifdef VRF_SVUNIT
    local string              m_last_msg;
`endif

    local function new();
    endfunction : new

    static function vrf_logger get_inst();
    endfunction : get_inst

    function void log(string name, vrf_level_e level, vrf_verbosity_e verbosity,
                      string msg, string filename, int line_number);
    endfunction : log

    function void set_verbosity(string name, vrf_verbosity_e level);
    endfunction : set_verbosity

`ifdef VRF_SVUNIT
    static function void reset();
    endfunction : reset

    function string last_msg();
    endfunction : last_msg
`endif

endclass : vrf_logger