## Tangler
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
