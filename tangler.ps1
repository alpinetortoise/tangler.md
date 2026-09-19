[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)] [string]$Document,
    [string]$OutputDir = '.',
    [switch]$List
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw "tangler: $Message" }
if (-not (Test-Path -LiteralPath $Document -PathType Leaf)) { Fail "cannot read document: $Document" }
$chunks = @{}
$files = @{}
$fileOrder = [System.Collections.Generic.List[string]]::new()
$inBlock = $false; $fenceLength = 0; $blockName = $null; $blockFile = $null
$blockContent = [System.Collections.Generic.List[string]]::new(); $lineNumber = 0
function Add-FileBlock([string]$Path, [string]$Content) {
    if (-not $files.ContainsKey($Path)) { $files[$Path] = ''; $fileOrder.Add($Path) }
    $files[$Path] += $Content
}
foreach ($line in [System.IO.File]::ReadLines((Resolve-Path -LiteralPath $Document))) {
    $lineNumber++
    if (-not $inBlock) {
        if ($line -match '^\s*(`{3,})(.*)$') {
            $inBlock = $true; $fenceLength = $Matches[1].Length; $info = $Matches[2]
            $blockName = $null; $blockFile = $null; $blockContent = [System.Collections.Generic.List[string]]::new()
            if ($info -match '<<([^>]+)>>') { $blockName = $Matches[1] }
            if ($info -match 'file\s*=\s*([^\s]+)') { $blockFile = $Matches[1].Trim('"') }
        }
    } elseif ($line -match '^\s*(`{3,})\s*$') {
        if ($Matches[1].Length -eq $fenceLength) {
            $inBlock = $false; $content = ($blockContent -join "`n") + "`n"
            if ($null -ne $blockName) {
                if ($chunks.ContainsKey($blockName)) { Fail "duplicate chunk '$blockName'" }
                $chunks[$blockName] = $content
            }
            if ($null -ne $blockFile) { Add-FileBlock $blockFile $content }
        } else { $blockContent.Add($line) }
    } else { $blockContent.Add($line) }
}
if ($inBlock) { Fail "unterminated code fence near line $lineNumber" }
if ($fileOrder.Count -eq 0) { Fail 'document contains no fenced blocks with file=...' }
function Expand-Text([string]$Text) {
    while ($Text -match '<<([^>]+)>>') {
        $name = $Matches[1]
        if (-not $chunks.ContainsKey($name)) { Fail "unknown chunk '$name'" }
        $replacement = Expand-Text $chunks[$name]
        $Text = $Text.Replace("<<$name>>", $replacement)
    }
    return $Text
}
if ($List) { $fileOrder; exit 0 }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
foreach ($relativePath in $fileOrder) {
    if ([System.IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|[\\/])\.\.?([\\/]|$)') { Fail "unsafe output path: $relativePath" }
    $destination = Join-Path $OutputDir $relativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path -Parent $destination)).Path + [IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $destination), (Expand-Text $files[$relativePath]))
    "tangled $destination"
}
