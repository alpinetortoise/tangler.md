# Tangler Stress Document

This document is a deliberately repetitive integration fixture. It contains
multiple output files, repeated blocks, named identities, unnamed blocks,
lexicon-controlled weaving, and a source block containing a Markdown fence.

:: weave-file="build/stress-weaved.md" ::
:: <<shared-header>> ::
:: <<retained-part>> ::
:: <<retained-part-2>> ::
:: <<retained-part-3>> ::
:: <<report-retained>> ::
:: <<worker-header>> ::
:: <<worker-retained>> ::
:: <<fenced-part>> ::
:: <<anonymous-named>> ::

The declarations above are the retention lexicon. The weaved document should
keep this prose and the three named blocks, while anonymous and undeclared
blocks remain absent.

```bash <<shared-header>> file=app.sh
# tangler:block name=shared-header
#!/usr/bin/env bash
set -euo pipefail
printf 'header\n'
```

```bash <<retained-part-2>> file=app.sh
# tangler:block name=retained-part-2
printf 'retained-1\n'
```

```bash file=app.sh
# tangler:block 1111111111111111111111111111111111111111111111111111111111111111
printf 'anonymous-1\n'
```

````bash <<fenced-part>> file=app.sh
# tangler:block name=fenced-part
printf '%s\n' 'fenced block follows'
```text
literal triple fence: ```
````

```bash file=app.sh
# tangler:block 2222222222222222222222222222222222222222222222222222222222222222
printf 'anonymous-2\n'
```

```bash <<retained-part-3>> file=app.sh
# tangler:block name=retained-part-3
printf 'retained-2\n'
```

```bash file=app.sh
# tangler:block 3333333333333333333333333333333333333333333333333333333333333333
printf 'anonymous-3\n'
```

## A second target

```bash <<worker-header>> file=worker.sh
# tangler:block name=worker-header
printf 'worker-header\n'
```

```bash file=worker.sh
# tangler:block 4444444444444444444444444444444444444444444444444444444444444444
printf 'worker-1\n'
```

```bash file=worker.sh
# tangler:block 5555555555555555555555555555555555555555555555555555555555555555
printf 'worker-2\n'
```

```bash <<worker-retained>> file=worker.sh
# tangler:block name=worker-retained
printf 'worker-retained\n'
```

## More repeated blocks

```bash file=report.txt
# tangler:block 6666666666666666666666666666666666666666666666666666666666666666
report-line-1
```

```bash file=report.txt
# tangler:block 7777777777777777777777777777777777777777777777777777777777777777
report-line-2
```

```bash <<report-retained>> file=report.txt
# tangler:block name=report-retained
report-retained
```

```bash file=report.txt
# tangler:block 8888888888888888888888888888888888888888888888888888888888888888
report-line-3
```

```bash file=anonymous.sh
# tangler:block 9999999999999999999999999999999999999999999999999999999999999999
printf 'anonymous output\n'
```

```bash <<anonymous-named>> file=anonymous.sh
# tangler:block name=anonymous-named
printf 'named output\n'
```

## Suggested checks

```text
./tangler --output-dir build stress.md
./weaver stress.md
./weaver --code-only stress.md
./weaver --weave stress.md
./gather --root build build/app.sh build/worker.sh build/report.txt > build/regathered.md
./tangler --output-dir build/rebuilt build/regathered.md
```

The final command should reproduce the gathered files. Running gather again on
`build/rebuilt` should preserve all named and unnamed block boundaries.
