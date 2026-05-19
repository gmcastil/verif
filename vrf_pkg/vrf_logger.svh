class vrf_logger;

    static local vrf_logger m_inst = null;

    local vrf_verbosity_e m_override_table[string];
    local vrf_verbosity_e m_user_table[string];
    local vrf_verbosity_e m_global_default;
    local int m_log_fd;

`ifdef VRF_SVUNIT
    local string m_last_msg;
`endif

    // verilog_format: off
    local function new();
    // verilog_format: on
        string level_str;

        // Set the global verbosity
        if ($value$plusargs("vrf_verbosity=%s", level_str)) begin
            case (level_str)
                "LOG_NONE": begin
                    m_global_default = LOG_NONE;
                end
                "LOG_LOW": begin
                    m_global_default = LOG_LOW;
                end
                "LOG_MEDIUM": begin
                    m_global_default = LOG_MEDIUM;
                end
                "LOG_HIGH": begin
                    m_global_default = LOG_HIGH;
                end
                "LOG_FULL": begin
                    m_global_default = LOG_FULL;
                end
                "LOG_DEBUG": begin
                    m_global_default = LOG_DEBUG;
                end
                default: begin
                    m_global_default = LOG_MEDIUM;
                end
            endcase
        end else begin
            m_global_default = LOG_MEDIUM;
        end
    endfunction : new

    // Returns an instance of the logger class. Typically used by clients via the `log_* and
    // `report_* macros.
    static function vrf_logger get_inst();
        if (m_inst == null) begin
            m_inst = new();
        end
        return m_inst;
    endfunction : get_inst

    function void log(string name, vrf_verbosity_e level, vrf_verbosity_e verbosity, string msg,
                      string filename, int line_number);
    endfunction : log

`ifdef VRF_SVUNIT
    static function void reset();
    endfunction : reset

    function string last_msg();
    endfunction : last_msg
`endif

endclass : vrf_logger

