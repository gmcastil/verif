REPO_DIR		:= $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))/../..)
SCRIPTS_DIR		:= $(REPO_DIR)/scripts

.PHONY: test
test:
	REPO_DIR=$(REPO_DIR) $(SCRIPTS_DIR)/run_svunit --sim questa -f vrf_logger.f

.PHONY: clean
clean:
	rm -rf qrun.out
	rm -rf work
	rm -f .__testsuite.sv
	rm -f tests.xml
	rm -f .testrunner.sv
	rm -f compile.log
	rm -f .svunit.f
	rm -f run.log
