package vrf_pkg;

    typedef enum {
        LOG_INFO,
        LOG_WARN,
        LOG_ERROR,
        LOG_FATAL
    } vrf_level_e;

    typedef enum {
        LOG_NONE,
        LOG_LOW,
        LOG_HIGH,
        LOG_DEBUG
    } vrf_verbosity_e;

    `include "vrf_logger.svh"

endpackage
