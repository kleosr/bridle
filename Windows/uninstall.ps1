#Requires -Version 5.1
# Mirror of shared/hooks/lib/fleet_install.sh uninstall_home. Untested in CI (no Windows runner).
$ErrorActionPreference = 'Stop'

$Pack   = Split-Path -Parent $PSScriptRoot
$HomeC  = Join-Path $env:USERPROFILE '.cursor'
$HooksD = Join-Path $HomeC 'hooks'

$hooksJson = Join-Path $HomeC 'hooks.json'
if ((Test-Path $hooksJson) -and (Select-String -Path $hooksJson -Pattern 'before_submit_prompt.sh' -Quiet)) {
  Remove-Item $hooksJson -Force
}
foreach ($s in 'session_start.sh', 'before_submit_prompt.sh', 'before_shell.sh', 'before_read_file.sh', 'wsl-shim.ps1') {
  Remove-Item (Join-Path $HooksD $s) -Force -ErrorAction SilentlyContinue
}
foreach ($s in 'common.sh', 'shell_gate.sh') {
  Remove-Item (Join-Path $HooksD "lib\$s") -Force -ErrorAction SilentlyContinue
}
Get-ChildItem (Join-Path $Pack 'shared\hooks\policy') -File | ForEach-Object {
  Remove-Item (Join-Path $HooksD "policy\$($_.Name)") -Force -ErrorAction SilentlyContinue
}
foreach ($d in 'policy', 'lib', '') {
  $dir = if ($d) { Join-Path $HooksD $d } else { $HooksD }
  if ((Test-Path $dir) -and -not (Get-ChildItem $dir -Force)) { Remove-Item $dir -Force }
}

foreach ($name in 'ponytail', 'agent', 'testing', 'vibe', 'postgres', 'next', 'vite', 'astro', 'complexity', 'pnpm') {
  Remove-Item (Join-Path $HomeC "rules\$name.mdc") -Force -ErrorAction SilentlyContinue
}
Get-Content (Join-Path $Pack 'shared\config\skills.txt') | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  Remove-Item (Join-Path $HomeC "skills\$line") -Recurse -Force -ErrorAction SilentlyContinue
}
foreach ($a in 'hunter', 'cut', 'prove') {
  Remove-Item (Join-Path $HomeC "agents\$a.md") -Force -ErrorAction SilentlyContinue
}

Write-Host '[done] kleosrules uninstalled from ~/.cursor (foreign rules/skills/agents untouched)'
