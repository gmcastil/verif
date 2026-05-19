import vrf_pkg::*;

`include "svunit_defines.svh"

module vrf_logger_basic_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "vrf_logger_ut";
    svunit_testcase svunit_ut;

    function automatic void build();
        svunit_ut = new(name);
    endfunction

    task automatic setup();
        svunit_ut.setup();
        vrf_logger::reset();
    endtask

    task automatic teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    // INFO at LOG_LOW passed default threshold; format correct
    `SVTEST(log_info_low_passes_default_filter)
    `SVTEST_END

    // INFO at LOG_HIGH suppressed; last_msg() stays ""
    `SVTEST(log_info_high_suppressed_by_default_filter)
    `SVTEST_END

    // INFO at LOG_FULL suppressed; last_msg() stays ""
    `SVTEST(log_info_full_suppressed_by_default_filter)
    `SVTEST_END

    // WARN always emitted regardless of verbosity
    `SVTEST(log_warn_bypasses_verbosity_filter)
    `SVTEST_END

    // ERROR always emitted regardless of verbosity
    `SVTEST(log_error_bypasses_verbosity_filter)
    `SVTEST_END

    // "" id renders as [] in output
    `SVTEST(empty_id_renders_as_empty_brackets)
    `SVTEST_END

    // Two get_inst() calls return the same handle
    `SVTEST(singleton_returns_same_instance)
    `SVTEST_END

    // Per-severity counts are correct after several log calls
    `SVTEST(message_counts_increment)
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
