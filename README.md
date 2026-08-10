# mark

A markdown viewer for the terminal, in the spirit of
[glow](https://github.com/charmbracelet/glow), written in
[kaikai](https://kaikai-lang.org).

Two modes, like glow: a CLI that renders a file (or stdin) to ANSI and exits,
and a pager that walks it on screen.

```sh
mark README.md          # render, paging if it does not fit
mark -w 100 doc.md      # at a given width
cat doc.md | mark -     # from stdin
mark -P doc.md | less    # dump, no pager
```

## Install

mark is built from source, so you need the kaikai compiler first — **0.110 or
later**. Either installer works; the binary is self-contained and needs no
system LLVM:

```sh
curl -fsSL https://raw.githubusercontent.com/kaikailang-org/kaikai/main/install.sh | sh
export PATH="$HOME/.kaikai/bin:$PATH"   # this shell; the installer persists it
```

or, with Homebrew:

```sh
brew install kaikailang-org/kaikai/kaikai
```

Already have it? `kai upgrade` self-updates in place (on a Homebrew install it
points you at `brew upgrade` instead).

Then build mark:

```sh
git clone https://github.com/lnds/mark
cd mark
make            # -> build/mark
make install    # -> ~/bin/mark   (PREFIX=/usr/local for /usr/local/bin)
```

The build goes through `make`, not a bare `kai build`: terevaka drives the
terminal through a C shim and `kai build` injects no link flags, so it travels in
`CFLAGS`. `make` fetches the dependency on first run.

## Usage

```
usage:
  mark <file.md>         render a file
  mark -                 render whatever arrives on stdin
  mark -h | --help       this help
  mark -v | --version    the version

options:
  -w, --width <n>        output width (default: the terminal's, capped at 80)
  -s, --style <style>    dark | light | auto
      --color <when>     auto | always | never (NO_COLOR also disables it)
  -p, --pager            page even when the text fits on screen
  -P, --no-pager         dump everything at once, without paging
```

In the pager: `j`/`k` or arrows scroll a line, `space`/`b` a page, `d`/`u` half
a page, `g`/`G` jump to the ends, `q` or `Esc` quits.

Paging happens when there is a terminal to page in and the document does not fit
in it — never when the input came from stdin, since the pager reads its keys
from that same descriptor and by then it is exhausted.

Colour follows the usual convention: on for a terminal, off for a pipe or a
file, off when `NO_COLOR` is set, and whatever `--color` says over all of it.

## What it renders

Headings, paragraphs with word wrapping, fenced code, nested quotes, bullet and
ordered lists with sublists, horizontal rules; and inline: emphasis, strong,
code spans, links (with the destination shown, since a terminal has nowhere to
hide it) and backslash escapes.

Tables are out of scope for now — the parser treats them as paragraphs.

## Design

The markdown pipeline is pure and I/O lives at the edge. In kaikai effects are
part of the type, so the typer enforces the split rather than convention:

```
argv/stdin/file            parse           render             output
  (File+Env+Stdin)   ->    pure     ->      pure      ->   (Stdout | Ffi)
                        String          [Block]        [String]
                        -> [Block]      -> [String] with ANSI
```

`mark/tty.kai` is the only module carrying `Ffi`, and only for the terminal
size. Parser, renderer and theme are testable by structural equality, with no
terminal to stand up and no disk to touch.

Two decisions worth knowing before reading the code:

- **Wrap before painting.** An ANSI code occupies no columns, so measuring
  already-coloured text overcounts. Text travels as cells (a codepoint plus its
  style), is cut into words measuring with `text.display_width`, and only the
  last pass emits the sequences.
- **Ambiguity degrades, never discards.** An unclosed delimiter comes out as
  literal text rather than swallowing what follows it.

## Development

```sh
kai typecheck .   # the fast loop: front end only
make test         # kai test . (root package plus each file in tests/)
make check        # property checks, file by file
make lint
make fmt
```

`kai test` on a package that imports `terevaka.ui` also runs terevaka's own test
blocks, so a red line there may not be this project's.

`CLAUDE.md` carries the working notes: verified traps, the performance rules
that matter with linked lists, and how to find your way around kaikai.

## Licence

Dual-licensed under [MIT](LICENSE-MIT) or [Apache 2.0](LICENSE-APACHE), at your
option — the same terms as kaikai itself.
