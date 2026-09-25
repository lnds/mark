# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What mark is

A markdown viewer for the terminal in the spirit of
[glow](https://github.com/charmbracelet/glow), written in **kaikai**. Two modes, like
glow: a CLI that renders a file (or stdin) to ANSI and exits, and a pager that walks it on
screen. Pointed at a directory — or at nothing — it opens a picker over the markdown
under it instead.

**Actual state:** complete for what it set out to do — arguments, block parser, inline
scanner, theme, ANSI renderer, paging over terevaka and the file picker, with 100 tests
and 2 property checks green.

**Footnotes** are GFM's: `[^label]` in the text, `[^label]: ...` and whatever is
indented under it as the note. They are numbered by where the markers appear, not by
where the notes were written, and gathered under a rule at the foot. A marker nothing
defines keeps its brackets; a note nothing cites is not shown.

**Images** are drawn through the kitty or iTerm2 protocol, on a line of their own,
when the terminal says it can. Under kitty they are placed rather than drawn — shown
through placeholder cells that measure like text — so they survive inside the pager.
kitty takes PNG and nothing else, so `mark/convert.kai` hands any other format to
whatever converter the machine has. Everything else falls back to the alt text.

**The picture is named, not spelled out.** When the terminal shares this filesystem
the payload is the path (`t=f`), so a 3.5 MB image costs what a small one costs:
0.09s against 2.2s, and 156 bytes of output against 4.7 MB. Over ssh there is no
shared filesystem and the bytes travel as base64.

A relative image source is resolved against the **document's** directory, not the one
mark was run from: `./shutup.jpg` means beside the file that named it.

Deliberately out of scope: automatic light/dark background detection via OSC 11 —
`--style` settles it by hand.

**When it pages:** only with a terminal on the output and a document that does not fit in
it. Never when the input came from stdin — the pager reads its keys from that same
descriptor, which by then is exhausted, leaving it no way to be told to quit. `-p` and
`-P` force either side.

## Commands

The toolchain this tree is verified against is **kai 0.121.0**; the sources need at least
it, since `pager.Model` now uses the `{ ...m }` spread on a `#[derive]` record.

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
make fmt          # kai fmt . (canonical formatting, whole package)
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

**The `core/*` modules are auto-loaded** — `core/list`, `core/string`, `core/char`,
`core/option`, `core/result`, `core/tuple`, plus `protocols`, `effects` and `array` (the
full set is in `kai info builtins`). Importing them is noise: write `reverse(xs)`,
`trim(s)`, `xs.length()`. Their module names stay in scope too, so `list.repeat("", n)`
and `string.length(s)` work with no import — which is how a name that both modules own
gets disambiguated. Only the modules outside that set are imported: here `text`,
`math/int` and `terevaka.*`. Note `kai doc` spells the paths with a slash
(`kai doc core/list.foldl`), not the dot the `import` form uses.

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
- `mark/ast.kai` — blocks (heading, paragraph, list, code fence, quote, table, rule,
  footnotes) and inline (emphasis, strikethrough, code, link, footnote mark, hard break).
  Some of its shapes exist to be resolved away rather than rendered: `Item.task` is the box
  a list item opened with, `Ref` is a reference link that `parse` settles once every
  definition has been read, and `NoteRef` is a footnote marker before `parse` numbers it.
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
- `mark/convert.kai` — the image formats kitty will not take, handed to `sips`,
  ImageMagick or ffmpeg, whichever the machine has. Every one missing means the
  picture keeps its alt text: nothing here is required.
- `mark/image.kai` — whether the terminal draws pictures, and the escape sequence
  that draws one. `detect` asks (kitty has a capability query; iTerm2 has only the
  environment) and is the one effectful part; `sequence` is pure, bytes to escape
  sequence, so the chunking is tested without a terminal. The bytes themselves are
  read in `main`, which is what keeps `render` from ever touching a disk.
- `mark/finder.kai` — the picker over the markdown files under a root. Same split as the
  pager: `Model`, `move_to`, `viewport`, `status` and `step` are **pure**, and only `run`
  touches a terminal. Its walk is `File`, not `Ffi` — `fs.dir.walk` and nothing else.
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
ecosystem's TUI framework. Verified: compiles and runs with kai 0.121.0. The pin is a
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

**The two width functions are not interchangeable.** `text.display_width` counts every
codepoint it is given, escape sequences included: on `"\e[1mhola\e[0m"` it says 12.
terevaka's `ui.visible_len` discounts them first and says 4. So text that still carries
ANSI — a status bar, a placeholder grid — is measured with `visible_len`, and
`display_width` is for text that has none yet, which inside the renderer means everything
before the painting pass.

## Traps verified in this project

Every one of these cost a compile cycle here; do not repeat them.

- **A private `fn` takes its name for the whole package, over the auto-loaded `core/*`.**
  A private `starts_with([Char], [Char])` in `mark/inline.kai` hid `core/string`'s from
  `mark/parser.kai`, which never mentions it, and every error landed on the parser. Hence
  `opens_with`. Check `kai info builtins` before giving a private helper a common name.
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
- **Unqualified, `string` wins over `list`.** `repeat("", n)` resolves to `string.repeat`
  and yields `""`, never `[String]`; a `let` annotation does not steer it back. Qualify —
  the module name is in scope with no import, so `list.repeat("", n)` works as written, and
  `xs.length()` by UFCS too.
- **Importing `math/int` takes over the bare `max`/`min`.** `max(xs)` then fails with
  `int.max expects 2 arguments`. Same remedy: write `list.max(xs)`. `path` does it to
  `join` and `split`, which is why every `string.join` in this tree is spelled out.
- **A continuation line may not begin with `.`.** Binary operators do continue an
  expression across lines; a UFCS chain does not. Break the chain inside its parentheses.
- **`_` is not a lambda parameter.** `(i, _) => ...` is `expected `,` or `)` in call
  arguments`; give the one you ignore a name.
- **`list.map_indexed` is not tail-recursive.** It overflows the fiber stack on a list of
  a few million — which a 3.5 MB image is, one `Int` per byte. `enumerate(xs) | f` walks
  the same ground and survives it.
- **`base64.encode` is quadratic in the length of its list.** 3.5 M bytes take 72 seconds
  in one call and under a second in chunks of 3072. Measured, both ways.

**This file ages faster than the language.** Before working around something it calls
missing, spend the thirty seconds to check.

## Conventions

**Everything in this repository is in English** — code, comments, `#[doc]`, test names,
user-facing text, and this file. Conversation with the user happens in Spanish; the
repository does not.

Comments are short and explain the timeless why. No ticket, branch or phase references
inside the code: that belongs in the commit message.

Item docs are `#[doc("...")]` **before** `pub`, never `///`.
