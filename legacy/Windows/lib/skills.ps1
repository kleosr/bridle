# Retired leftover cleanup. Cursor catalogs ~/.cursor/skills/*/SKILL.md.
# Only pack installer suffix-baks (retired-skill stem + .pre-kleos-bak) are moved.
# Existing kleos-bak entries are never overwritten; extras park as name.2, name.3, ...

function Move-KleosSkillToBak {
  param(
    [Parameter(Mandatory = $true)][string]$From,
    [Parameter(Mandatory = $true)][string]$BakRoot,
    [Parameter(Mandatory = $true)][string]$Name
  )
  New-Item -ItemType Directory -Force $BakRoot | Out-Null
  $dest = Join-Path $BakRoot $Name
  if (-not (Test-Path -LiteralPath $dest)) {
    Move-Item -LiteralPath $From -Destination $dest
    return
  }
  $n = 2
  while (Test-Path -LiteralPath (Join-Path $BakRoot "$Name.$n")) { $n++ }
  Move-Item -LiteralPath $From -Destination (Join-Path $BakRoot "$Name.$n")
}

function Remove-KleosRetiredSkills {
  param(
    [Parameter(Mandatory = $true)][string]$Pack,
    [Parameter(Mandatory = $true)][string]$HomeC
  )
  $skillsDst = Join-Path $HomeC 'skills'
  $skillBak = Join-Path $HomeC 'kleos-bak\skills'
  if (-not (Test-Path -LiteralPath $skillsDst)) { return }

  $retired = @{}
  $txt = Join-Path $Pack 'shared\config\retired-skills.txt'
  if (Test-Path -LiteralPath $txt) {
    Get-Content $txt | ForEach-Object {
      $line = $_.Trim()
      if (-not $line -or $line.StartsWith('#')) { return }
      $retired[$line] = $true
    }
  }

  Get-ChildItem -LiteralPath $skillsDst -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*.pre-kleos-bak' } |
    ForEach-Object {
      $stem = $_.Name
      if ($stem.EndsWith('.pre-kleos-bak')) {
        $stem = $stem.Substring(0, $stem.Length - '.pre-kleos-bak'.Length)
      }
      if (-not $retired.ContainsKey($stem)) { return }
      Move-KleosSkillToBak -From $_.FullName -BakRoot $skillBak -Name $stem
    }
}
