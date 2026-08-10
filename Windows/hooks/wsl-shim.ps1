param([Parameter(Mandatory = $true)][string]$HookScript)
$ErrorActionPreference = 'Stop'

$inputJson = [Console]::In.ReadToEnd()
$hookPath  = Join-Path $PSScriptRoot $HookScript
$wslPath   = (wsl.exe wslpath -a $hookPath).Trim()
$output    = $inputJson | wsl.exe bash --noprofile --norc $wslPath
if ($output) { [Console]::Out.Write(($output -join "`n")) }
