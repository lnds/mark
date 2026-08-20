# mark — a markdown viewer for the terminal, in kaikai.
#
# Nothing here is load-bearing: terevaka declares its terminal shim in
# its own manifest ([native]), so the driver compiles and links it and
# a plain `kai build .` works. These targets are shorthand for the
# commands in the README, not a build system the project depends on.
#
# Do not put terevaka's shim back into CFLAGS — [native] already links
# it, and a second copy fails on duplicate kai_tvk_* symbols.

KAI_BIN ?= kai
BUILD   := build

SRC := main.kai $(wildcard mark/*.kai)

.PHONY: all run test lint fmt fmt-check check clean deps install uninstall \
        install-completions install-completion-zsh install-completion-bash \
        install-completion-fish

all: $(BUILD)/mark

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/mark: $(SRC) kai.lock | $(BUILD)
	$(KAI_BIN) build . -o $@

kai.lock: kai.toml
	$(KAI_BIN) fetch

deps: kai.lock

# `kai install .` is the usual path — it drops the binary in
# $KAIKAI_HOME/bin, already on PATH. This target is for a different
# prefix (PREFIX=/usr/local for /usr/local/bin), and copies rather
# than symlinks so `make clean` does not break the command.
PREFIX ?= $(HOME)

install: all
	mkdir -p $(PREFIX)/bin
	cp $(BUILD)/mark $(PREFIX)/bin/mark

uninstall:
	rm -f $(PREFIX)/bin/mark

BREW_PREFIX := $(shell brew --prefix 2>/dev/null)

# The zsh completion has to sort ahead of zsh's stock functions, where
# _mh claims the name `mark` for the MH mail handler. Homebrew's
# site-functions does; override for anywhere else on $fpath.
ZSH_COMPLETION_DIR  ?= $(BREW_PREFIX)/share/zsh/site-functions
BASH_COMPLETION_DIR ?= $(BREW_PREFIX)/etc/bash_completion.d
FISH_COMPLETION_DIR ?= $(HOME)/.config/fish/completions

# Each shell is installed on its own, and a missing directory is a skip
# rather than an error: few machines have all three.
install-completions: install-completion-zsh install-completion-bash install-completion-fish

install-completion-zsh:
	@if [ -d "$(ZSH_COMPLETION_DIR)" ]; then \
	  cp completions/_mark "$(ZSH_COMPLETION_DIR)/_mark" \
	    && echo "zsh  -> $(ZSH_COMPLETION_DIR)/_mark"; \
	else echo "zsh  -- skipped, no $(ZSH_COMPLETION_DIR)"; fi

install-completion-bash:
	@if [ -d "$(BASH_COMPLETION_DIR)" ]; then \
	  cp completions/mark.bash "$(BASH_COMPLETION_DIR)/mark" \
	    && echo "bash -> $(BASH_COMPLETION_DIR)/mark"; \
	else echo "bash -- skipped, no $(BASH_COMPLETION_DIR)"; fi

install-completion-fish:
	@if [ -d "$(FISH_COMPLETION_DIR)" ]; then \
	  cp completions/mark.fish "$(FISH_COMPLETION_DIR)/mark.fish" \
	    && echo "fish -> $(FISH_COMPLETION_DIR)/mark.fish"; \
	else echo "fish -- skipped, no $(FISH_COMPLETION_DIR)"; fi

run: all
	./$(BUILD)/mark

test:
	$(KAI_BIN) test .

# `kai check .` only looks at the root package: unlike `kai test` it
# does not descend into tests/, so the files go one by one.
check:
	@for f in tests/*.kai; do $(KAI_BIN) check $$f; done

lint:
	$(KAI_BIN) lint .

# `kai fmt .` formats the entry point and nothing else, exiting 0 as if
# it had done the package: the files go one by one here too.
fmt:
	@for f in main.kai mark/*.kai tests/*.kai; do $(KAI_BIN) fmt $$f; done

fmt-check:
	@for f in main.kai mark/*.kai tests/*.kai; do $(KAI_BIN) fmt --check $$f >/dev/null || echo "unformatted: $$f"; done

clean:
	rm -rf $(BUILD)
