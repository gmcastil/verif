SHELL			:= /bin/bash
NPROC			:= $(shell nproc)

# Top level directories that all subsystems inherit
REPO_DIR		:= $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
EXTERN_DIR		:= $(REPO_DIR)/extern
SVUNIT_INSTALL		:= $(EXTERN_DIR)/svunit
TEST_DIRS		:= $(wildcard $(REPO_DIR)/tests/vrf_*)

PRINTF			:= builtin printf
GREP			:= grep

PROJ_FILES		:= $(shell git ls-files | grep -v '^extern/')

.PHONY: ctags test file-list check-ascii clean

ctags:
	ctags -R --languages=SystemVerilog \
	$(REPO_DIR)/vrf_pkg $(REPO_DIR)/tests $(SVUNIT_INSTALL)/svunit_base

test:
	@for dir in $(TEST_DIRS); do \
	$(MAKE) -C $$dir test || exit 1; \
	done

# Creates a filelist for the LSP
file-list:
	find $(SVUNIT_INSTALL)/svunit_base -iname '*.svh' -o -iname '*.sv' -o -iname '*.v' | sort > $(REPO_DIR)/verible.filelist
	find $(REPO_DIR)/vrf_pkg -iname '*.svh' -o -iname '*.sv' -o -iname '*.v' | sort >> $(REPO_DIR)/verible.filelist

# Check the source codd and documentation for non-ASCII characters
check-ascii:
	@$(PRINTF) '%s\n' "Checking for non-ASCII characters..."
	@LC_ALL=C $(GREP) --color='always' -Pn "[^\x00-\x7F]" $(PROJ_FILES) || $(PRINTF) 'OK\n'

clean:
	rm -f tags
