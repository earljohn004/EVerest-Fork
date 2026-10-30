# Shortcuts for local-sil/sil.sh, e.g. `make start`, `make run parking`, `make stop`.
SIL := ./local-sil/sil.sh
CMDS := start run flow kill shell logs stop help

# `make run parking`: the second word is the argument to sil.sh, not a make target.
ARG := $(word 2,$(MAKECMDGOALS))
ifneq ($(ARG),)
ifneq ($(filter $(firstword $(MAKECMDGOALS)),start run flow),)
$(eval $(ARG):;@:)
endif
endif

.PHONY: $(CMDS)
$(CMDS):
	@$(SIL) $@ $(ARG)
