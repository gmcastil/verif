class vrf_logger;

    static local vrf_logger m_inst = null;

    // Store verbosity overrides at runtime
    local vrf_verbosity_e m_override_table[string];
    // Maintain a count of the number of messages logged at each severity for
    // reporting
    local int m_severity_counts[vrf_severity_e];
    // Default log verbosity, can be overriden by $value$plusargs 'vrf_verbosity'
    local vrf_verbosity_e m_global_default;
    // Optional log file via $value$plusargs 'vrf_log_file'. Closed in the summarize phase.
    local int m_log_fd;
    local bit m_log_to_file;

`ifdef VRF_SVUNIT
    local string m_last_msg = "";
`endif

    // verilog_format: off
    local function new();
    // verilog_format: on
        string level_str;
        string log_file_str;

        // Set the global verbosity
        if ($value$plusargs("vrf_verbosity=%s", level_str)) begin
            case (level_str)
                "NONE": begin
                    m_global_default = LOG_NONE;
                end
                "LOW": begin
                    m_global_default = LOG_LOW;
                end
                "MEDIUM": begin
                    m_global_default = LOG_MEDIUM;
                end
                "HIGH": begin
                    m_global_default = LOG_HIGH;
                end
                "FULL": begin
                    m_global_default = LOG_FULL;
                end
                "DEBUG": begin
                    m_global_default = LOG_DEBUG;
                end
                default: begin
                    m_global_default = LOG_MEDIUM;
                end
            endcase
        end else begin
            m_global_default = LOG_MEDIUM;
        end

        // Open the log file if it was provided
        if ($value$plusargs("vrf_log_file=%s", log_file_str)) begin
            m_log_fd = $fopen(log_file_str, "w");
            if (m_log_fd == 0) begin
                $fatal(1, "vrf_logger: failed to open log file: %s", log_file_str);
            end
            m_log_to_file = 1;
        end else begin
            m_log_to_file = 0;
        end

        // Initialize the severity count table
        m_severity_counts[LOG_INFO]  = 0;
        m_severity_counts[LOG_WARN]  = 0;
        m_severity_counts[LOG_ERROR] = 0;
        m_severity_counts[LOG_FATAL] = 0;

        // Populate the verbosity override table (TODO)

    endfunction : new

    // Returns an instance of the logger class. Typically used by clients via the `log_* and
    // `report_* macros.
    static function vrf_logger get_inst();
        if (m_inst == null) begin
            m_inst = new();
        end
        return m_inst;
    endfunction : get_inst

    function void log(string name, vrf_severity_e severity, vrf_verbosity_e verbosity, string id,
                      string msg, string filename, int line_number);
        string fmt;
        string fmt_msg;

        // Guard first to make sure we're actually logging something
        if (severity == LOG_INFO && verbosity > m_global_default) begin
            return;
        end

        // Example: "INFO test.sv(42) @ 100 ns: root.test [TEST] Hello world"
        fmt = "%s %s(%0d) @ %0t: %s [%s] %s";
        fmt_msg =
            $sformatf(fmt, severity_to_str(severity), filename, line_number, $time, name, id, msg);
        $display("%s", fmt_msg);

`ifdef VRF_SVUNIT
        m_last_msg = fmt_msg;
`endif

        // Increment counts and log to file if indicated
        m_severity_counts[severity]++;
        if (m_log_to_file) begin
            $fdisplay(m_log_fd, "%s", fmt_msg);
        end

        // This is the sole point of early termination in the framework.
        if (severity == LOG_FATAL) begin
            if (m_log_to_file) begin
                $fclose(m_log_fd);
            end
            $fatal(1);
        end

    endfunction : log

    function int get_severity_count(vrf_severity_e severity);
        return m_severity_counts[severity];
    endfunction : get_severity_count

    function string severity_to_str(vrf_severity_e severity);
        case (severity)
            LOG_INFO: begin
                return "INFO";
            end
            LOG_WARN: begin
                return "WARN";
            end
            LOG_ERROR: begin
                return "ERROR";
            end
            LOG_FATAL: begin
                return "FATAL";
            end
            default: begin
                return "UNKNOWN";
            end
        endcase
    endfunction : severity_to_str

`ifdef VRF_SVUNIT
    // SVUnit tests need to be able to clear the logger so that it can be reused, without each
    // test affecting it
    static function void reset();
        m_inst = null;
    endfunction : reset

    // For testing purposes, we store the last emitted log message so that test can call the
    // log() function and check the result afterwards
    function string last_msg();
        return m_last_msg;
    endfunction : last_msg
`endif

endclass : vrf_logger

