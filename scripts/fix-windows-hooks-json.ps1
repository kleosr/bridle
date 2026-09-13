# Restore Windows hooks.json to shim-only (removes duplicate ./hooks/ entries
# that fleet_sync merge used to add). Prefers git-bash-shim.ps1, then bash-shim.ps1.
$ErrorActionPreference = 'Stop'
$hooksDir = Join-Path $env:USERPROFILE '.cursor\hooks'
$hooksJson = Join-Path $env:USERPROFILE '.cursor\hooks.json'
$backup = "$hooksJson.pre-sync-bak"
$shim = $null
foreach ($name in @('git-bash-shim.ps1', 'bash-shim.ps1')) {
  $candidate = Join-Path $hooksDir $name
  if (Test-Path -LiteralPath $candidate) {
    $shim = $candidate
    break
  }
}
if (-not $shim) {
  Write-Error "Missing git-bash-shim.ps1 or bash-shim.ps1 under $hooksDir - install hooks scripts first."
}
$cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$shim`""
if (Test-Path -LiteralPath $backup) {
  Copy-Item -LiteralPath $backup -Destination $hooksJson -Force
  Write-Host "[ok] restored from $backup"
} else {
  $doc = [ordered]@{
    version = 1
    hooks = [ordered]@{
      beforeReadFile = @(@{ command = "$cmd before_read_file.sh"; timeout = 10; failClosed = $true })
      beforeShellExecution = @(@{ command = "$cmd before_shell.sh"; timeout = 30; failClosed = $true })
      beforeSubmitPrompt = @(@{ command = "$cmd before_submit_prompt.sh"; timeout = 10; failClosed = $true })
      stop = @(@{ command = "$cmd stop.sh"; timeout = 30; failClosed = $false; loop_limit = 1 })
    }
  }
  ($doc | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $hooksJson -Encoding utf8
  Write-Host "[ok] wrote shim-only hooks.json"
}
$doc = Get-Content -LiteralPath $hooksJson -Raw | ConvertFrom-Json
Write-Host ("[info] events registered: " + (($doc.hooks | Get-Member -MemberType NoteProperty).Name -join ", "))
Get-Content -LiteralPath $hooksJson
