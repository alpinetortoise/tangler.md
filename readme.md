# Tangler
## A markdown tangling program for Literate CI/CD
## By Joshua Chubb

`tangler` turns Markdown code blocks into source files.

Usage: `./tangler --output-dir build document.md`

Put `file=path/to/file` in a fenced Markdown code block. Blocks targeting the
same path are concatenated in document order. A named block uses `<<name>>` in
the fence info string and can be inserted with `<<name>>` from any file block.

`--list` prints target paths without writing files. Output paths must be
relative and may not escape the selected output directory.

Checks: `bash -n tangler` and `./tangler --help`.

## Gather

`gather` performs the reverse operation. It accepts multiple files or
directories and emits one `file=...` block per file:

`./gather --root src src > gathered.md`

The resulting document can be rebuilt with `./tangler --output-dir rebuilt
gathered.md`. Gatherer lengthens Markdown fences when source content contains
backticks, so gathered blocks remain safe to tangle. Each block carries a
`# tangler:block <sha256>` comment; those markers let a later gather recover
multiple blocks from one tangled output file.

## Weaver

`weaver` inventories a literate Markdown document without tangling it. It
reports prose as `documentation` and fenced blocks as `code`, classifying them
as `file`, `chunk`, or `anonymous`.

Run `./weaver tangle.md`, or add `--code-only` to suppress documentation
ranges. Code records include a stable content ID, target or chunk name, and
source line range; `--output report.txt` writes the inventory to a file.

## Weaver Source

[weaver.md](weaver.md) is the literate source for `weaver`. Put declarations
such as `:: <<example>> ::` near its top. `./weaver --weave weaver.md` keeps
the documentation and declared named blocks while omitting other source
blocks from the weaved document.
Add `:: weave-file="path/file.md" ::` near the top to select the woven output
path relative to the input document. A command-line `--output` overrides it.
Named blocks take precedence over hashes: they use their name as identity and
are not assigned SHA-256 IDs. Unnamed blocks continue to receive hashes.

Run `./tangler --output-dir build weaver.md` to reproduce the executable.
Run `./weaver weaver.md` to inspect every region, or `./weaver --weave
weaver.md` to retain prose and the declared `example` block.
