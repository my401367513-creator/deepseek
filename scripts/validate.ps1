#Requires -Version 7.0

param(
  [string]$SkillsRoot = ''
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
  $SkillsRoot = Join-Path $repoRoot 'skills'
}
$SkillsRoot = [System.IO.Path]::GetFullPath($SkillsRoot)
if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) {
  throw "Skills root not found: $SkillsRoot"
}

$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$validator = Join-Path $codexRoot 'skills\.system\skill-creator\scripts\quick_validate.py'
if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
  throw "Skill validator not found: $validator"
}

$pythonCandidates = @(@(
  $env:CODEX_PYTHON,
  (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Leaf) })
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCommand -and $pythonCommand.Source -notin $pythonCandidates) {
  $pythonCandidates += $pythonCommand.Source
}
if (-not $pythonCandidates) { throw 'No usable Python runtime found.' }
$python = $null
foreach ($candidate in $pythonCandidates) {
  try {
    & $candidate -X utf8 -c 'import sys; assert sys.version_info >= (3, 9)' *> $null
    if ($LASTEXITCODE -eq 0) { $python = $candidate; break }
  } catch { continue }
}
if (-not $python) { throw "No usable Python runtime among: $($pythonCandidates -join ', ')" }

$skillNames = @(
  'short-drama-director',
  'short-drama-script-analysis',
  'short-drama-assets',
  'short-drama-prompts'
)
$expectedVersion = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw -Encoding utf8).Trim()

foreach ($name in $skillNames) {
  $skillDir = Join-Path $SkillsRoot $name
  $skillFile = Join-Path $skillDir 'SKILL.md'
  if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
    throw "Missing skill: $skillFile"
  }
  & $python -X utf8 $validator $skillDir
  if ($LASTEXITCODE -ne 0) { throw "Skill validation failed: $name" }

  $skillText = Get-Content -LiteralPath $skillFile -Raw -Encoding utf8
  $versionMatch = [regex]::Match($skillText, '(?m)^\s*version:\s*"([^"]+)"\s*$')
  if (-not $versionMatch.Success -or $versionMatch.Groups[1].Value -ne $expectedVersion) {
    throw "Version mismatch in $name; expected $expectedVersion"
  }
}

$markdownFiles = foreach ($name in $skillNames) {
  Get-ChildItem -LiteralPath (Join-Path $SkillsRoot $name) -Recurse -File -Filter '*.md'
}
foreach ($file in $markdownFiles) {
  $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
  foreach ($match in [regex]::Matches($text, '\[[^\]]+\]\(([^)]+)\)')) {
    $target = $match.Groups[1].Value.Split('#')[0]
    if ([string]::IsNullOrWhiteSpace($target) -or $target -match '^(https?:|mailto:|#)') { continue }
    if ([System.IO.Path]::IsPathRooted($target) -or $target.StartsWith('\\')) {
      throw "Absolute or UNC links are not allowed in $($file.FullName): $target"
    }
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $target))
    $skillsPrefix = $SkillsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($skillsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Relative link escapes the skills root in $($file.FullName): $target"
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
      throw "Broken relative link in $($file.FullName): $target"
    }
  }
}

$promptRoot = Join-Path $SkillsRoot 'short-drama-prompts'
$requiredPromptFiles = @(
  'references\modules\source-context.md',
  'references\modules\audio-timeline.md',
  'references\modules\assets-references.md',
  'references\modules\performance.md',
  'references\modules\shot-continuity.md',
  'references\modules\timing-segmentation.md',
  'references\modules\project-style.md',
  'references\modules\output-format.md',
  'references\templates\director-compact.md',
  'references\adapters\seedance.md',
  'references\libraries\camera.md',
  'references\libraries\lighting.md',
  'references\libraries\ritual-vfx.md',
  'references\quality\delivery-checklist.md',
  'references\maintenance\rule-index.md'
)
foreach ($relative in $requiredPromptFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $promptRoot $relative) -PathType Leaf)) {
    throw "Missing prompt module: $relative"
  }
}

Write-Host "[validate] 3.0 skills, versions, links, and module routing passed: $SkillsRoot"
