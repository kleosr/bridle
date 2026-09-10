function Get-GitBashPath {
  foreach ($c in @(
      "$env:ProgramFiles\Git\bin\bash.exe",
      "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
      "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return $null
}

function Get-WindowsJqPath {
  $cmd = Get-Command jq.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($c in @(
      (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\jq.exe'),
      (Join-Path $env:ProgramFiles 'jq\jq.exe')
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

function Test-GitBashJq([string]$Bash) {
  & $Bash --noprofile --norc -c 'command -v jq >/dev/null'
  return ($LASTEXITCODE -eq 0)
}

function Test-WslJq {
  if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
  wsl.exe bash -lc 'command -v jq >/dev/null'
  return ($LASTEXITCODE -eq 0)
}

function Write-HooksJsonWithJq {
  param([string]$JqExe, [string]$SrcJson, [string]$JqFile, [string]$DstJson, [string]$Shim)
  $json = & $JqExe --arg shim $Shim -f $JqFile $SrcJson
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
    throw 'jq rewrite of hooks.json failed'
  }
  $text = if ($json -is [array]) { $json -join "`n" } else { [string]$json }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($DstJson, ($text.Trim() + "`n"), $utf8)
}

function Write-HooksJsonWithGitBash {
  param([string]$Bash, [string]$SrcJson, [string]$JqFile, [string]$DstJson, [string]$Shim)
  $srcU = ConvertTo-GitBashPath $SrcJson
  $jqU = ConvertTo-GitBashPath $JqFile
  $dstU = ConvertTo-GitBashPath $DstJson
  $shimQ = $Shim.Replace("'", "'\''")
  & $Bash --noprofile --norc -c "jq --arg shim '$shimQ' -f '$jqU' '$srcU' > '$dstU'"
  if ($LASTEXITCODE -ne 0) { throw 'jq rewrite of hooks.json failed (Git Bash)' }
}

function Write-HooksJsonWithWsl {
  param([string]$SrcJson, [string]$JqFile, [string]$DstJson, [string]$Shim)
  $srcWsl = (wsl.exe wslpath -a $SrcJson).Trim()
  $jqWsl = (wsl.exe wslpath -a $JqFile).Trim()
  $dstWsl = (wsl.exe wslpath -a $DstJson).Trim()
  $shimQ = $Shim.Replace("'", "'\''")
  wsl.exe bash -lc "jq --arg shim '$shimQ' -f '$jqWsl' '$srcWsl' > '$dstWsl'"
  if ($LASTEXITCODE -ne 0) { throw 'jq rewrite of hooks.json failed (WSL)' }
}

function Merge-HooksJsonFile {
  param([string]$Incoming, [string]$DstJson, [string]$MergeJq)
  if (-not (Test-Path -LiteralPath $DstJson)) {
    Copy-Item -LiteralPath $Incoming -Destination $DstJson -Force
    return
  }
  $out = [System.IO.Path]::GetTempFileName()
  try {
    $jq = Get-WindowsJqPath
    if ($jq) {
      $json = & $jq --arg mode merge --slurpfile dest $DstJson -f $MergeJq $Incoming
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
        throw 'jq merge of hooks.json failed'
      }
      $text = if ($json -is [array]) { $json -join "`n" } else { [string]$json }
      $utf8 = New-Object System.Text.UTF8Encoding $false
      [System.IO.File]::WriteAllText($DstJson, ($text.Trim() + "`n"), $utf8)
      return
    }
    $bash = Get-GitBashPath
    if ($bash -and (Test-GitBashJq $bash)) {
      $inU = ConvertTo-GitBashPath $Incoming
      $dstU = ConvertTo-GitBashPath $DstJson
      $jqU = ConvertTo-GitBashPath $MergeJq
      $outU = ConvertTo-GitBashPath $out
      & $bash --noprofile --norc -c "jq --arg mode merge --slurpfile dest '$dstU' -f '$jqU' '$inU' > '$outU' && mv '$outU' '$dstU'"
      if ($LASTEXITCODE -ne 0) { throw 'jq merge of hooks.json failed (Git Bash)' }
      return
    }
    if (Test-WslJq) {
      $inW = (wsl.exe wslpath -a $Incoming).Trim()
      $dstW = (wsl.exe wslpath -a $DstJson).Trim()
      $jqW = (wsl.exe wslpath -a $MergeJq).Trim()
      $outW = (wsl.exe wslpath -a $out).Trim()
      wsl.exe bash -lc "jq --arg mode merge --slurpfile dest '$dstW' -f '$jqW' '$inW' > '$outW' && mv '$outW' '$dstW'"
      if ($LASTEXITCODE -ne 0) { throw 'jq merge of hooks.json failed (WSL)' }
      return
    }
    throw 'jq not found. Install Git for Windows and: winget install jqlang.jq'
  } finally {
    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
  }
}

function Invoke-HooksJsonRewrite {
  param([string]$SrcJson, [string]$JqFile, [string]$DstJson, [string]$Shim)
  $mergeJq = Join-Path (Split-Path $JqFile) 'hooks_json.jq'
  $tmp = [System.IO.Path]::GetTempFileName()
  try {
    $jq = Get-WindowsJqPath
    if ($jq) {
      Write-HooksJsonWithJq -JqExe $jq -SrcJson $SrcJson -JqFile $JqFile -DstJson $tmp -Shim $Shim
      Merge-HooksJsonFile -Incoming $tmp -DstJson $DstJson -MergeJq $mergeJq
      return 'Git Bash + jq'
    }
    $bash = Get-GitBashPath
    if ($bash -and (Test-GitBashJq $bash)) {
      Write-HooksJsonWithGitBash -Bash $bash -SrcJson $SrcJson -JqFile $JqFile -DstJson $tmp -Shim $Shim
      Merge-HooksJsonFile -Incoming $tmp -DstJson $DstJson -MergeJq $mergeJq
      return 'Git Bash + jq'
    }
    if (Test-WslJq) {
      Write-HooksJsonWithWsl -SrcJson $SrcJson -JqFile $JqFile -DstJson $tmp -Shim $Shim
      Merge-HooksJsonFile -Incoming $tmp -DstJson $DstJson -MergeJq $mergeJq
      return 'WSL'
    }
    throw 'jq not found. Install Git for Windows and: winget install jqlang.jq'
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
  }
}
