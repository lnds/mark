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

.PHONY: all run test lint fmt check clean deps install uninstall install-completions

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

# The completion has to sort ahead of zsh's stock functions, where _mh
# claims the name `mark` for the MH mail handler. Homebrew's
# site-functions does; override for anywhere else on $fpath.
ZSH_COMPLETION_DIR ?= $(shell brew --prefix 2>/dev/null)/share/zsh/site-functions

install-completions:
	@test -d "$(ZSH_COMPLETION_DIR)" \
	  || { echo "no such directory: $(ZSH_COMPLETION_DIR)"; \
	       echo "set ZSH_COMPLETION_DIR to a directory on your \$$fpath"; exit 1; }
	cp completions/_mark $(ZSH_COMPLETION_DIR)/_mark
	@echo "installed. start a new shell, or: rm -f ~/.zcompdump* && compinit"

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

fmt:
	$(KAI_BIN) fmt .

clean:
	rm -rf $(BUILD)
