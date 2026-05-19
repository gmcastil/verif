package vrf_pkg;

    typedef enum {
        LOG_INFO,
        LOG_WARN,
        LOG_ERROR,
        LOG_FATAL
    } vrf_severity_e;

    typedef enum {
        LOG_NONE = 0,
        LOG_LOW = 1,
        LOG_MEDIUM = 2,
        LOG_HIGH = 3,
        LOG_FULL = 4,
        LOG_DEBUG = 5
    } vrf_verbosity_e;

    `include "vrf_logger.svh"

endpackage
