// Requires: +vrf_set_verbosity=root.env.uart_agent:HIGH +define+VRF_SVUNIT
import vrf_pkg::*;

`include "svunit_defines.svh"

module vrf_logger_set_verbosity_unit_test;
    import svunit_pkg::svunit_testcase;

    string name = "vrf_logger_set_verbosity_ut";
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

    // Note that when these test cases are executed, the default verbosity for the root.env.uart_agent
    // is set to LOG_HIGH, which overrides the default of LOG_MEDIUM.

    // INFO at LOG_HIGH passes for component with LOG_HIGH override
    `SVTEST(log_info_high_passes_for_overridden_component)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        logger.log(
            "root.env.uart_agent", LOG_INFO, LOG_HIGH, "UART", "Hello world", "test.sv", 42
        );
        expected = "INFO test.sv(42) @ 0 ns: root.env.uart_agent [UART] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // INFO at LOG_FULL suppressed for component with LOG_HIGH override
    `SVTEST(log_info_full_suppressed_for_overridden_component)
        string expected;
        vrf_logger logger = vrf_logger::get_inst();

        logger.log(
            "root.env.uart_agent", LOG_INFO, LOG_HIGH, "UART", "Hello world", "test.sv", 42
        );
        expected = "INFO test.sv(42) @ 0 ns: root.env.uart_agent [UART] Hello world";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);

        logger.log(
            "root.env.uart_agent", LOG_INFO, LOG_FULL, "UART", "suppressed", "test.sv", 43
        );
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // INFO at LOG_HIGH suppressed for component not in override table (global default LOG_MEDIUM applies)
    `SVTEST(log_info_high_suppressed_for_non_overridden_component)
        string expected;

        vrf_logger logger = vrf_logger::get_inst();
        logger.log(
            "root.test", LOG_INFO, LOG_HIGH, "TEST", "Hello world", "test.sv", 42
        );
        expected = "";
        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    // Parent walk: child of overridden component inherits parent threshold
    `SVTEST(child_component_inherits_parent_override)
        string expected;

        vrf_logger logger = vrf_logger::get_inst();
        logger.log(
            "root.env.uart_agent.driver", LOG_INFO, LOG_HIGH, "DRV", "Hello world", "test.sv", 42
        );
        expected = "INFO test.sv(42) @ 0 ns: root.env.uart_agent.driver [DRV] Hello world";

        `FAIL_UNLESS_STR_EQUAL(logger.last_msg(), expected);
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule
