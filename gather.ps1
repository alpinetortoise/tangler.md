[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]]$Paths,
    [string]$Output = '-',
    [string]$Root = '.'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "gather: $Message" }
if ($Paths.Count -eq 0) { Fail 'expected at least one input path' }
if (-not (Test-Path -LiteralPath $Root -PathType Container)) { Fail "root is not a directory: $Root" }
$all = [System.Collections.Generic.List[string]]::new(); $seen = @{}
foreach ($inputPath in $Paths) {
    if (Test-Path -LiteralPath $inputPath -PathType Container) {
        Get-ChildItem -LiteralPath $inputPath -File -Recurse | Sort-Object FullName | ForEach-Object {
            if (-not $seen.ContainsKey($_.FullName)) { $seen[$_.FullName] = $true; $all.Add($_.FullName) }
        }
    } elseif (Test-Path -LiteralPath $inputPath -PathType Leaf) {
        $full = (Resolve-Path -LiteralPath $inputPath).Path
        if (-not $seen.ContainsKey($full)) { $seen[$full] = $true; $all.Add($full) }
    } else { Fail "cannot read file: $inputPath" }
}
function Relative-Path([string]$Path) {
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\','/')
    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($full.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar)) { return $full.Substring($rootFull.Length + 1).Replace('\','/') }
    return [IO.Path]::GetRelativePath((Get-Location).Path, $full).Replace('\','/')
}
function Fence-For([string[]]$Lines) {
    $maximum = 0
    foreach ($line in $Lines) { if ($line -match '^(`+)') { $maximum = [Math]::Max($maximum, $Matches[1].Length) } }
    return ('`' * [Math]::Max(3, $maximum + 1))
}
function Write-Block([string]$Relative, [string]$Identity, [string[]]$Lines) {
    $fence = Fence-For $Lines
    if ($Identity.StartsWith('name=')) { $name = $Identity.Substring(5); "$fence <<$name>> file=$Relative" } else { "$fence file=$Relative" }
    "# tangler:block $Identity"
    $Lines
    $fence
    ''
}
function Gather-File([string]$Path) {
    $relative = Relative-Path $Path
    $lines = [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path))
    $current = [System.Collections.Generic.List[string]]::new(); $identity = $null
    $emit = {
        if ($null -eq $identity -and $current.Count -eq 0) { return }
        if ($null -eq $identity) {
            $bytes = [Text.Encoding]::UTF8.GetBytes(($current -join "`n") + "`n")
            $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
            $identity = (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
        }
        Write-Block $relative $identity $current.ToArray()
        $current.Clear(); $identity = $null
    }
    foreach ($line in $lines) {
        if ($line -match '^# tangler:block (.+)$') {
            $candidate = $Matches[1]
            if (($candidate -match '^[0-9a-fA-F]{64}$') -or ($candidate -match '^name=.+$')) {
                & $emit; $identity = $candidate; continue
            }
        }
        $current.Add($line)
    }
    & $emit
}
$outputLines = [System.Collections.Generic.List[string]]::new()
foreach ($path in $all) { foreach ($line in (Gather-File $path)) { $outputLines.Add($line) } }
if ($Output -eq '-') { $outputLines } else { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Output) | Out-Null; Set-Content -LiteralPath $Output -Value $outputLines -Encoding utf8 }
