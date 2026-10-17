# mark

A markdown viewer for the terminal in the spirit of
[glow](https://github.com/charmbracelet/glow), written in **kaikai**. Two modes, like
glow: a CLI that renders a file (or stdin) to ANSI and exits, and a pager that walks it on
screen. Pointed at a directory — or at nothing — it opens a picker over the markdown under
it instead.

**State:** complete for what it set out to do, with 160 tests and 2 property checks green
on **kai 0.161.0**. It renders GFM: headings both forms, wrapped paragraphs, fenced and
indented code, nested quotes, lists with sublists and task boxes, tables, footnotes,
strikethrough, every link spelling, entities, hard breaks, and images drawn through the
kitty or iTerm2 protocol.

Deliberately out of scope: automatic light/dark detection via OSC 11 — `--style` settles
it by hand.

## Project language

Code, comments, `#[doc]`, test names, commit messages, user-facing text and documentation
are **English only**. Conversation with the user happens in Spanish and does not reach the
repository.

## The shape

The decision that orders everything: **the markdown pipeline is pure and I/O lives at the
edge.** In kaikai effects are part of the type, so the typer holds the split up rather
than a convention.

| Piece | Role | Effects |
|---|---|---|
| `cli`, `ast`, `parser`, `inline`, `render`, `theme` | source text to ANSI lines | none — tested by structural equality |
| `pager`, `finder` | the two TUIs over already-rendered lines | pure model; only `run` touches a terminal |
| `tty`, `image`, `convert` | what has to be asked of the terminal, and drawing on it | `Ffi`, `Env`, `Process` |
| `main` | resolves argv, the terminal and the disk, then hands the rest to the pure part | the full row |

## Layout

```
main.kai            entry point; the only place declaring the full effect row
mark/*.kai          the modules above; `mark/<file>.kai` imports as `mark.<file>`
tests/*_test.kai    one per module, plus version_test.kai
examples/           images.md and the two PNGs it draws
```

## Commands

`kai build . -o build/mark` is enough — **nothing in the build is load-bearing on `make`**.
The `-o` is not optional: the default output name is the package name, which collides
with the `mark/` source directory (`ld: ... errno=21 (Is a directory)`). terevaka
declares its terminal shim in its own `[native]` table, so the driver links it
transitively and mark installs like any other package: `kai install .`.

The fast loop is `kai typecheck .`, several times faster than a build. `make test`, `make
lint`, `make fmt-check`, `make check` (property checks, file by file), `make bump`.

`kai test .` compiles the root package and each file under `tests/` separately — a `0/0
tests passed` followed by `1/1` is expected, not a failure — and **aborts at the first
file that fails to compile**, so a green tail does not mean every file ran. `kai check .`
stays in the root package and never descends into `tests/`, which is why that target walks
the files one by one.

## Detailed rules

Topic rules live in `.claude/rules/` and load by path:

- `kaikai-code.md` — writing kaikai: the tooling, the import model, the traps.
- `pipeline.md` — the pure core: what each module owes, wrapping, the performance trap.
- `terminal.md` — terevaka, the TUIs, the image protocols.
- `git.md` — commits, `cz bump`, the version guard.

## Things to avoid

- **Do not put terevaka's shim into `CFLAGS`.** The two channels do not deduplicate: the
  same translation unit from `[native]` and from `CFLAGS` links twice and the build dies
  with `ld: 6 duplicate symbols`. `KAI_NATIVE_DEPS=0` turns `[native]` off if ever needed.
- **Do not let an effect row into the pure modules.** A parser or renderer function that
  needs one is logic that leaked out of `main`.
- **Do not measure painted text with `text.display_width`.** It counts escape bytes; see
  `terminal.md`.
- **Do not work around a kaikai gap silently.** Open an issue on `lnds/kaikai` with a
  reproduction, as `#2120` and `#2121` were.
- **Do not edit `CHANGELOG.md` or either version by hand.** `cz bump` owns both.
