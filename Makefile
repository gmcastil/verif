SHELL			:= /bin/bash

PRINTF			:= builtin printf
GREP			:= grep

PROJ_FILES		:= $(shell git ls-files | grep -v '^extern/')

check-ascii:
	@$(PRINTF) '%s\n' "Checking for non-ASCII characters..."
	@LC_ALL=C $(GREP) --color='always' -Pn "[^\x00-\x7F]" $(PROJ_FILES) || $(PRINTF) 'OK\n'

