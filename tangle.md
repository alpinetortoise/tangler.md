# Tangler

This file contains the literate program source.

## Purpose

Tangler treats Markdown as the human-readable source of a small software
project. Prose explains the intent and fenced code blocks contain the files
that should be produced. The Bash program below is therefore both an example
of the format and the implementation of the tool that reads the format.

The executable is deliberately dependency-free. It needs Bash with associative
arrays, and it writes only the files explicitly named by `file=...` in the
document.

## Document model

A file block starts with a fenced Markdown line containing a target, such as
the inline form ` ```bash file=path/to/file `, and ends at the next closing
fence. The source text between those lines becomes the file content.

Several blocks may name the same target. Tangler appends them in document
order, which makes it possible to introduce a generated file in small,
explained sections.

Named chunks are reusable pieces that do not write a file by themselves. A
chunk opening line can be written as ` ```bash <<common-options>> ` and its
body can contain `set -euo pipefail`. The reference `<<common-options>>` can
occur inside any file block. Chunk
definitions may appear before or after the blocks that use them.

## Command-line interface

The first part of the program handles the small command-line interface. The
default output directory is the current directory; `-o` and
`--output-dir` select another one. `--list` performs parsing but stops after
printing the target paths, which is useful for CI checks and previews.

The `--` form is accepted when the document name begins with a dash. Missing
documents, unreadable input, and extra arguments are reported through one
error function so every failure has a consistent command name.

```file=tangler
#!/usr/bin/env bash
set -euo pipefail

usage() {
        printf '%s\n' \
                'Usage: tangler [--output-dir DIR] [--list] DOCUMENT' \
                '' \
                'Tangle fenced Markdown code blocks into files.' \
                '' \
                '  ```bash file=path/to/file' \
                '  contents' \
                '  ```' \
                '' \
                'Named blocks use `<' '<name>>` in the fence info string and can be included' \
                'with `<' '<name>>` from any file block.'
}

die() {
    printf 'tangler: %s\n' "$1" >&2
    exit 1
}

output_dir=.
list_only=false
document=

while (($#)); do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -o|--output-dir)
            (($# >= 2)) || die "missing argument for $1"
            output_dir=$2
            shift 2
            ;;
        --list)
            list_only=true
            shift
            ;;
        --)
            shift
            (($# == 1)) || die "expected one Markdown document"
            document=$1
            shift
            ;;
        -*|*)
            [[ -z $document ]] || die "unexpected argument: $1"
            document=$1
            shift
            ;;
    esac
done

[[ -n $document ]] || { usage >&2; exit 2; }
[[ -r $document ]] || die "cannot read document: $document"

declare -A chunks=()
declare -A files=()
declare -a file_order=()
in_block=false
block_name=
block_file=
block_content=
fence_length=0
line_number=0

add_file() {
    local path=$1
    if [[ -z ${files[$path]+set} ]]; then
        file_order+=("$path")
        files[$path]=
    fi
    files[$path]+=$block_content
}

while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    if ! $in_block; then
        if [[ $line =~ ^[[:space:]]*(\`\`\`+)[[:space:]]*(.*)$ ]]; then
            in_block=true
            info=${BASH_REMATCH[2]}
            fence_length=${#BASH_REMATCH[1]}
            block_name=
            block_file=
            block_content=
            if [[ $info =~ \<\<([^\>]+)\>\> ]]; then
                block_name=${BASH_REMATCH[1]}
            fi
            if [[ $info =~ file[[:space:]]*=[[:space:]]*([^[:space:]]+) ]]; then
                block_file=${BASH_REMATCH[1]}
                block_file=${block_file#\"}
                block_file=${block_file%\"}
            fi
        fi
    elif [[ $line =~ ^[[:space:]]*(\`\`\`+)[[:space:]]*$ ]]; then
        if ((${#BASH_REMATCH[1]} == fence_length)); then
            in_block=false
            if [[ -n $block_name ]]; then
                [[ -z ${chunks[$block_name]+set} ]] || die "duplicate chunk '$block_name'"
                chunks[$block_name]=$block_content
            fi
            if [[ -n $block_file ]]; then
                add_file "$block_file"
            fi
        else
            block_content+="$line"$'\n'
        fi
    else
        block_content+="$line"$'\n'
    fi
done < "$document"

$in_block && die "unterminated code fence near line $line_number"
((${#file_order[@]} > 0)) || die "document contains no fenced blocks with file=..."

declare -A expanding=()

expand() {
    local text=$1
    local name before after replacement
    while [[ $text =~ (.*)\<\<([^\>]+)\>\>(.*) ]]; do
        before=${BASH_REMATCH[1]}
        name=${BASH_REMATCH[2]}
        after=${BASH_REMATCH[3]}
        [[ -n ${chunks[$name]+set} ]] || die "unknown chunk '$name'"
        [[ -z ${expanding[$name]+set} ]] || die "cyclic chunk reference involving '$name'"
        expanding[$name]=1
        replacement=$(expand "${chunks[$name]}")
        unset 'expanding[$name]'
        text=$before$replacement$after
    done
    printf '%s' "$text"
}

$list_only && printf '%s\n' "${file_order[@]}" && exit 0

mkdir -p "$output_dir"
for relative_path in "${file_order[@]}"; do
    [[ $relative_path != /* && $relative_path != .. && $relative_path != ../* && $relative_path != */../* && $relative_path != */.. ]] || die "unsafe output path: $relative_path"
    destination=$output_dir/$relative_path
    mkdir -p "$(dirname "$destination")"
    expand "${files[$relative_path]}" > "$destination"
    printf 'tangled %s\n' "$destination"
done
```

