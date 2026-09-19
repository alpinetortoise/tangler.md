[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)] [string]$Document,
    [string]$Output = '-',
    [switch]$CodeOnly,
    [switch]$Weave
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Document -PathType Leaf)) { throw "weaver: cannot read document: $Document" }
$lines = [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Document))
$lexicon = @{}; $outputExplicit = $Output -ne '-'; $outputPath = $Output
foreach ($line in $lines) {
    if ($line -match '^\s*::\s*<<([^>]+)>>\s*::\s*$') { $lexicon[$Matches[1]] = $true }
}
$inBlock = $false; $fenceLength = 0; $blockStart = 0; $info = ''; $content = [System.Collections.Generic.List[string]]::new(); $documentationStart = 1
$report = [System.Collections.Generic.List[string]]::new()
function Emit-Documentation([int]$End) {
    if ($documentationStart -gt $End) { return }
    if ($Weave) { for ($i = $documentationStart - 1; $i -lt $End; $i++) { $report.Add($lines[$i]) } }
    elseif (-not $CodeOnly) { $report.Add("documentation lines=$documentationStart-$End") }
}
function Emit-Code([int]$End) {
    $kind = 'anonymous'; $target = '-'; $name = '-'; $retain = $false
    if ($info -match '<<([^>]+)>>') { $name = $Matches[1]; if ($lexicon.ContainsKey($name)) { $retain = $true } }
    if ($info -match 'file\s*=\s*([^\s]+)') { $kind = 'file'; $target = $Matches[1].Trim('"') } elseif ($name -ne '-') { $kind = 'chunk' }
    if ($name -ne '-') { $id = $name } else {
        $bytes = [Text.Encoding]::UTF8.GetBytes(($content -join "`n") + "`n")
        $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        $id = (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    if ($Weave) { if ($retain) { for ($i = $blockStart - 1; $i -lt $End; $i++) { $report.Add($lines[$i]) } } }
    else { $report.Add("code id=$id kind=$kind target=$target name=$name retain=$retain lines=$blockStart-$End") }
}
for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]; $lineNumber = $index + 1
    if (-not $inBlock) {
        if ($line -match '^\s*::\s*weave-file="([^"]+)"\s*::\s*$') {
            if ($Weave -and -not $outputExplicit) { $outputPath = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $Document)) $Matches[1] }
            continue
        }
        if ($line -match '^\s*::\s*<<([^>]+)>>\s*::\s*$') { continue }
        if ($line -match '^\s*(`{3,})(.*)$') { Emit-Documentation ($lineNumber - 1); $inBlock = $true; $fenceLength = $Matches[1].Length; $info = $Matches[2]; $blockStart = $lineNumber; $content = [System.Collections.Generic.List[string]]::new() }
    } elseif ($line -match '^\s*(`{3,})\s*$') {
        if ($Matches[1].Length -eq $fenceLength) { Emit-Code $lineNumber; $inBlock = $false; $documentationStart = $lineNumber + 1 } else { $content.Add($line) }
    } else { $content.Add($line) }
}
if ($inBlock) { throw "weaver: unterminated code fence near line $($lines.Count)" }
Emit-Documentation $lines.Count
if ($outputPath -ne '-') { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputPath) | Out-Null; Set-Content -LiteralPath $outputPath -Value $report -Encoding utf8 } else { $report }
