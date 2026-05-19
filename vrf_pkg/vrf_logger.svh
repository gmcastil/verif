class vrf_logger;

    static local vrf_logger m_inst = null;

    // Store verbosity overrides at runtime, with key-value pairs the full hierarchical name and the
    // verbosity level to set that component
    local vrf_verbosity_e m_override_table[string];
    // Maintain a count of the number of messages logged at each severity for
    // reporting
    local int m_severity_counts[vrf_severity_e];
    // Default log verbosity, can be overriden by $value$plusargs 'vrf_verbosity'
    local vrf_verbosity_e m_global_default;
    // Convenience map for mapping names to log verbosity levels
    local vrf_verbosity_e m_verbosity_map[string];
    // Optional log file via $value$plusargs 'vrf_log_file'. Closed in the summarize phase.
    local int m_log_fd;
    local bit m_log_to_file;

`ifdef VRF_SVUNIT
    local string m_last_msg = "";
`endif

    // verilog_format: off
    local function new();
    // verilog_format: on
        string verbosity_str;
        string log_file_str;
        string entries_str;

        // Populate the log verbosity map so it can be used by other members
        m_verbosity_map["NONE"]   = LOG_NONE;
        m_verbosity_map["LOW"]    = LOG_LOW;
        m_verbosity_map["MEDIUM"] = LOG_MEDIUM;
        m_verbosity_map["HIGH"]   = LOG_HIGH;
        m_verbosity_map["FULL"]   = LOG_FULL;
        m_verbosity_map["DEBUG"]  = LOG_DEBUG;

        // Set the global verbosity
        if ($value$plusargs("vrf_verbosity=%s", verbosity_str)) begin
            if (m_verbosity_map.exists(verbosity_str)) begin
                m_global_default = m_verbosity_map[verbosity_str];
            end else begin
                $fatal(1, "vrf_logger: illegal log verbosity: %s", verbosity_str);
            end
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

        // Populate the verbosity override table
        if ($value$plusargs("vrf_set_verbosity=%s", entries_str)) begin
            populate_override_table(entries_str);
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

    // Central logging function
    function void log(string name, vrf_severity_e severity, vrf_verbosity_e verbosity, string id,
                      string msg, string filename, int line_number);
        string fmt;
        string fmt_msg;

        // Guard first to make sure we're actually logging something
        if (severity == LOG_INFO && verbosity > get_verbosity(name)) begin
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

    local function string severity_to_str(vrf_severity_e severity);
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

    // Given a hierarchical name, returns the verbosity level to apply. Checks the override table
    // first for an exact match, and if it isn't found, walks up the name, until it either finds
    // one in the table or fails, in which case it uses the global default instead
    local function vrf_verbosity_e get_verbosity(string name);
        // First, look up the hierarchical name directly
        if (m_override_table.exists(name)) begin
            return m_override_table[name];
        end else begin
            while (1) begin
                name = get_parent(name);
                if (name != "") begin
                    if (m_override_table.exists(name)) begin
                        return m_override_table[name];
                    end
                end else begin
                    return m_global_default;
                end
            end
        end
    endfunction : get_verbosity

    // Return parent in a hierarchical string. If its the top level of the hierarchy, it returns "".
    local function automatic string get_parent(string name);
        int last_dot;
        last_dot = -1;

        for (int i = name.len() - 1; i >= 0; i--) begin
            if (name.getc(i) == ".") begin
                last_dot = i;
                return name.substr(0, last_dot - 1);
            end
        end
        return "";

    endfunction : get_parent

    // Parse the comma-delimited string of entries, each containing a hierarchical name and severity
    // pair separated by a colon, then populate the override table
    local function void populate_override_table(string entries);

        int i;
        int start;
        string token;

        i = 0;
        start = 0;

        // Iterate over the entries string effectively slicing it from start to finish using commas
        while (i <= entries.len()) begin
            if (i == entries.len() || entries.getc(i) == ",") begin
                token = entries.substr(start, i - 1);
                if (!add_override_entry(token)) begin
                    $warning("vrf_logger: ignoring bad +vrf_set_verbosity entry %s", token);
                end
                start = i + 1;
            end
            i++;
        end
    endfunction : populate_override_table

    // Takes a colon separated string representing a name to log_verbosity_e value to add to the
    // runtime override table
    local function bit add_override_entry(string entry);

        int i;
        string name;
        string verbosity_str;

        name = "";
        // Split the string on the `:` and capture the name and verbosity level
        for (i = 0; i < entry.len(); i++) begin
            if (entry.getc(i) == ":") begin
                name = entry.substr(0, i - 1);
                verbosity_str = entry.substr(i + 1, entry.len() - 1);
                break;
            end
        end

        // Look up the verbosity level and store it in the override table
        if (!m_verbosity_map.exists(verbosity_str)) begin
            return 0;
        end else begin
            m_override_table[name] = m_verbosity_map[verbosity_str];
            return 1;
        end

    endfunction : add_override_entry

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

