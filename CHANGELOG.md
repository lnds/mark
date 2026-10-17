## v0.10.2 (2026-10-17)

### Fix

- **inline**: two defects a mutation run found behind green tests
- **tests**: a missing import was hiding half the suite

### Refactor

- **image**: make the two pure parts reachable from a test

## v0.10.1 (2026-09-25)

## v0.10.0 (2026-09-25)

### Feat

- **parser,render**: footnotes, which used to be invented and then lost

## v0.9.0 (2026-09-24)

### Perf

- **image**: name the picture to the terminal instead of spelling it out

## v0.8.1 (2026-09-24)

### Fix

- **image,parser**: three ways a real blog post broke what the examples did not

## v0.8.0 (2026-09-24)

### Feat

- **image**: every format the machine can convert, and kitty told the truth

## v0.7.0 (2026-09-24)

### Feat

- **image**: a paragraph of images draws all of them, side by side

## v0.6.0 (2026-09-24)

### Feat

- **image**: place the picture instead of drawing it, so the pager keeps it

### Fix

- **cli**: -p asked for the pager, so it gets the pager

## v0.5.0 (2026-09-24)

### Feat

- **image**: draw the picture when the terminal says it can

### Fix

- **tty**: a TUI needs both descriptors, not just the one it paints on

## v0.4.0 (2026-09-24)

### Feat

- everything the renderer was quietly dropping, and a file to pick

## v0.3.0 (2026-09-24)

### Feat

- **parser,render**: tables, which used to collapse into a paragraph
- **completion**: add bash and fish alongside zsh
- **completion**: ship a zsh completion that wins the name back from MH

### Fix

- **parser**: setext headings and indented code, both of which mangled text

### Refactor

- **0.121**: drop what the stdlib already provides, and let fmt run
- **pager**: drop the blind counter, whose bug terevaka closed
- **theme**: build ESC with the unicode escape the lexer now has

## v0.2.0 (2026-09-24)

### BREAKING CHANGE

- the build now requires kai 0.112 or later. Earlier
compilers ignore a dependency's [native] table and fail to link, and
the CFLAGS scaffolding that used to compensate is gone.

### Feat

- **pkg**: install straight from the repository, without a Makefile
