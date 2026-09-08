#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\host.ps1')

$Pack = Split-Path -Parent $PSScriptRoot
$HomeC = Join-Path $env:USERPROFILE '.cursor'
$HooksD = Join-Path $HomeC 'hooks'

if (-not (Get-GitBashPath) -and -not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw 'Install Git for Windows (https://git-scm.com) or WSL. Then: winget install jqlang.jq'
}

$src = Join-Path $Pack 'shared\hooks'
New-Item -ItemType Directory -Force "$HooksD\lib", "$HooksD\policy" | Out-Null
# Must match HOOK_SCRIPTS / RUNTIME_LIBS in shared/hooks/lib/fleet_install.sh
foreach ($s in 'session_start.sh', 'before_submit_prompt.sh', 'before_shell.sh', 'before_read_file.sh', 'stop.sh') {
  Copy-Item (Join-Path $src $s) $HooksD -Force
}
foreach ($s in 'common.sh', 'shell_gate.sh', 'shell_fleet.sh', 'diff_gate.sh') {
  Copy-Item (Join-Path $src "lib\$s") (Join-Path $HooksD 'lib') -Force
}
Copy-Item "$src\policy\*" "$HooksD\policy" -Force
Copy-Item (Join-Path $PSScriptRoot 'hooks\bash-shim.ps1') $HooksD -Force

New-Item -ItemType Directory -Force (Join-Path $HomeC 'rules') | Out-Null
Get-Content (Join-Path $Pack 'shared\config\rules.global.txt') | ForEach-Object {
  $name = $_.Trim()
  if (-not $name -or $name.StartsWith('#')) { return }
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
Get-Content (Join-Path $Pack 'shared\config\retired-skills.txt') | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  $orphan = Join-Path $skillsDst $line
  if (Test-Path $orphan) { Remove-Item $orphan -Recurse -Force }
}

New-Item -ItemType Directory -Force (Join-Path $HomeC 'agents') | Out-Null
foreach ($a in 'hunter', 'cut', 'prove') {
  Copy-Item (Join-Path $Pack "shared\agents\$a.md") (Join-Path $HomeC "agents\$a.md") -Force
}

$srcJson = Join-Path $src 'hooks.json'
$jqFile = Join-Path $src 'lib\windows_hooks_rewrite.jq'
$dstJson = Join-Path $HomeC 'hooks.json'
$shim = Join-Path $HooksD 'bash-shim.ps1'
$rewriteHost = Invoke-HooksJsonRewrite -SrcJson $srcJson -JqFile $jqFile -DstJson $dstJson -Shim $shim

Write-Host "[done] kleosrules installed (Windows via $rewriteHost shim)"
Write-Host 'Next: paste shared/rules/USER-RULES.paste.txt into Cursor Settings -> User Rules, then start a NEW agent chat.'
