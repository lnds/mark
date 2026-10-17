# Commits, version, changelog

## Conventional Commits

`<type>(<scope>)?: <subject>`, in English. The scope is the area — `feat(parser):`,
`fix(image,parser):`, `perf(image):`.

- `feat` → MINOR (pre-1.0). `fix` / `perf` / `refactor` → PATCH.
- `docs`, `chore`, `ci`, `test`, `build` → no bump, no changelog entry.
- Breaking: `!` plus a `BREAKING CHANGE:` footer. `major_version_zero` keeps it at a minor
  bump while the project is 0.x.

The subject says what changed and, where it fits, what was wrong before. The body is where
a ticket or a measurement belongs — never inside a code comment.

## Bumps

`cz bump` (or `make bump`), configured in `.cz.toml`. It reads the current version from the
git tags, decides the increment from the commits since the last one, rewrites both places
the version lives, writes `CHANGELOG.md`, commits and tags — annotated, like the ones
already here. `cz bump --dry-run` says what it would do without doing it.

A commit type that bumps nothing stops with `NO_COMMITS_TO_BUMP`, leaving no tag and no
edit, even though the line above it proposes the current version. Running it is always
safe.

Do not edit `CHANGELOG.md` by hand.

## The version lives twice

`kai.toml` for the package manager, `cli.VERSION` for `mark -v` and the help — which is
why `version_files` names both. Nothing in the build, the lint or the formatter notices
when one is forgotten, so `tests/version_test.kai` reads the manifest and asserts they
agree; it is the guard for a hand-edit that skips `cz`.

Asking the toolchain to hand the manifest to the compiler, as Cargo does with
`CARGO_PKG_VERSION`, was declined as speculative
([kaikai#2121](https://github.com/lnds/kaikai/issues/2121)) — rightly, since it was filed
from the analogy rather than from a program that needed it. The reply names what would
reopen it, and its first line is a program that prints its own version from its own code,
which is this one. So the guard is the answer here, not a stopgap.

## Hygiene

- Commits are the user's and only the user's: no `Co-Authored-By`, no tool footer.
- A bug found outside the change's scope becomes its own commit, not an inline fix.
