# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What mark is

A markdown viewer for the terminal in the spirit of
[glow](https://github.com/charmbracelet/glow), written in **kaikai**. Two modes, like
glow: a CLI that renders a file (or stdin) to ANSI and exits, and a pager that walks it on
screen.

**Actual state:** the CLI and the pager work end to end — arguments, block parser, inline
scanner, theme, ANSI renderer and paging over terevaka, with 53 tests and 2 property
checks green. What is missing is the **file finder** (`mark/finder.kai` over
`fs.dir.walk`): with no arguments `mark` prints the help, and that is where it would go.

Deliberately out of scope: automatic light/dark background detection via OSC 11 —
`--style` settles it by hand.

**When it pages:** only with a terminal on the output and a document that does not fit in
it. Never when the input came from stdin — the pager reads its keys from that same
descriptor, which by then is exhausted, leaving it no way to be told to quit. `-p` and
`-P` force either side.

## Commands

`kai build .` is enough — **nothing in the build is load-bearing on `make` any more**.
terevaka declares its terminal shim in its own manifest (`[native]`, needs kai 0.112+), so
the driver compiles and links it for `build`, `run`, `test` and `install`, transitively.
mark therefore installs like any other package:

```sh
kai install github.com/lnds/mark    # or `kai install .` from a clone
```

**Never put terevaka's shim back into `CFLAGS`.** The two channels do not deduplicate:
the same translation unit arriving from `[native]` and from `CFLAGS` is linked twice and
the build dies with `ld: 6 duplicate symbols` on `kai_tvk_raw_enable` and its
neighbours. `KAI_NATIVE_DEPS=0` turns the `[native]` channel off if some build ever needs
the old way.

`kai build .` needs its `-o`: the default output name is the package name, `mark`, which
collides with the `mark/` source directory (`ld: ... errno=21 (Is a directory)`).

The `Makefile` is now shorthand, not machinery:

```sh
make              # kai build . -o build/mark (creates build/ first)
make install      # copies to ~/bin (PREFIX overrides) — `kai install .` is the usual path
make run
make test         # kai test . (root package plus each file in tests/)
make check        # property checks, file by file
make lint         # kai lint .
make fmt          # canonical formatting, file by file
make fmt-check    # names the files that are not formatted, without touching them
make deps         # kai fetch (regenerates kai.lock from kai.toml)
make clean
```

The fast loop is `kai typecheck .`, which answers "does it compile?" from the front end,
several times faster than a build: `typecheck` → patch → repeat, and `make` once at the
end. For programmatic consumption there are the JSON variants (`kai typecheck .
--diags-json`, `kai build --holes-json`).

A single test: `kai test tests/cli_test.kai`. `kai test .` compiles the root package and
each `*.kai` under `tests/` separately — a `0/0 tests passed` followed by `1/1` is
expected, not a failure. **`kai check .` does not do the same**: it stays in the root
package and never descends into `tests/`, which is why the target walks the files one by
one.

## Learn kaikai before writing it

kaikai has little presence in training corpora; **do not extrapolate from Rust, Go, Python
or Haskell**. The tooling exists for this and is cheaper than reading sources:

1. `kai doc <module>.<symbol>` — one signature and its doc. The default move.
2. `kai info deltas` — once per session: the ~60 lines of collisions with other languages
   (`#` for comments, `:=` to assign, `++` concatenates, no `return`, no `for x in xs`).
3. `kai info idiomatic` — **read this before writing much code.** It pairs each idiom with
   the wrong reach from another language; skipping it is what produced nested `else { if }`
   ladders and sentinel return values in this repo, both since fixed.
4. `kai info syntax` — the sheet of every form that exists. If a form is not there it does
   not exist: its *NOT IN KAIKAI* section is the truth.
5. `kai info <topic>` in full only when stuck on that specific thing.

For the unknown, write a typed hole `?` and let the compiler tell you the expected type
and what is in scope: `kai build --holes <file>`.

The language moves fast: **verify before assuming something is absent** just because this
file called it absent under an older version.

## Architecture

The decision that orders the whole project: **the markdown pipeline is pure and I/O lives
at the edge.** In kaikai effects are part of the type, so the split is not a convention —
the typer holds it up.

```
argv/stdin/file            parse           render             output
  (File+Env+Stdin)   ->    pure     ->      pure      ->   (Stdout | Ffi)
                        String          [Block]        [String]
                        -> [Block]      -> [String] with ANSI
```

- `mark/cli.kai` — arguments to `Opts` (`source`, `width`, `style`, `color`, `pager`), a
  pure function over `[String]`. What depends on the environment is left unset
  (`width == 0`, `style == "auto"`) for `main` to resolve.
- `mark/ast.kai` — blocks (heading, paragraph, list, code fence, quote, table, rule) and
  inline (emphasis, code, link).
- `mark/parser.kai` — `String -> [Block]`. Containers de-indent their lines and re-enter
  `blocks`, so nesting falls out of the recursion. Two shapes are decided by position
  rather than by prefix, and both live where the ambiguity is: a setext underline is
  recognised inside `take_para`, since `---` is a rule standing alone and a heading with a
  paragraph above it; and indented code goes **first** in `block_at`'s recogniser list,
  because every other recogniser trims the indent away before it looks at the line. A
  table is the third: it is two lines before it is one, and the delimiter row must carry a
  pipe of its own — otherwise `Title` over `-----` opens a one-column table instead of the
  setext heading it is.
- `mark/inline.kai` — the text of a line to `[Inline]`. An unclosed delimiter **degrades
  to literal text**: ambiguity never loses content.
- `mark/render.kai` — `[Block] -> [String]` with ANSI, at a given width.
- `mark/theme.kai` — the codes per element (`dark`/`light`/`plain`), as values.
- `mark/pager.kai` — the viewport over the already-rendered lines. `Model`, `scroll`,
  `viewport`, `status` and `step` are **pure**; only `run` touches the terminal, so
  scrolling is tested by equality with no TUI to stand up.
- `mark/tty.kai` — where terminal questions live. `is_terminal` rides `Stdout.is_tty()`,
  but the size still needs terevaka's shim, so this is the only module carrying `Ffi`.
- `main.kai` — the only place declaring the full effect row.

**Wrap before painting.** An ANSI code occupies no columns, so measuring already-coloured
text overcounts. Text travels as `[Cell]` (a codepoint plus its style), is cut into words
measuring with `text.display_width`, and only the last pass emits the sequences. Inverting
that order is the classic renderer bug.

Why the purity matters: parser, renderer and theme stay checkable by structural equality
with `test` and `check`, with no terminal to stand up and no disk to touch. The theme
defines its own sequences instead of importing them from `terevaka.term` for exactly that
reason. Any function in those modules needing an effect row is a sign that logic leaked
into the wrong place.

## Performance: the lists are linked

`acc ++ [x]` inside a recursion **copies the whole accumulator on every step**. This is
the performance trap of this project: it cost a render quadratic in paragraph length — 28s
against 0.36s over the same volume of text — and no test catches it, only a clock over a
big document.

The rules the code follows:

- **Accumulate at the front and reverse once.** `[x, ...acc]` is O(1); one `list.reverse`
  at the end is a single pass. Applies across `inline`, `render`, `parser` and
  `read_stdin`.
- **`[x, ...xs]`, not `[x] ++ xs`.** The cons form builds the cell directly; `++` builds a
  one-element list only to concatenate it. It takes several elements too: `[a, b, ...xs]`.
- **Do not recompute what you can carry.** `place` used to measure the whole line for
  every word placed on it; carrying the width inside `Run` made it O(1).
- **Gather fragments and `string.join` once.** Growing a `String` with `out ++ c`
  reallocates the entire prefix per character.

To measure, what works is fixing the volume of text and varying the line length: if the
time changes, something inside the line is quadratic. A fence of the same size (which
skips the inline scanner and the wrap) isolates how much of it belongs to the parser.

## terevaka: the TUI layer

`terevaka` (github.com/kaikailang-org/terevaka, pinned by sha in `kai.lock`) is the
ecosystem's TUI framework. Verified: compiles and runs with kai 0.113.0. The pin is a
`main` sha past the v0.1.4 tag, for the still-unreleased commit that moved the C shim into
the manifest's `[native]` table; `kai.lock` keeps the build reproducible regardless.

It is **TEA (Elm Architecture)**: you define a `Model`, an `update(model, key) -> Step[m]`
and a `view(model) -> Ui`; `app.run` owns raw mode, the input loop, painting and teardown.
The repaint is in place and only when the frame changes, so it does not flicker.

| Module | For what |
|---|---|
| `terevaka.app` | `run` / `run_overlay`, `Step[m]` (`keep` / `quit`). The loop. |
| `terevaka.ui` | The `Ui` value tree (`Text`/`Row`/`Col`/`Box`/`Pad`) and `render(Ui) : [String]`. **Pure** — views are tested by equality. |
| `terevaka.term` | Raw mode, `poll_key`, `rows`/`cols`, ANSI builders. The only one carrying `Ffi`. |
| `terevaka.widget.*` | `menu`, `listbox` (with scroll), `input`, `form`, `popup`, `confirm`, `statusbar`, `board`. |

**`app.paint_frame` paints from row 2, column 4.** A frame sized as if the origin were
(1,1) overflows: the terminal wraps the excess and, when that lands on the last row, the
scroll shifts the whole frame and leaves scraps down the left edge. `pager.margin()` and
`pager.body_rows()` exist for this.

Limits that affect mark: no mouse and no `SIGWINCH` handling (resizing the terminal does
not repaint), and the widgets are value state machines rather than fibers. terevaka is
kept for one reason only: the terminal size (`term.rows`/`term.cols`), which the stdlib
still does not expose.

The pager does not use `widget.listbox`: its lines already come painted and fitted to the
width by the renderer, and cutting them by columns again would split an escape sequence.
The hand-rolled viewport is half a dozen pure functions over `[String]`.

For measuring width use `text.display_width` from the stdlib. terevaka's `visible_len`
already delegates to it, so it is the right tool for measuring text that **contains** ANSI,
which is what the status bar needs.

## Traps verified in this project

Every one of these cost a compile cycle here; do not repeat them.

- **`#[derive(...)]` on a *record* breaks the `{ ...o }` spread** — `unknown record type X
  in '...' spread`. On a sum type it does not. `cli.Opts` goes without `derive` because of
  this; `pager.Model` keeps the derive and spells its fields out one by one.
  ([kaikai#1719](https://github.com/lnds/kaikai/issues/1719))
- **A private name captures the name package-wide — types and functions alike.** A `type
  Step` local to one module made `terevaka.app`'s `pub type Step[m]` unreachable from
  another module that never mentions it, and qualifying as `app.Step` does not help. The
  same goes for `fn`: a private `fits` added to `mark/render.kai` collided with an
  unrelated private `fits` in `tests/props_test.kai`, and the error — `wrong number of
  arguments to fits` — named neither the other file nor the collision.
  ([kaikai#1726](https://github.com/lnds/kaikai/issues/1726))
- **Match arms on one line are separated by `;`, not `,`.** A comma gives `expected
  pattern`.
- **`text.char_width` takes an `Int`, not a `Char`** — `char_to_int(c)` first. The error
  shows up at link time, not in `kai typecheck`: it is a *deferred field access*, so a
  clean `typecheck` does not guarantee the char arithmetic type-checks.
- **A `#` comment between `#[doc("...")]` and its declaration disconnects them**, and the
  doc is read as the module doc — `second module-level #[doc(...)]` if the file already had
  one. The comment goes **before** the `#[doc]`, never between.
- **The multi-line form is `"""`, not `"`.** A newline inside single quotes is a lexer
  error (`unterminated string`). The triple quote is an expression literal, interpolates
  `#{...}` just like the single one, and **keeps the content byte for byte**: it trims
  neither the newline after `"""` nor the indentation. Hence the text starting glued to the
  opening quotes (`"""mark #{version()} …`), or the first line comes out blank.
- **The stderr op is `Stderr.eprint`, not `print`.**
- **`fs.file.read` panics on any I/O failure.** That is its design; to handle the error,
  `File.read_file(path)` returns `Result[String, String]`.
- **A package importing `terevaka.ui` runs terevaka's tests too.** A red line there is not
  necessarily this project's — check whose file it is before chasing it.
- **`kai fmt .` formats the entry point and nothing else.** It walks no further into the
  package, and exits 0 as though it had — so a tree it calls clean can be entirely
  unformatted. `make fmt` and `make fmt-check` loop over the files one by one for the same
  reason `make check` does. Verified on 0.113.0: mangling `mark/theme.kai` and running
  `kai fmt .` leaves the damage untouched.
- **`kai fmt` inserts a blank line between consecutive imports.** Not a style choice to
  adopt: kaikai's own self-hosted sources hold 1368 adjacent import pairs across 152 files,
  which the formatter would rewrite. This is why the tree is deliberately left unformatted
  under 0.113.0 — running `make fmt` today spreads the import blocks apart in all 16 files.

Traps that **no longer are** (they were here, and were fixed upstream; do not assume them
current if you read older code): the `Int` from `main` is the exit code, binary operators
do continue an expression from the start of a line, `string.trim_left`/`trim_right` and
`string.from_chars` exist, `pub const` does cross the module boundary, `Stdout.is_tty()`
removed the need for a hand-written `isatty` shim, `kai lint` no longer reports
`#[derive]` impls as dead code, and terevaka's shim no longer travels in `CFLAGS` — it is
declared in its manifest's `[native]` table.

`pager.kai` used to carry a counter for the last of those: `terevaka.term` reported EOF and
an undecodable key both as `Key::Unknown`, so a closed descriptor spun the loop at 100% CPU
and `blind_limit` cut it off after 200 in a row. terevaka 0.1.4 closed it
([terevaka#6](https://github.com/kaikailang-org/terevaka/issues/6)): `Key` gained `Eof` and
`app.run` ends the loop on it, before `step` is ever called. The counter, `Model.blind` and
their two tests are gone.

**String literals do have unicode escapes**, since
[kaikai#1720](https://github.com/lnds/kaikai/issues/1720) closed on 2026-08-10. Verified on
0.113.0: `"\u{1b}"` is a real ESC, `"\u{263A}"` and the astral `"\u{1F600}"` come out as
correct UTF-8, and `"\x1b"` works too. An unknown escape is now a **hard error** naming the
sequence, not a silently dropped backslash. `theme.esc` still builds ESC with
`int_to_char(27)`, which is no longer necessary — a plain `"\u{1b}"` would do.

The lesson each of those teaches is the same: **this file ages faster than the language**.
Before working around something it calls missing, spend the thirty seconds to check.

## Conventions

**Everything in this repository is in English** — code, comments, `#[doc]`, test names,
user-facing text, and this file. Conversation with the user happens in Spanish; the
repository does not.

Comments are short and explain the timeless why. No ticket, branch or phase references
inside the code: that belongs in the commit message.

Item docs are `#[doc("...")]` **before** `pub`, never `///`.
