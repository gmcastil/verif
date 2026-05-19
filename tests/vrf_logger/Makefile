REPO_DIR		:= $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))/../..)
SCRIPTS_DIR		:= $(REPO_DIR)/scripts

.PHONY: test
test:
	REPO_DIR=$(REPO_DIR) $(SCRIPTS_DIR)/run_svunit --sim questa -f vrf_logger.f \
		 -t vrf_logger_basic_unit_test.sv -o basic
	REPO_DIR=$(REPO_DIR) $(SCRIPTS_DIR)/run_svunit --sim questa -f vrf_logger.f \
		 -t vrf_logger_set_verbosity_unit_test.sv -o set_verbosity \
		 -r +vrf_set_verbosity=root.env.uart_agent:HIGH
	REPO_DIR=$(REPO_DIR) $(SCRIPTS_DIR)/run_svunit --sim questa -f vrf_logger.f \
		 -t vrf_logger_verbosity_none_unit_test.sv -o verbosity_none \
		 -r +vrf_verbosity=NONE

.PHONY: clean
clean:
	rm -rf basic
	rm -rf set_verbosity
	rm -rf verbosity_none
