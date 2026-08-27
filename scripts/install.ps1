#Requires -Version 7.0

param(
  [string]$TargetRoot = '',
  [switch]$AllowCustomTarget
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'skills'
$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$defaultTargetRoot = [System.IO.Path]::GetFullPath((Join-Path $codexRoot 'skills'))
$customTargetRequested = -not [string]::IsNullOrWhiteSpace($TargetRoot)
if (-not $customTargetRequested) {
  $TargetRoot = $defaultTargetRoot
} else {
  $TargetRoot = [System.IO.Path]::GetFullPath($TargetRoot)
  if (-not $AllowCustomTarget) {
    throw 'Custom TargetRoot requires -AllowCustomTarget.'
  }
}

function Test-PathOverlap([string]$Left, [string]$Right) {
  $separator = [System.IO.Path]::DirectorySeparatorChar
  $leftPath = [System.IO.Path]::GetFullPath($Left).TrimEnd($separator)
  $rightPath = [System.IO.Path]::GetFullPath($Right).TrimEnd($separator)
  return $leftPath.Equals($rightPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    $leftPath.StartsWith($rightPath + $separator, [System.StringComparison]::OrdinalIgnoreCase) -or
    $rightPath.StartsWith($leftPath + $separator, [System.StringComparison]::OrdinalIgnoreCase)
}

if ($TargetRoot.StartsWith('\\') -or [System.IO.Path]::GetPathRoot($TargetRoot) -eq $TargetRoot) {
  throw "Refusing unsafe target root: $TargetRoot"
}
if ((Test-PathOverlap $TargetRoot $repoRoot) -or (Test-PathOverlap $TargetRoot $sourceRoot)) {
  throw "Target must not overlap the repository or source skills: $TargetRoot"
}
if (Test-Path -LiteralPath $TargetRoot) {
  $targetItem = Get-Item -LiteralPath $TargetRoot -Force
  if ($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    throw "Target root must not be a reparse point: $TargetRoot"
  }
}
[System.IO.Directory]::CreateDirectory($TargetRoot) | Out-Null
$TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path
if (-not $AllowCustomTarget -and -not $TargetRoot.Equals($defaultTargetRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Default installation must target $defaultTargetRoot"
}

$skillNames = @(
  'short-drama-director',
  'short-drama-script-analysis',
  'short-drama-assets',
  'short-drama-prompts'
)
& (Join-Path $PSScriptRoot 'validate.ps1') -SkillsRoot $sourceRoot

$runId = [guid]::NewGuid().ToString('N')
$installParent = [System.IO.Path]::GetDirectoryName($TargetRoot)
$workRoot = Join-Path $installParent '.short-drama-installs'
$runRoot = Join-Path $workRoot $runId
$stagingRoot = Join-Path $runRoot 'staging'
$backupRoot = Join-Path $runRoot 'backup'
$failedRoot = Join-Path $runRoot 'failed'
foreach ($path in @($workRoot, $runRoot, $stagingRoot, $backupRoot, $failedRoot)) {
  $full = [System.IO.Path]::GetFullPath($path)
  $allowedRoot = [System.IO.Path]::GetFullPath($installParent) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe temporary path: $full"
  }
}
[System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null

function Get-TreeManifest([string]$Root) {
  $items = Get-ChildItem -LiteralPath $Root -Recurse -Force
  $reparse = $items | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint }
  if ($reparse) { throw "Reparse points are not allowed in skill trees: $($reparse.FullName -join ', ')" }
  return $items | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
    $relative = [System.IO.Path]::GetRelativePath($Root, $_.FullName)
    "$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
  } | Sort-Object
}

foreach ($name in $skillNames) {
  Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination (Join-Path $stagingRoot $name) -Recurse
}
& (Join-Path $PSScriptRoot 'validate.ps1') -SkillsRoot $stagingRoot
foreach ($name in $skillNames) {
  if (Compare-Object (Get-TreeManifest (Join-Path $sourceRoot $name)) (Get-TreeManifest (Join-Path $stagingRoot $name))) {
    throw "Staging hash mismatch: $name"
  }
}

$installed = New-Object System.Collections.Generic.List[string]
try {
  foreach ($name in $skillNames) {
    $target = Join-Path $TargetRoot $name
    $backup = Join-Path $backupRoot $name
    if (Test-Path -LiteralPath $target) { Move-Item -LiteralPath $target -Destination $backup }
    Move-Item -LiteralPath (Join-Path $stagingRoot $name) -Destination $target
    $installed.Add($name)
  }

  & (Join-Path $PSScriptRoot 'validate.ps1') -SkillsRoot $TargetRoot

  foreach ($name in $skillNames) {
    $source = Join-Path $sourceRoot $name
    $target = Join-Path $TargetRoot $name
    if (Compare-Object (Get-TreeManifest $source) (Get-TreeManifest $target)) { throw "Installed hash mismatch: $name" }
  }
} catch {
  $originalError = $_.Exception.Message
  $rollbackErrors = New-Object System.Collections.Generic.List[string]
  try { [System.IO.Directory]::CreateDirectory($failedRoot) | Out-Null } catch {
    $rollbackErrors.Add("Cannot create failed-install directory: $($_.Exception.Message)")
  }
  for ($index = $installed.Count - 1; $index -ge 0; $index--) {
    $name = $installed[$index]
    $target = Join-Path $TargetRoot $name
    if (Test-Path -LiteralPath $target) {
      try {
        Move-Item -LiteralPath $target -Destination (Join-Path $failedRoot $name)
      } catch {
        $rollbackErrors.Add("Cannot preserve failed $name installation: $($_.Exception.Message)")
      }
    }
  }
  for ($index = $skillNames.Count - 1; $index -ge 0; $index--) {
    $name = $skillNames[$index]
    $target = Join-Path $TargetRoot $name
    $backup = Join-Path $backupRoot $name
    if ((Test-Path -LiteralPath $backup) -and -not (Test-Path -LiteralPath $target)) {
      try {
        Move-Item -LiteralPath $backup -Destination $target
      } catch {
        $rollbackErrors.Add("Cannot restore $name backup: $($_.Exception.Message)")
      }
    } elseif ((Test-Path -LiteralPath $backup) -and (Test-Path -LiteralPath $target)) {
      $rollbackErrors.Add("Cannot restore $name because the target is still occupied.")
    }
  }
  if ($rollbackErrors.Count -gt 0) {
    throw "Install failed: $originalError Rollback incomplete: $($rollbackErrors -join ' | ') Recovery data kept at: $runRoot"
  }
  throw "Install failed and all previous skills were restored: $originalError"
}

if (Test-Path -LiteralPath $runRoot) {
  $resolved = [System.IO.Path]::GetFullPath($runRoot)
  $allowedWorkRoot = [System.IO.Path]::GetFullPath($workRoot) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($allowedWorkRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe cleanup: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}

Write-Host "[install] Installed and hash-verified 3.0 skills: $TargetRoot"
