param([Parameter(Mandatory = $true)][string]$HookScript)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$gitBash = 'C:\Program Files\Git\bin\bash.exe'
# Stay under hooks.json timeouts (read/submit=30s, shell=60s): first-byte wait + idle drain + bash.
$stdinFirstByteMs = 3000
$stdinIdleMs = 400
$stdinMaxMs = 8000
$havePipePeek = $false
# The P/Invoke helper is compiled once to a DLL beside this script and loaded
# from there afterwards. Compiling C# in-process (csc.exe) on every hook cost
# 1-3 s per invocation and, under load, exceeded the hook timeout.
$pipeUtilSrc = @'
using System;
using System.Runtime.InteropServices;
public static class KleosPipeUtil {
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern IntPtr GetStdHandle(int hStdHandle);
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern bool PeekNamedPipe(IntPtr hPipe, byte[] lpBuffer, uint nBufferSize, out uint lpBytesRead, out uint lpTotalBytesAvail, out uint lpBytesLeftThisMessage);
}
'@
$pipeUtilDll = Join-Path $PSScriptRoot 'KleosPipeUtil.dll'
try {
  if (-not (Test-Path -LiteralPath $pipeUtilDll)) {
    $tmpDll = Join-Path ([System.IO.Path]::GetTempPath()) ('KleosPipeUtil-' + [guid]::NewGuid().ToString('n') + '.dll')
    Add-Type -TypeDefinition $pipeUtilSrc -OutputAssembly $tmpDll
    try { Move-Item -LiteralPath $tmpDll -Destination $pipeUtilDll -ErrorAction Stop }
    catch { Remove-Item -LiteralPath $tmpDll -Force -ErrorAction SilentlyContinue }  # another shim won the race
  }
  Add-Type -Path $pipeUtilDll
  $havePipePeek = $true
} catch {
  try { Add-Type -TypeDefinition $pipeUtilSrc; $havePipePeek = $true } catch {}
}

function Get-VerdictTag([string]$json) {
  # Class and reason only. user_message and followup text stay out of the log.
  if ([string]::IsNullOrWhiteSpace($json)) { return 'verdict=empty' }
  try { $o = $json | ConvertFrom-Json } catch { return 'verdict=unparsed' }
  $names = @($o.PSObject.Properties.Name)
  $tag = 'verdict=quiet'
  if ($names -contains 'permission') {
    $tag = 'verdict=' + [string]$o.permission
  } elseif ($names -contains 'continue') {
    $bit = 'false'
    if ($o.continue) { $bit = 'true' }
    $tag = 'verdict=continue:' + $bit
  } elseif ($names -contains 'followup_message') {
    $tag = 'verdict=followup'
  }
  if ($names -contains 'reason' -and $o.reason) {
    $safe = ([string]$o.reason) -replace '[^A-Za-z0-9_-]', ''
    if ($safe.Length -gt 40) { $safe = $safe.Substring(0, 40) }
    if ($safe.Length -gt 0) { $tag += ' reason=' + $safe }
  }
  return $tag
}

function Write-HookLog([string]$msg) {
  try {
    $log = $env:KLEOS_HOOK_LOG
    if (-not $log) { $log = Join-Path ([System.IO.Path]::GetTempPath()) 'kleos-hooks.log' }
    $old = Get-Item -LiteralPath $log -ErrorAction SilentlyContinue
    # Default log only. An explicit KLEOS_HOOK_LOG is the caller's capture.
    if (-not $env:KLEOS_HOOK_LOG -and $old -and $old.Length -gt 1048576) {
      Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    }
    Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' [' + $HookScript + '] ' + $msg) -Encoding UTF8 -ErrorAction SilentlyContinue
  } catch {}
}

function Emit-Verdict([string]$json) {
  # Cursor failClosed treats a non-zero process exit as a hook crash, even when
  # stdout is a valid verdict. powershell.exe -File otherwise inherits bash's
  # LASTEXITCODE. Always exit 0 after writing JSON.
  [Console]::Out.Write($json)
  exit 0
}

function Emit-ShimFailure([string]$detail) {
  $safe = 'kleosrules: git-bash shim failed (' + $detail + ').'
  switch ($HookScript) {
    'before_submit_prompt.sh' {
      Emit-Verdict ((@{ continue = $false; user_message = $safe } | ConvertTo-Json -Compress))
    }
    'before_read_file.sh' {
      Emit-Verdict ((@{ permission = 'deny'; user_message = $safe } | ConvertTo-Json -Compress))
    }
    'before_shell.sh' {
      Emit-Verdict ((@{ permission = 'deny'; user_message = $safe } | ConvertTo-Json -Compress))
    }
    default { Emit-Verdict '{}' }
  }
}

function Unix-Path([string]$win) {
  # Drive-letter paths convert in-process (C:\a\b -> /c/a/b); spawning bash for
  # cygpath cost ~0.5-2 s each under load. Anything else falls back to cygpath.
  if ($win -match '^([A-Za-z]):[\\/](.*)$') {
    return '/' + $matches[1].ToLower() + '/' + ($matches[2] -replace '\\', '/')
  }
  $env:KLEOS_CYG = $win
  $u = & $gitBash --noprofile --norc -c 'cygpath -u "$KLEOS_CYG"'
  if (-not $u) { throw 'cygpath failed' }
  return ([string]$u).Trim()
}

function Get-PipeAvail([IntPtr]$h) {
  try {
    [uint32]$br = 0; [uint32]$av = 0; [uint32]$lm = 0
    if ([KleosPipeUtil]::PeekNamedPipe($h, $null, 0, [ref]$br, [ref]$av, [ref]$lm)) { return [int64]$av }
  } catch {}
  return -1
}

