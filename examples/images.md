---
title: images in mark
note: this front matter is skipped, not shown
---

# Images

An image **on a line of its own** is drawn by the terminal, if the
terminal can draw one:

![the mark banner](banner.png)

mark asks before it draws. The kitty protocol defines a query whose
answer *is* the capability, so that one is asked rather than guessed;
iTerm2 defines no query, so it is recognised from `LC_TERMINAL` and
`TERM_PROGRAM`. Anything else gets the text below instead.

## When it falls back

An image that shares a line with text keeps its alt text, because an
escape sequence has no width and the wrap around it would break:
![a circle](circle.png) — that one is still legible, which is
what alt text is for.

A picture drawn through kitty is given a virtual placement and shown
through placeholder cells, which measure and scroll like any other
text — so it lives inside the pager rather than displacing it. iTerm2
has no placement mechanism, so there the picture is drawn where the
cursor stands and the pager is skipped.

The alt text is what is left with `--images never`, when stdout is not
a terminal, when the terminal cannot draw, and when the file cannot be
read:

![this file does not exist](missing.png)

## Two on a line

A paragraph that is nothing but images draws all of them, side by side,
wrapping to a new band when the width runs out:

![the banner](banner.png) ![the circle](circle.png)

One word among them and it is prose with pictures in it, which is a
different layout problem — that paragraph keeps its alt text.

## Reference form

Images take the reference spelling too, resolved against a definition
anywhere in the document:

![the circle again][circle]

## Other formats

kitty takes PNG and nothing else, so an image in any other format is
handed to whatever converter the machine has — `sips`, ImageMagick or
ffmpeg. iTerm2 needs no conversion: it takes what the system can open.
With no converter installed the picture keeps its alt text, quietly.

## Everything else, for contrast

Ordinary [links](https://github.com/lnds/mark) still print their
destination, `code spans` stay raw, ~~strikethrough~~ works, and so do
entities like &mdash; and &hellip;

- [x] draw an image when the terminal says it can
- [x] fall back to alt text when it cannot
- [x] keep the pager, by placing the image instead of drawing it
- [x] draw a second image on the same line, beside the first

> A quote holds a picture too, on its own line:
>
> ![the banner, quoted](banner.png)

| protocol | how it is detected | pages |
|:---------|:-------------------|:-----:|
| kitty    | asked, via `probe` |  yes  |
| iTerm2   | environment only   |  no   |

[circle]: circle.png
