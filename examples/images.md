---
title: images in mark
note: this front matter is skipped, not shown
---

# Images

An image **on a line of its own** is drawn by the terminal, if the
terminal can draw one:

![the mark banner](examples/banner.png)

mark asks before it draws. The kitty protocol defines a query whose
answer *is* the capability, so that one is asked rather than guessed;
iTerm2 defines no query, so it is recognised from `LC_TERMINAL` and
`TERM_PROGRAM`. Anything else gets the text below instead.

## When it falls back

An image that shares a line with text keeps its alt text, because an
escape sequence has no width and the wrap around it would break:
![a circle](examples/circle.png) — that one is still legible, which is
what alt text is for.

The same happens with `--images never`, inside the pager, when stdout
is not a terminal, and when the file cannot be read:

![this file does not exist](examples/missing.png)

## Reference form

Images take the reference spelling too, resolved against a definition
anywhere in the document:

![the circle again][circle]

## Everything else, for contrast

Ordinary [links](https://github.com/lnds/mark) still print their
destination, `code spans` stay raw, ~~strikethrough~~ works, and so do
entities like &mdash; and &hellip;

- [x] draw an image when the terminal says it can
- [x] fall back to alt text when it cannot
- [ ] decide what a *second* image on the same line should do

> A quote holds a picture too, on its own line:
>
> ![the banner, quoted](examples/banner.png)

| protocol | how it is detected | chunked |
|:---------|:-------------------|:-------:|
| kitty    | asked, via `probe` |   yes   |
| iTerm2   | environment only   |   no    |

[circle]: examples/circle.png
