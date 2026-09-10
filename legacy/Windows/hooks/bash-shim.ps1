param([Parameter(Mandatory = $true)][string]$HookScript)
$ErrorActionPreference = 'Stop'

$utf8 = New-Object System.Text.UTF8Encoding $false
$stdinReader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8)
$inputJson = $stdinReader.ReadToEnd()
$hookPath = Join-Path $PSScriptRoot $HookScript

function Find-GitBash {
  foreach ($c in @(
      "$env:ProgramFiles\Git\bin\bash.exe",
      "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
      "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function ConvertTo-GitBashPath([string]$WinPath) {
  $full = [System.IO.Path]::GetFullPath($WinPath).Replace('\', '/')
  if ($full -match '^([A-Za-z]):/(.*)$') {
    return '/' + $Matches[1].ToLower() + '/' + $Matches[2]
  }
  return $full
}

function Find-JqDir {
  $cmd = Get-Command jq.exe -ErrorAction SilentlyContinue
  if ($cmd) { return (Split-Path -Parent $cmd.Source) }
  foreach ($c in @(
      "$env:LOCALAPPDATA\Microsoft\WinGet\Links\jq.exe",
      "$env:ProgramFiles\jq\jq.exe"
    )) {
    if (Test-Path -LiteralPath $c) { return (Split-Path -Parent $c) }
  }
  return $null
}

function Invoke-Utf8Process {
  param([string]$FileName, [string]$Arguments, [string]$Stdin)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FileName
  $psi.Arguments = $Arguments
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $psi.StandardOutputEncoding = $script:utf8
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  try {
    if (-not $p.Start()) { return 1 }
  } catch {
    if ($_.Exception.Message) { [Console]::Error.Write([string]$_.Exception.Message) }
    return 1
  }
  $bytes = $script:utf8.GetBytes($Stdin)
  $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
  $p.StandardInput.Close()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if ($stderr) { [Console]::Error.Write($stderr) }
  if ($stdout) { [Console]::Out.Write($stdout) }
  return $p.ExitCode
}

$jqDir = Find-JqDir
if ($jqDir) { $env:PATH = "$jqDir;$env:PATH" }

function Exit-HookProcess([object]$Code) {
  if ($null -eq $Code) { exit 1 }
  exit [int]$Code
}

$bash = Find-GitBash
if ($bash) {
  $unix = ConvertTo-GitBashPath $hookPath
  Exit-HookProcess (Invoke-Utf8Process -FileName $bash -Arguments "--noprofile --norc `"$unix`"" -Stdin $inputJson)
}
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
  $wslPath = (wsl.exe wslpath -a $hookPath).Trim()
  Exit-HookProcess (Invoke-Utf8Process -FileName 'wsl.exe' -Arguments "bash --noprofile --norc $wslPath" -Stdin $inputJson)
}
throw 'Git Bash not found. Install Git for Windows and jq (winget install jqlang.jq).'
