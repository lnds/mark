---
paths:
  - "mark/tty.kai"
  - "mark/pager.kai"
  - "mark/finder.kai"
  - "mark/image.kai"
  - "mark/convert.kai"
---

# The terminal edge

These are the modules allowed to ask the terminal something or write to it directly.
`tty.kai`, `pager.run`, `finder.run`, `image.detect` and `image.install` are the whole
surface; everything else stays pure.

Both TUIs keep the same split: `Model`, the movement, `viewport`, `status` and `step` are
**pure**, so scrolling and key handling are tested by equality with no TUI to stand up,
and only `run` touches a terminal.

## terevaka

`terevaka` (github.com/kaikailang-org/terevaka, pinned in `kai.lock`) is the ecosystem's
TUI framework. It is **TEA**: a `Model`, an `update(model, key) -> Step[m]` and a
`view(model) -> Ui`; `app.run` owns raw mode, the input loop, painting and teardown.

| Module | For what |
|---|---|
| `terevaka.app` | `run` / `run_overlay`, `Step[m]` (`keep` / `quit`). The loop. |
| `terevaka.ui` | The `Ui` value tree and `render(Ui) : [String]`. **Pure** — views test by equality. |
| `terevaka.term` | Raw mode, `poll_key`, `probe`, `rows`/`cols`, ANSI builders. The only one carrying `Ffi`. |
| `terevaka.widget.*` | `menu`, `listbox`, `input`, `form`, `popup`, `confirm`, `statusbar`, `board`. |

**`app.paint_frame` paints from row 2, column 4.** A frame sized as if the origin were
(1,1) overflows: the terminal wraps the excess and, when that lands on the last row, the
scroll shifts the whole frame and leaves scraps down the left edge. `pager.margin()` and
`pager.body_rows()` exist for this.

Limits that affect mark: no mouse, no `SIGWINCH` (resizing does not repaint), and the
widgets are value state machines rather than fibers. The pager does not use
`widget.listbox`: its lines come already painted and fitted by the renderer, and cutting
them by columns again would split an escape sequence.

**The two width functions are not interchangeable.** `text.display_width` counts every
codepoint it is given, escape sequences included: on `"\e[1mhola\e[0m"` it says 12.
`ui.visible_len` discounts them first and says 4. Text that still carries ANSI — a status
bar, a placeholder grid — is measured with `visible_len`; `display_width` is for text with
none yet, which inside the renderer means everything before the painting pass.

**A TUI needs both descriptors.** `tty.is_terminal` asks about stdout, which is right for
colour and width and wrong for opening a TUI — that also needs a stdin to take keys from.
`tty.is_interactive` asks about both.

## Images

Drawn on a line of their own, when the terminal says it can. kitty is **asked** — it
defines a capability query whose answer is the capability, and a terminal that does not
speak it stays silent. iTerm2 defines no query and is recognised from `LC_TERMINAL` and
`TERM_PROGRAM`, which is weaker and says so.

**Placed, not drawn.** Under kitty the image is transmitted once, given a virtual
placement, and shown through placeholder cells that occupy one column each — so the pager
measures, scrolls and clips it like prose, and the picture lives inside the pager instead
of displacing it. iTerm2 has no placement mechanism, so there the picture is drawn where
the cursor stands and displaces the pager mark would have opened on its own — though not a
`-p` that asked for it.

**Named, not spelled out.** When the terminal shares this filesystem the payload is the
path (`t=f`), so a 3.5 MB image costs what a small one costs: 0.09s against 2.2s, and 156
bytes of output against 4.7 MB. Over ssh — `SSH_CONNECTION` or `SSH_TTY` — there is no
shared filesystem and the bytes travel as base64.

kitty takes **PNG and nothing else**, so any other format goes to whatever converter the
machine has (`sips`, ImageMagick, ffmpeg). None installed means the picture keeps its alt
text: nothing in `convert.kai` is required. A converter's stderr is piped so a missing one
leaves no `execvp` complaint on ours.

A relative source is resolved against the **document's** directory, not the one mark was
run from: `./shutup.jpg` means beside the file that named it.

Everything that cannot be drawn falls back to the alt text — a terminal that cannot, a
file that cannot be read, output that is not a terminal, `--images never`.
