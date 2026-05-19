// Requires: +vrf_verbosity=NONE +define+VRF_SVUNIT
import vrf_pkg::*;

`include "svunit_defines.svh"

module vrf_logger_verbosity_none_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "vrf_logger_verbosity_none_ut";
    svunit_testcase svunit_ut;

    function automatic void build();
        svunit_ut = new(name);
    endfunction

    task automatic setup();
        svunit_ut.setup();
        vrf_logger::reset();
        $timeformat(-9, 0, " ns", 1);
    endtask

    task automatic teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    // INFO at LOG_LOW suppressed when global default is LOG_NONE
    `SVTEST(log_info_low_suppressed_by_none_threshold)
        vrf_logger logger = vrf_logger::get_inst();
        logger.log(
            "root.test", LOG_INFO, LOG_LOW, "TEST", "Hello world", "test.sv", 42
        );
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), "");
    `SVTEST_END

    // INFO at LOG_MEDIUM suppressed when global default is LOG_NONE
    `SVTEST(log_info_medium_suppressed_by_none_threshold)
        vrf_logger logger = vrf_logger::get_inst();
        logger.log(
            "root.test", LOG_INFO, LOG_MEDIUM, "TEST", "Hello world", "test.sv", 42
        );
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), "");
    `SVTEST_END

    // WARN still emits when global default is LOG_NONE
    `SVTEST(log_warn_emits_when_threshold_is_none)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();
        logger.log(
            "root.test", LOG_WARN, LOG_NONE, "TEST", "Hello world", "test.sv", 42
        );
        expected = "WARN test.sv(42) @ 0 ns: root.test [TEST] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // ERROR still emits when global default is LOG_NONE
    `SVTEST(log_error_emits_when_threshold_is_none)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();
        logger.log(
            "root.test", LOG_ERROR, LOG_NONE, "TEST", "Hello world", "test.sv", 42
        );
        expected = "ERROR test.sv(42) @ 0 ns: root.test [TEST] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule

