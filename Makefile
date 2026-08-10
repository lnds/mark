# mark — a markdown viewer for the terminal, in kaikai.
#
# terevaka drives the terminal through a C shim (c/terevaka_term.{c,h})
# and `kai build` injects no link flags: the shim travels in CFLAGS, the
# header via -include and the .c as a translation unit the driver hands
# to the C compiler. That is why the build goes through make rather than
# a bare `kai build`. Only terevaka needs this — the stdlib covers
# everything else mark asks of the terminal.

KAI_BIN ?= kai
BUILD   := build

# kai-pkg package cache: $KAIKAI_CACHE, or the per-OS default.
KAIKAI_CACHE ?= $(if $(filter Darwin,$(shell uname -s)),$(HOME)/Library/Caches/kai/pkg,$(HOME)/.cache/kai/pkg)

# terevaka's sha comes from kai.lock rather than being pinned by hand:
# `kai update` moves it and the build still points at the right
# checkout.
TVK_SHA  := $(shell awk '/^name = "terevaka"/{f=1} f && /^sha = /{gsub(/[",]/,"",$$3); print $$3; exit}' kai.lock)
TVK_ROOT := $(KAIKAI_CACHE)/github.com/kaikailang-org/terevaka/$(TVK_SHA)
TVK_SHIM := $(TVK_ROOT)/c/terevaka_term

KAI_CFLAGS := -std=c99 -O2 -include $(TVK_SHIM).h $(TVK_SHIM).c

SRC := main.kai $(wildcard mark/*.kai)

.PHONY: all run test lint fmt check clean deps install uninstall

all: $(BUILD)/mark

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/mark: $(SRC) kai.lock | $(BUILD)
	CFLAGS="$(KAI_CFLAGS)" $(KAI_BIN) build . -o $@

kai.lock: kai.toml
	$(KAI_BIN) install

deps: kai.lock

# The binary is copied, not linked: a symlink into the build tree
# leaves the command broken after a `make clean`.
PREFIX ?= $(HOME)

install: all
	mkdir -p $(PREFIX)/bin
	cp $(BUILD)/mark $(PREFIX)/bin/mark

uninstall:
	rm -f $(PREFIX)/bin/mark

run: all
	./$(BUILD)/mark

test:
	CFLAGS="$(KAI_CFLAGS)" $(KAI_BIN) test .

# `kai check .` only looks at the root package: unlike `kai test` it
# does not descend into tests/, so the files go one by one.
check:
	@for f in tests/*.kai; do CFLAGS="$(KAI_CFLAGS)" $(KAI_BIN) check $$f; done

lint:
	$(KAI_BIN) lint .

fmt:
	$(KAI_BIN) fmt .

clean:
	rm -rf $(BUILD)
