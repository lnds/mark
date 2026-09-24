# mark

A markdown viewer for the terminal, in the spirit of
[glow](https://github.com/charmbracelet/glow), written in
[kaikai](https://kaikai-lang.org).

Two modes, like glow: a CLI that renders a file (or stdin) to ANSI and exits,
and a pager that walks it on screen. Pointed at a directory — or at nothing at
all — it opens a picker over the markdown under it instead.

```sh
mark README.md          # render, paging if it does not fit
mark                    # pick a file from the tree at hand
mark docs/               # pick one from somewhere else
mark -w 100 doc.md      # at a given width
cat doc.md | mark -     # from stdin
mark -P doc.md | less    # dump, no pager
```

## Install

mark is built from source, so you need the kaikai compiler first — **0.121 or
later**, which is what the sources are verified against. Either installer
works; the binary is self-contained and needs no system LLVM:

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

Then install mark, straight from the repository:

```sh
kai install github.com/lnds/mark      # -> ~/.kaikai/bin/mark, already on PATH
```

That is the whole thing: the dependency is fetched, the terminal shim it binds
comes declared in its own manifest, and the binary lands in `$KAIKAI_HOME/bin`.
Pass `--force` to replace an install already there.

From a clone, if you want the source too:

```sh
git clone https://github.com/lnds/mark
cd mark
kai install .   # -> ~/.kaikai/bin/mark
make            # -> build/mark, to run it from the tree
```

Build it by hand with `kai build . -o build/mark`, creating `build/` first — the
`-o` is not optional here, since the default output name would be `mark` and
collide with the `mark/` source directory. `make` is only shorthand for that and
the commands below; nothing depends on it. `make install` copies to `~/bin`
instead (`PREFIX=/usr/local` for `/usr/local/bin`).

## Shell completion

`completions/` carries one for zsh, bash and fish. All three complete the
flags, the values `--style` and `--color` accept, and the documents: only the
markdown files when the directory has any — a README should not come surrounded
by its images and scripts — and every file when it has none, since mark renders
any text it is handed.

```sh
make install-completions          # each shell whose directory exists; the rest are skipped
```

Override any destination: `ZSH_COMPLETION_DIR`, `BASH_COMPLETION_DIR`,
`FISH_COMPLETION_DIR`. Or install one shell at a time with
`make install-completion-zsh` and its `-bash` / `-fish` siblings. Then start a
new shell; zsh also caches, so `rm -f ~/.zcompdump* && compinit`.

### zsh needs to come first in `$fpath`, not merely be in it

zsh ships a completion for [MH](https://www.nongnu.org/nmh/), the 1980s mail
handler, and `mark` is one of MH's commands — so the stock `_mh` claims the
name. With MH absent it returns non-zero, which *suppresses* the default file
completion rather than falling back to it, and `mark <TAB>` offers nothing at
all. Homebrew's `site-functions` and oh-my-zsh's `custom/completions` both sort
ahead of `/usr/share/zsh/*/functions`, so either wins. Without installing
anything, `compdef _files mark` in `~/.zshrc` at least restores plain file
completion.

bash and fish have no such collision; there the completion only adds.

## Usage

```
usage:
  mark <file.md>         render a file
  mark <dir>             choose a file from the tree under it
  mark                   the same, for the directory at hand
  mark -                 render whatever arrives on stdin
  mark -h | --help       this help
  mark -v | --version    the version

options:
  -w, --width <n>        output width (default: the terminal's, capped at 80)
  -s, --style <style>    dark | light | auto
      --color <when>     auto | always | never (NO_COLOR also disables it)
  -p, --pager            page even when the text fits on screen
  -P, --no-pager         dump everything at once, without paging
      --images <when>    auto | kitty | iterm | never (under kitty they page;
                         an iTerm2 one skips the pager unless -p asked for it)
```

In the pager: `j`/`k` or arrows scroll a line, `space`/`b` a page, `d`/`u` half
a page, `g`/`G` jump to the ends, `q` or `Esc` quits.

In the file picker the same keys move, `enter` opens the entry under the cursor
and `q` leaves without opening anything. It lists `.md`, `.markdown`, `.mdown`
and `.mkd`, recursively, sorted — and, needing a terminal to choose in, it says
so instead of opening when there is none.

Paging happens when there is a terminal to page in and the document does not fit
in it — never when the input came from stdin, since the pager reads its keys
from that same descriptor and by then it is exhausted.

Colour follows the usual convention: on for a terminal, off for a pipe or a
file, off when `NO_COLOR` is set, and whatever `--color` says over all of it.

## What it renders

Headings — both `#` and the underlined setext form — paragraphs with word
wrapping, code both fenced and indented four spaces, nested quotes, bullet and
ordered lists with sublists and task boxes, tables, horizontal rules; and
inline: emphasis, strong, strikethrough, code spans, links, character entities
and backslash escapes. A YAML or TOML front matter block is metadata and is
skipped rather than shown.

Links come in every spelling: `[text](dest)`, the reference forms
`[text][label]`, `[label][]` and a bare `[label]` resolved against a
`[label]: dest` line anywhere in the document, `<https://autolinks>` and bare
addresses written with no markup at all. The destination is printed after the
label, since a terminal has nowhere to hide it — except where the label already
is the destination, which is every autolink. A reference nothing defines keeps
its brackets rather than vanishing. Two trailing spaces, or a trailing
backslash, break the line where the source insists on it.

HTML is not rendered and not shown either: a tag is dropped and the text inside
it kept, so a paragraph wrapped in `<div>` reads as the sentence it holds.

**Images** are drawn when the terminal can draw them. kitty is asked with its
own capability query — an emulator that does not speak the protocol stays
silent, which is the answer — and iTerm2, which defines no query, is recognised
from `LC_TERMINAL` and `TERM_PROGRAM`. `--images` settles it by hand: `auto`,
`kitty`, `iterm` or `never`.

A paragraph that is nothing but images draws all of them, side by side, and
wraps to a new band when the width runs out. One image sharing a line with
words keeps its alt text, which is also what is left when the terminal cannot
draw, when the file cannot be read, and when the output is not a terminal at
all.
Under kitty a picture is **placed**, not drawn: it is transmitted once, given a
virtual placement, and shown through placeholder cells one column wide each.
Those measure, scroll and clip like ordinary text, so the picture lives inside
the pager instead of displacing it. iTerm2 has no placement mechanism, so there
the picture is drawn where the cursor stands, which the pager cannot repaint —
it displaces the pager mark would have opened on its own, but not a `-p` that
asked for it by name. See `examples/images.md`.

Tables are drawn with a box-drawing frame and honour the alignments the
delimiter row declares (`:--`, `:-:`, `--:`). A table too wide for the terminal
is squeezed rather than cut off: the columns share the space that is left, the
ones that already fitted keep their width, and text that no longer fits its
column wraps inside the cell instead of being dropped.

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
make fmt          # kai fmt . (canonical formatting, whole package)
```

`kai test` on a package that imports `terevaka.ui` also runs terevaka's own test
blocks, so a red line there may not be this project's.

`CLAUDE.md` carries the working notes: verified traps, the performance rules
that matter with linked lists, and how to find your way around kaikai.

## Licence

Dual-licensed under [MIT](LICENSE-MIT) or [Apache 2.0](LICENSE-APACHE), at your
option — the same terms as kaikai itself.
