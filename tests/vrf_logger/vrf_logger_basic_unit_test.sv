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
        // $timeformat(<unit_number>, <precision>, <suffix_string>, <minimum field width>);
        $timeformat(-9, 0, " ns", 1);
    endtask

    task automatic teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    // Demonstrate that the test-only reset actualy returns a new object
    `SVTEST(logger_singleton_reset_succeeds)
        vrf_logger logger = vrf_logger::get_inst();
        vrf_logger::reset();
        `FAIL_UNLESS(logger != vrf_logger::get_inst());
    `SVTEST_END

    // INFO at LOG_LOW passed default threshold; format correct
    `SVTEST(log_info_low_passes_default_filter)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        logger.log(
            "root.test", LOG_INFO, LOG_LOW, "TEST", "Hello world", "test.sv", 42
        );
        expected = "INFO test.sv(42) @ 0 ns: root.test [TEST] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // INFO at LOG_HIGH suppressed; last_msg() stays ""
    `SVTEST(log_info_high_suppressed_by_default_filter)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        // Need to make sure that the default actually works first, or this will pass
        // even if it hasn't been implemented yet.
        logger.log(
            "root.test", LOG_INFO, LOG_LOW, "TEST", "Hello world", "test.sv", 42
        );
        expected = "INFO test.sv(42) @ 0 ns: root.test [TEST] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);

        // Now test that the HIGH verbosity is actually suppressed and the last message
        // emitted doesn't change
        logger.log(
            "root.test", LOG_INFO, LOG_HIGH, "TEST", "Hello world", "test.sv", 42
        );
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // WARN always emitted regardless of verbosity
    `SVTEST(log_warn_bypasses_verbosity_filter)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        logger.log(
            "root.test", LOG_WARN, LOG_DEBUG, "TEST", "Hello world", "test.sv", 42
        );
        expected = "WARN test.sv(42) @ 0 ns: root.test [TEST] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // ERROR always emitted regardless of verbosity
    `SVTEST(log_error_bypasses_verbosity_filter)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        logger.log(
            "root.test", LOG_ERROR, LOG_DEBUG, "TEST", "Hello world", "test.sv", 42
        );
        expected = "ERROR test.sv(42) @ 0 ns: root.test [TEST] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // "" id renders as [] in output
    `SVTEST(empty_id_renders_as_empty_brackets)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        logger.log(
            "root.test", LOG_INFO, LOG_LOW, "", "Hello world", "test.sv", 42
        );
        expected = "INFO test.sv(42) @ 0 ns: root.test [] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // Two get_inst() calls return the same handle
    `SVTEST(singleton_returns_same_instance)
        vrf_logger logger = vrf_logger::get_inst();
        `FAIL_UNLESS(logger == vrf_logger::get_inst());
    `SVTEST_END

    // Per-severity counts are correct after several log calls
    `SVTEST(message_counts_increment)
        vrf_logger logger = vrf_logger::get_inst();

        logger.log("root.test", LOG_INFO, LOG_LOW, "TEST", "msg 1", "test.sv", 1);
        logger.log("root.test", LOG_INFO, LOG_LOW, "TEST", "msg 2", "test.sv", 2);
        logger.log("root.test", LOG_INFO, LOG_HIGH, "TEST", "suppressed", "test.sv", 3);
        logger.log("root.test", LOG_WARN, LOG_HIGH, "TEST", "a warning", "test.sv", 4);
        logger.log("root.test", LOG_ERROR, LOG_HIGH, "TEST", "an error", "test.sv", 5);

        `FAIL_UNLESS(logger.get_severity_count(LOG_INFO) == 2);
        `FAIL_UNLESS(logger.get_severity_count(LOG_WARN) == 1);
        `FAIL_UNLESS(logger.get_severity_count(LOG_ERROR) == 1);
        `FAIL_UNLESS(logger.get_severity_count(LOG_FATAL) == 0);
    `SVTEST_END

    // Simulation time is displayed properly as time advances per $timeformat
    `SVTEST(sim_time_appears_in_log_message)
        vrf_logger logger = vrf_logger::get_inst();

        logger.log("root.test", LOG_INFO, LOG_LOW, "TEST", "first",  "test.sv", 1);
        `FAIL_UNLESS_STR_EQUAL(
            logger.last_msg(), "INFO test.sv(1) @ 0 ns: root.test [TEST] first"
        );

        #100;
        logger.log("root.test", LOG_INFO, LOG_LOW, "TEST", "second", "test.sv", 2);
        `FAIL_UNLESS_STR_EQUAL(
            logger.last_msg(), "INFO test.sv(2) @ 100 ns: root.test [TEST] second"
        );

        #100;
        logger.log("root.test", LOG_INFO, LOG_LOW, "TEST", "third",  "test.sv", 3);
        `FAIL_UNLESS_STR_EQUAL(
            logger.last_msg(), "INFO test.sv(3) @ 200 ns: root.test [TEST] third"
        );
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
