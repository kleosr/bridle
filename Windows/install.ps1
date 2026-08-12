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
Copy-Item "$src\*.sh" $HooksD -Force
Copy-Item "$src\lib\*.sh" "$HooksD\lib" -Force
Copy-Item "$src\policy\*" "$HooksD\policy" -Force
Copy-Item (Join-Path $PSScriptRoot 'hooks\wsl-shim.ps1') $HooksD -Force

New-Item -ItemType Directory -Force (Join-Path $HomeC 'rules') | Out-Null
foreach ($name in 'native-lean-autoload', 'ponytail', 'agent', 'vernacular', 'testing') {
  Copy-Item (Join-Path $Pack "shared\rules\$name.mdc") (Join-Path $HomeC 'rules') -Force
}

$json = Get-Content (Join-Path $src 'hooks.json') -Raw | ConvertFrom-Json
foreach ($event in $json.hooks.PSObject.Properties) {
  foreach ($entry in @($event.Value)) {
    $script = [IO.Path]::GetFileName($entry.command)
    $entry.command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HooksD\wsl-shim.ps1`" $script"
  }
}
# PS 5.1 Set-Content -Encoding UTF8 writes a BOM, which breaks strict JSON parsers.
[IO.File]::WriteAllText((Join-Path $HomeC 'hooks.json'), ($json | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

Write-Host '[done] kleosrules installed (Windows via WSL shim)'
Write-Host 'Next: paste shared/rules/USER-RULES.paste.txt into Cursor Settings -> User Rules, then start a NEW agent chat.'
