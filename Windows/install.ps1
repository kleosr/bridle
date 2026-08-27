#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Pack   = Split-Path -Parent $PSScriptRoot
$HomeC  = Join-Path $env:USERPROFILE '.cursor'
$HooksD = Join-Path $HomeC 'hooks'

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw 'WSL not found. Install first: wsl --install'
}
wsl.exe bash -lc 'command -v jq >/dev/null'
if ($LASTEXITCODE -ne 0) { throw 'jq missing inside WSL. Run: wsl sudo apt-get install jq' }

$src = Join-Path $Pack 'shared\hooks'
New-Item -ItemType Directory -Force "$HooksD\lib", "$HooksD\policy" | Out-Null
foreach ($s in 'session_start.sh', 'before_submit_prompt.sh', 'before_shell.sh', 'before_read_file.sh') {
  Copy-Item (Join-Path $src $s) $HooksD -Force
}
foreach ($s in 'common.sh', 'shell_gate.sh', 'shell_fleet.sh') {
  Copy-Item (Join-Path $src "lib\$s") (Join-Path $HooksD 'lib') -Force
}
Copy-Item "$src\policy\*" "$HooksD\policy" -Force
Copy-Item (Join-Path $PSScriptRoot 'hooks\wsl-shim.ps1') $HooksD -Force

New-Item -ItemType Directory -Force (Join-Path $HomeC 'rules') | Out-Null
foreach ($name in 'ponytail', 'agent', 'vernacular', 'testing', 'mario-engineering-team', 'vibe', 'postgres', 'next', 'vite', 'astro', 'complexity') {
  Copy-Item (Join-Path $Pack "shared\rules\$name.mdc") (Join-Path $HomeC 'rules') -Force
}
Get-Content (Join-Path $Pack 'shared\config\retired.txt') | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  $orphan = Join-Path (Join-Path $HomeC 'rules') $line
  if (Test-Path $orphan) { Remove-Item $orphan -Force }
}

$skillsTxt = Join-Path $Pack 'shared\config\skills.txt'
$skillsSrc = Join-Path $Pack 'shared\skills'
$skillsDst = Join-Path $HomeC 'skills'
New-Item -ItemType Directory -Force $skillsDst | Out-Null
Get-Content $skillsTxt | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  $from = Join-Path $skillsSrc $line
  $to = Join-Path $skillsDst $line
  if (Test-Path $from) {
    if (Test-Path $to) { Remove-Item $to -Recurse -Force }
    Copy-Item $from $to -Recurse -Force
  }
}

# ConvertTo-Json unwraps singleton arrays. Keep [{...}] via jq (WSL).
$srcJson = Join-Path $src 'hooks.json'
$jqFile = Join-Path $src 'lib\windows_hooks_rewrite.jq'
$dstJson = Join-Path $HomeC 'hooks.json'
$srcWsl = (wsl.exe wslpath -a $srcJson).Trim()
$jqWsl = (wsl.exe wslpath -a $jqFile).Trim()
$dstWsl = (wsl.exe wslpath -a $dstJson).Trim()
$shim = Join-Path $HooksD 'wsl-shim.ps1'
$shimQ = $shim.Replace("'", "'\''")
wsl.exe bash -lc "jq --arg shim '$shimQ' -f '$jqWsl' '$srcWsl' > '$dstWsl'"
if ($LASTEXITCODE -ne 0) { throw 'jq rewrite of hooks.json failed (need jq inside WSL)' }

Write-Host '[done] kleosrules installed (Windows via WSL shim — same Cursor hooks as macOS/Linux)'
Write-Host 'Next: paste shared/rules/USER-RULES.paste.txt into Cursor Settings -> User Rules, then start a NEW agent chat.'