function Read-HookStdin {
  # Never block on stdin: some launchers keep the stdin pipe open without EOF,
  # which used to hang ReadToEnd() until the hook timeout killed us (Cursor:
  # "returned no output", failClosed block). We therefore NEVER issue a
  # blocking read: seekable input (file redirect) is read to EOF (always safe),
  # pipes are polled with PeekNamedPipe and only already-buffered bytes are
  # read. (BeginRead+WaitOne was tried: abandoning the timed-out async read
  # wedged later child-process calls, so it is deliberately not used.)
  try {
    if (-not [Console]::IsInputRedirected) { return '' }
    $stream = [Console]::OpenStandardInput()
    try {
      if ($stream.CanSeek) {
        $sr = New-Object System.IO.StreamReader($stream, $utf8)
        $all = $sr.ReadToEnd()
        if ($null -eq $all) { return '' }
        return $all
      }
      if (-not $havePipePeek) { return '' }
      # ConsolePal+WindowsConsoleStream.SafeFileHandle is null on PowerShell 7,
      # so PeekNamedPipe cannot use the console stream and the old code read 0
      # bytes (every prompt came out reason=malformed). Take the real handle
      # from GetStdHandle and wrap it in a FileStream, which does expose a usable
      # handle, for both the peek and the read. ownsHandle=$false so closing the
      # stream never closes the process stdin handle.
      $h = [KleosPipeUtil]::GetStdHandle(-10)
      if ($h -eq [IntPtr]::Zero) { return '' }
      $fs = $null
      try {
        $fs = New-Object System.IO.FileStream($h, [System.IO.FileAccess]::Read, $false)
      } catch { return '' }
      $ms = New-Object System.IO.MemoryStream
      $buf = New-Object byte[] 65536
      $started = [DateTime]::UtcNow
      $firstDeadline = $started.AddMilliseconds($stdinFirstByteMs)
      $hardStop = $started.AddMilliseconds($stdinMaxMs)
      $idleDeadline = [DateTime]::MinValue
      while ($true) {
        $now = [DateTime]::UtcNow
        if ($now -ge $hardStop) {
          if ($ms.Length -gt 0) { Write-HookLog 'stdin max window elapsed; using partial input' }
          break
        }
        if ($ms.Length -eq 0 -and $now -ge $firstDeadline) { break }
        if ($ms.Length -gt 0 -and $now -ge $idleDeadline) { break }
        $avail = Get-PipeAvail $h
        if ($avail -lt 0) { break }
        if ($avail -gt 0) {
          $n = $fs.Read($buf, 0, [int][Math]::Min($buf.Length, $avail))
          if ($n -le 0) { break }  # EOF
          $ms.Write($buf, 0, $n)
          $idleDeadline = [DateTime]::UtcNow.AddMilliseconds($stdinIdleMs)
          continue
        }
        Start-Sleep -Milliseconds 25
      }
      if ($ms.Length -eq 0) { return '' }
      return $utf8.GetString($ms.ToArray())
    } finally {
      # Close stdin so children can never inherit a live pipe from us.
      try { if ($null -ne $fs) { $fs.Close() } } catch {}
      try { $stream.Close() } catch {}
    }
  } catch {
    return ''
  }
}

try {
  if (-not (Test-Path -LiteralPath $gitBash)) { throw 'git-bash not found' }
  $hookPath = Join-Path $PSScriptRoot $HookScript
  if (-not (Test-Path -LiteralPath $hookPath)) { throw 'hook script missing: ' + $hookPath }
  $raw = Read-HookStdin
  if ($null -eq $raw) { $raw = '' }
  if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
  $tmpDir = [System.IO.Path]::GetTempPath()
  $tag = [guid]::NewGuid().ToString('n')
  $inFile = Join-Path $tmpDir ('kleos-hook-in-' + $tag + '.json')
  $errFile = Join-Path $tmpDir ('kleos-hook-err-' + $tag + '.txt')
  [System.IO.File]::WriteAllText($inFile, $raw, $utf8)
  try {
    $env:KLEOS_HOOK = Unix-Path $hookPath
    $env:KLEOS_IN = Unix-Path $inFile
    $env:KLEOS_ERR = Unix-Path $errFile
    $out = & $gitBash --noprofile --norc -c 'exec "$KLEOS_HOOK" < "$KLEOS_IN" 2> "$KLEOS_ERR"'
    $code = $LASTEXITCODE
    $errTail = ''
    try {
      if (Test-Path -LiteralPath $errFile) {
        $errTail = [System.IO.File]::ReadAllText($errFile).Trim() -replace '\s+', ' '
        if ($errTail.Length -gt 300) { $errTail = $errTail.Substring(0, 300) }
      }
    } catch {}
    $json = if ($null -eq $out) { '' } elseif ($out -is [array]) { $out -join "`n" } else { [string]$out }
    $json = $json.Trim()
    $verdict = Get-VerdictTag $json
    Write-HookLog ('stdin=' + $raw.Length + 'B exit=' + $code + ' stdout=' + $json.Length + 'B ' + $verdict + ' err=[' + $errTail + ']')
    if ($json -eq '') {
      # Never emit empty stdout: Cursor treats that as "returned no output"
      # and failClosed blocks with no explanation. Emit an explicit verdict.
      $why = 'hook produced no output (exit=' + $code + ')'
      if ($errTail -ne '') { $why += ': ' + $errTail }
      Emit-ShimFailure $why
    }
    Emit-Verdict $json
  } finally {
    Remove-Item -LiteralPath $inFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
  }
} catch {
  try { Write-HookLog ('FATAL: ' + $_.Exception.Message) } catch {}
  Emit-ShimFailure $_.Exception.Message
}
