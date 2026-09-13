param([Parameter(Mandatory = $true)][string]$HookScript)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$gitBash = 'C:\Program Files\Git\bin\bash.exe'

function Emit-ShimFailure([string]$detail) {
  $safe = 'kleosrules: git-bash shim failed (' + $detail + ').'
  switch ($HookScript) {
    'before_submit_prompt.sh' {
      [Console]::Out.Write((@{ continue = $false; user_message = $safe } | ConvertTo-Json -Compress))
    }
    'before_read_file.sh' {
      [Console]::Out.Write((@{ permission = 'deny'; user_message = $safe } | ConvertTo-Json -Compress))
    }
    'before_shell.sh' {
      [Console]::Out.Write((@{ permission = 'deny'; user_message = $safe } | ConvertTo-Json -Compress))
    }
    default { [Console]::Out.Write('{}') }
  }
}

function Unix-Path([string]$win) {
  $env:KLEOS_CYG = $win
  $u = & $gitBash --noprofile --norc -c 'cygpath -u "$KLEOS_CYG"'
  if (-not $u) { throw 'cygpath failed' }
  return ([string]$u).Trim()
}

try {
  if (-not (Test-Path -LiteralPath $gitBash)) { throw 'git-bash not found' }
  $hookPath = Join-Path $PSScriptRoot $HookScript
  if (-not (Test-Path -LiteralPath $hookPath)) { throw 'hook script missing: ' + $hookPath }
  $raw = [Console]::In.ReadToEnd()
  if ($null -eq $raw) { $raw = '' }
  if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
  $inFile = Join-Path ([System.IO.Path]::GetTempPath()) ('kleos-hook-in-' + [guid]::NewGuid().ToString('n') + '.json')
  [System.IO.File]::WriteAllText($inFile, $raw, $utf8)
  try {
    $env:KLEOS_HOOK = Unix-Path $hookPath
    $env:KLEOS_IN = Unix-Path $inFile
    $out = & $gitBash --noprofile --norc -c 'exec "$KLEOS_HOOK" < "$KLEOS_IN"'
    $json = if ($null -eq $out) { '' } elseif ($out -is [array]) { $out -join "`n" } else { [string]$out }
    [Console]::Out.Write($json)
  } finally {
    Remove-Item -LiteralPath $inFile -Force -ErrorAction SilentlyContinue
  }
} catch {
  Emit-ShimFailure $_.Exception.Message
}