## Collecting blocks

The parser reads the document one line at a time. Outside a fence it looks for
an opening triple-backtick line. Inside a fence it records the raw line and
closes only on a fence with no additional text. This keeps the code contents
unchanged, including indentation and shell syntax.

When a block closes, its optional chunk name is stored in `chunks`, while its
optional file target is appended to `files`. `file_order` is kept separately
because associative-array iteration is intentionally unordered; output should
always follow the order in which targets first appeared.

An unfinished fence is an input error. A document with no file blocks is also
rejected, since there would be nothing to tangle.

## Expanding chunks

Expansion happens after collection, so forward references work. `expand`
searches for the next `<<name>>` reference, recursively expands the named
chunk, and replaces the reference in the surrounding text. A missing name is
an error rather than silently becoming incomplete source.

The `expanding` associative array is a recursion stack. A name is marked
before its body is expanded and removed afterward. If expansion encounters a
name already on that stack, the document contains a cycle and tangling stops
with a useful diagnostic.

## Writing safely

Only after parsing and expansion setup succeeds does the program create the
output directory and files. Every target must be relative and must not contain
a `..` path component that could escape the output directory. Parent
directories are created as needed, and each completed file is announced on
standard output.

The result is intentionally ordinary source files. They can be checked with
the language's normal tools, committed as build artifacts, or consumed by a
CI/CD pipeline.

Gathered blocks carry a `# tangler:block <sha256>` comment in their source
text. Tangling preserves that comment in the output file. When the file is
gathered later, the comment is used as a boundary and identity marker, so
several blocks targeting the same output file do not collapse into one block.

## Reproducing the executable

From this directory, the document can reproduce the executable itself:

    ./tangler --output-dir build tangle.md

That command writes `build/tangler`. The source block above is the complete
file, while the surrounding prose remains documentation only. A basic check
of the generated program is:

    bash -n build/tangler

This separation is the central promise of literate programming here: the
document is optimized for reading, and the tangled file is optimized for
execution.

## Multi-block and reverse workflows

Repeated `file=...` blocks are accumulated in source order. This is the
multi-block form used when a generated file is explained in separate sections.
The parser keeps target order separately from its associative arrays so output
ordering remains deterministic.

The companion `gather` command reverses the file-to-document direction. Given
several paths or a directory, it emits one block per file, using paths relative
to `--root`. Its output can be passed directly back to `tangler`. It also uses
longer Markdown fences when needed and the tangler closes only a matching
length, allowing source files to contain ordinary triple-backtick lines.

The `weaver` command provides the document inventory view. It reports prose
ranges as `documentation` and fenced regions as `code`, identifying file
blocks, named chunks, and anonymous code. Each code record carries a SHA-256
content ID, so executable material can be located without confusing it with
explanatory prose. Existing `# tangler:block` markers retain their IDs in the
report.

Named blocks use their names as identity instead of SHA-256. Gather writes
named markers as `# tangler:block name=NAME`, avoiding a collision with noweb
references while preserving the name through tangling.

The weaver itself is documented in [weaver.md](weaver.md). Its retention
lexicon uses declarations such as `:: <<named-block>> ::` near the top of the
document. `./weaver --weave weaver.md` retains prose and only the named blocks
declared by that lexicon.
