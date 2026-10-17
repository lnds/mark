---
paths:
  - "main.kai"
  - "mark/**/*.kai"
---

# The markdown pipeline

The decision that orders the project: **the pipeline is pure and I/O lives at the edge.**
In kaikai effects are part of the type, so the split is not a convention — the typer holds
it up.

```
argv/stdin/file            parse           render             output
  (File+Env+Stdin)   ->    pure     ->      pure      ->   (Stdout | Ffi)
                        String          [Block]        [String]
                        -> [Block]      -> [String] with ANSI
```

Parser, renderer and theme stay checkable by structural equality with `test` and `check`,
with no terminal to stand up and no disk to touch. The theme defines its own ANSI
sequences instead of importing them from `terevaka.term` for exactly that reason. **Any
function in those modules needing an effect row is a sign that logic leaked into the wrong
place.**

## What each module owes

- `cli.kai` — arguments to `Opts`, a pure function over `[String]`. What depends on the
  environment is left unset (`width == 0`, `style == "auto"`) for `main` to resolve.
- `ast.kai` — the document as a value. Some shapes exist to be **resolved away** rather
  than rendered: `Item.task` is the box a list item opened with, `Ref` is a reference link
  `parse` settles once every definition has been read, and `NoteRef` is a footnote marker
  before `parse` numbers it.
- `parser.kai` — `String -> [Block]`. Containers de-indent their lines and re-enter
  `blocks`, so nesting falls out of the recursion. Three shapes are decided by position
  rather than prefix, and each lives where its ambiguity is: a setext underline is
  recognised inside `take_para`, since `---` alone is a rule and over a paragraph is a
  heading; indented code goes **first** in `block_at`'s recogniser list, because every
  other recogniser trims the indent away before looking; and a table is two lines before
  it is one, its delimiter row needing a pipe of its own — otherwise `Title` over `-----`
  opens a one-column table instead of the setext heading it is.
- `inline.kai` — a line's text to `[Inline]`. An unclosed delimiter **degrades to literal
  text**: ambiguity never loses content.
- `render.kai` — `[Block] -> [String]` with ANSI, at a given width.
- `theme.kai` — the codes per element (`dark`/`light`/`plain`), as values.
- `main.kai` — the only place declaring the full effect row.

## Wrap before painting

An ANSI code occupies no columns, so measuring already-coloured text overcounts. Text
travels as `[Cell]` (a codepoint plus its style), is cut into words measuring with
`text.display_width`, and only the last pass emits the sequences. Inverting that order is
the classic renderer bug.

## The lists are linked

`acc ++ [x]` inside a recursion **copies the whole accumulator on every step**. This is
the performance trap of this project: it cost a render quadratic in paragraph length — 28s
against 0.36s over the same text — and no test catches it, only a clock over a big
document.

- **Accumulate at the front and reverse once.** `[x, ...acc]` is O(1); one `list.reverse`
  at the end is a single pass. Applies across `inline`, `render`, `parser`, `read_stdin`.
- **`[x, ...xs]`, not `[x] ++ xs`.** The cons form builds the cell directly; `++` builds a
  one-element list only to concatenate it. It takes several: `[a, b, ...xs]`.
- **Do not recompute what you can carry.** `place` used to measure the whole line for every
  word placed on it; carrying the width inside `Run` made it O(1).
- **Gather fragments and `string.join` once.** Growing a `String` with `out ++ c`
  reallocates the entire prefix per character.

To measure, fix the volume of text and vary the line length: if the time changes,
something inside the line is quadratic. A fence of the same size — which skips the inline
scanner and the wrap — isolates how much belongs to the parser.
