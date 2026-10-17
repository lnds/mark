---
paths:
  - "**/*.kai"
---

# Writing kaikai here

kaikai has little presence in training corpora; **do not extrapolate from Rust, Go,
Python or Haskell**. The tooling answers faster than reading sources.

1. `kai doc <module>.<symbol>` — one signature and its doc. The default move. Note it
   spells paths with a slash (`kai doc core/list.foldl`), not the dot `import` uses.
2. `kai info deltas` — once per session: the collisions with other languages (`#` for
   comments, `:=` to assign, `++` concatenates, no `return`, no `for x in xs`).
3. `kai info idiomatic` — **before writing much code.** It pairs each idiom with the
   wrong reach from another language; skipping it is what produced nested `else { if }`
   ladders and sentinel return values here, both since fixed.
4. `kai info syntax` — every form that exists. If a form is not there it does not exist:
   its *NOT IN KAIKAI* section is the truth.
5. `kai info <topic>` in full only when stuck on that thing.

For the unknown, write a typed hole `?` and let the compiler name the expected type and
what is in scope: `kai build --holes <file>`.

**This file ages faster than the language.** Before working around something it calls
missing, spend the thirty seconds to check.

## Imports are per-file

An import is visible **only in the file that writes it**. A name another file imports, or
one a module you import imports in turn, is not in scope here — a bare use is `` `add` is
not imported in this file ``, and the help names the import to add.

```
import pkg              # its pub names, bare
import pkg.mod
import pkg as m         # m.add only, nothing bare
import pkg.{add, mul}   # selective
```

Constructors obey this too: a file matching on `terevaka.term`'s `Key` must import them,
which is why `tests/pager_test.kai` says `import terevaka.term.{Down, Esc, Printable,
Tick}`.

**The `core/*` modules are auto-loaded** — `core/list`, `core/string`, `core/char`,
`core/option`, `core/result`, `core/tuple`, plus `protocols`, `effects` and `array` (the
full set is in `kai info builtins`). Importing them is noise: write `reverse(xs)`,
`trim(s)`, `xs.length()`. Their module names stay in scope too, so `list.repeat("", n)`
disambiguates a name both modules own. Only what is outside that set is imported: here
`text`, `math/int`, `path`, `encoding/*`, `fs/*`, `os/*` and `terevaka.*`.

## Iterate for effect with `|!`

`xs |! f` is the each-pipe: it returns `Unit`, closes a `Unit` body and calls the head
type's own `each`. It is what `main` writes to print the rendered lines and what
`image.install` writes to send the chunks. `foreach(xs, f)` is the older spelling.

## Which lines a test runs

`kai test --json --coverage <file>` follows each test's record with the package source
lines that block ran, by file. **The flags go before the spec** — after it they are taken
and silently do nothing. Union those records over `tests/*.kai` and the complement names
every line no test reaches, which turns closing a coverage hole into reading instead of
guessing: kalku counts its `no_coverage` wekufe and never names them.

Read the complement knowing what is not instrumented: an `fn` signature, a record field, a
`match` arm whose body is on the next line and a closing delimiter never show as run. A
gap is real only where an expression sits on the line.

Five arms are unreachable by construction and stay uncovered for good: `fits_in`'s `[]`
and `ceiling`'s first branch in `render.kai`, `is_rule`'s and `weave`'s `[]` in
`parser.kai`, `trailing_noise`'s in `inline.kai`. Exhaustiveness asks for them; no input
reaches them.

## Traps verified here

Every one cost a compile cycle; do not repeat them.

- **Match arms on one line are separated by `;`, not `,`.** A comma gives `expected
  pattern`.
- **`text.char_width` takes an `Int`, not a `Char`** — `char_to_int(c)` first. The error
  shows at link time, not in `kai typecheck`: it is a *deferred field access*, so a clean
  `typecheck` does not guarantee the char arithmetic type-checks.
- **A `#` comment between `#[doc("...")]` and its declaration disconnects them**, and the
  doc is read as the module doc. The comment goes **before** the `#[doc]`, never between.
- **The multi-line form is `"""`, not `"`.** A newline inside single quotes is
  `unterminated string`. The triple quote interpolates `#{...}` like the single one and
  **keeps the content byte for byte** — it trims neither the newline after `"""` nor the
  indentation, hence text starting glued to the opening quotes.
- **The stderr op is `Stderr.eprint`, not `print`.**
- **`fs.file.read` panics on any I/O failure.** That is its design; `File.read_file(path)`
  returns `Result[String, String]`.
- **Unqualified, `string` wins over `list`.** `repeat("", n)` resolves to `string.repeat`
  and yields `""`, never `[String]`; a `let` annotation does not steer it back. Qualify:
  `list.repeat("", n)`. A module you import shadows a core name the same way, but only in
  the file that writes the import — `main.kai` imports `path` and so spells out
  `string.join`, while the other files need not.
- **A continuation line may not begin with `.`.** Binary operators continue an expression
  across lines; a UFCS chain does not. Break it inside its parentheses.
- **`_` is not a lambda parameter.** `(i, _) => ...` is `expected `,` or `)` in call
  arguments`; name the one you ignore.
- **`list.map_indexed` is not tail-recursive.** It overflows the fiber stack on a few
  million elements — which a 3.5 MB image is, one `Int` per byte. `enumerate(xs) | f`
  walks the same ground and survives it.
- **`base64.encode` is quadratic in the length of its list.** 3.5 M bytes take 72 seconds
  in one call and under a second in chunks of 3072. Measured, both ways.
- **A package importing `terevaka.ui` runs terevaka's tests too.** A red line there is not
  necessarily this project's — check whose file it is before chasing it.
