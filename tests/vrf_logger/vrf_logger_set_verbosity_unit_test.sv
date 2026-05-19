// Requires: +vrf_set_verbosity=root.env.uart_agent:LOG_HIGH +define+VRF_SVUNIT
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
    endtask

    task automatic teardown();
        svunit_ut.teardown();
    endtask

    `SVUNIT_TESTS_BEGIN

    // INFO at LOG_HIGH passes for component with LOG_HIGH override
    `SVTEST(log_info_high_passes_for_overridden_component)
    `SVTEST_END

    // INFO at LOG_FULL suppressed for component with LOG_HIGH override
    `SVTEST(log_info_full_suppressed_for_overridden_component)
    `SVTEST_END

    // INFO at LOG_HIGH suppressed for component not in override table (global default LOG_MEDIUM applies)
    `SVTEST(log_info_high_suppressed_for_non_overridden_component)
    `SVTEST_END

    // Parent walk: child of overridden component inherits parent threshold
    `SVTEST(child_component_inherits_parent_override)
    `SVTEST_END

    `SVUNIT_TESTS_END

endmodule