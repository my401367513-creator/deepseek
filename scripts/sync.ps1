#Requires -Version 7.0

param(
  [ValidateSet('sync','pull','push','status')]
  [string]$Action = 'sync',
  [string]$Message = '',
  [string]$Tag = ''
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Git([string[]]$Arguments) {
  & git -C $repoRoot @Arguments
  if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed" }
}

function Reset-Staging([string[]]$Paths) {
  if ($Paths.Count -gt 0) {
    Invoke-Git (@('restore','--staged','--') + $Paths)
  }
}

function Test-AllowedRepositoryPath([string]$Path, [switch]$AllowLegacy) {
  $normalized = $Path.Replace('\', '/')
  if ($normalized -match '^(\.gitignore|AGENTS\.md|README\.md|VERSION)$') { return $true }
  if ($normalized -match '^docs/agents/(domain|issue-tracker|triage-labels)\.md$') { return $true }
  if ($normalized -match '^scripts/(install|sync|validate)\.ps1$') { return $true }
  if ($normalized -match '^skills/(short-drama-director|short-drama-script-analysis|short-drama-story-writing|short-drama-assets|short-drama-prompts|short-drama-image-design)/(SKILL\.md|agents/openai\.yaml)$') { return $true }
  if ($normalized -match '^skills/(short-drama-script-analysis|short-drama-story-writing)/references/quality/[a-z0-9][a-z0-9-]*\.md$') { return $true }
  if ($normalized -match '^skills/short-drama-director/references/[a-z0-9][a-z0-9-]*\.md$') { return $true }
  if ($normalized -match '^skills/short-drama-script-analysis/references/(analysis-workflow|commercial-observation|downstream-handoff)\.md$') { return $true }
  if ($normalized -match '^skills/short-drama-script-analysis/references/downstream-handoff\.schema\.json$') { return $true }
  if ($normalized -match '^skills/short-drama-script-analysis/references/fixtures/[a-z0-9][a-z0-9-]*\.json$') { return $true }
  if ($normalized -match '^skills/short-drama-assets/references/quality/[a-z0-9][a-z0-9-]*\.md$') { return $true }
  if ($normalized -match '^skills/short-drama-prompts/references/(modules|templates|adapters|libraries|quality|maintenance)/[a-z0-9][a-z0-9-]*\.md$') { return $true }
  if ($normalized -match '^skills/short-drama-image-design/references/(quality/)?[a-z0-9][a-z0-9-]*\.md$') { return $true }

  $legacyPromptFiles = '^skills/short-drama-prompts/references/(delivery-checklist|director-compact-format|lighting-library|seedance|shot-library)\.md$'
  return $AllowLegacy -and $normalized -match $legacyPromptFiles
}

function Test-AllowedSyncPath([string]$Status, [string]$Path) {
  if (Test-AllowedRepositoryPath $Path) { return $true }
  return $Status -eq 'D' -and (Test-AllowedRepositoryPath $Path -AllowLegacy)
}

function Get-GitBlobBytes([string]$ObjectSpec) {
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = 'git'
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in @('-C', $repoRoot, 'cat-file', 'blob', $ObjectSpec)) {
    $startInfo.ArgumentList.Add($argument)
  }
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  $memory = [System.IO.MemoryStream]::new()
  try {
    if (-not $process.Start()) { throw "Unable to start git cat-file for $ObjectSpec" }
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $process.WaitForExit()
    $errorText = $errorTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) {
      throw "Unable to read Git blob $ObjectSpec`: $errorText"
    }
    return $memory.ToArray()
  } finally {
    $memory.Dispose()
    $process.Dispose()
  }
}

function Test-GitObjectPrivacy([object[]]$Entries, [string]$Revision = '') {
  $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
  $violations = New-Object System.Collections.Generic.List[string]
  foreach ($entry in $Entries) {
    if ($entry.Status -eq 'D') { continue }
    $objectSpec = if ([string]::IsNullOrWhiteSpace($Revision)) { ":$($entry.Path)" } else { "$Revision`:$($entry.Path)" }
    try {
      [byte[]]$bytes = Get-GitBlobBytes $objectSpec
    } catch {
      $violations.Add($_.Exception.Message)
      continue
    }
    if ($bytes.Length -gt 262144) {
      $violations.Add("Text file exceeds 256 KiB: $($entry.Path)")
      continue
    }
    try {
      $content = $strictUtf8.GetString($bytes)
    } catch {
      $violations.Add("Git blob is not strict UTF-8 text: $($entry.Path)")
      continue
    }
    if ($content.Contains([char]0)) {
      $violations.Add("NUL byte detected: $($entry.Path)")
    }
    $windowsAbsolutePath = '(?i)\b[A-Z]:[\\/](?:[^\\/\s<>:"''|?*]+[\\/])*[^\\/\s<>:"''|?*]+'
    $pathSeparator = [char]92
    $uncAbsolutePath = "(?i)${pathSeparator}${pathSeparator}[^\\/\s<>:|?*]+[\\/][^\r\n\s<>:|?*]+"
    $unixAbsolutePath = '(?i)(?<![\w:])/(?:Users|home|opt|srv|var|tmp|mnt|workspace|project|etc|usr|root|private|data|app|work)(?:/[^/\s<>:"''|?]+)+'
    if ($content -match "(?:$windowsAbsolutePath|$uncAbsolutePath|$unixAbsolutePath)") {
      $violations.Add("Absolute path detected: $($entry.Path)")
    }
    if ($content -match '(?i)data:(?:image|audio|video)/[^;\s]+;base64,') {
      $violations.Add("Embedded media payload detected: $($entry.Path)")
    }
    if ($content -match '(?i)(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)') {
      $violations.Add("Possible credential detected: $($entry.Path)")
    }
  }
  return $violations
}

function Get-HeadEntries {
  $paths = @(& git -C $repoRoot ls-tree -r --name-only HEAD)
  if ($LASTEXITCODE -ne 0) { throw 'Unable to list the HEAD tree.' }
  return @($paths | ForEach-Object { [pscustomobject]@{ Status = 'A'; Path = $_ } })
}

function Assert-HeadTree {
  $entries = @(Get-HeadEntries)
  $blocked = @($entries | Where-Object { -not (Test-AllowedRepositoryPath $_.Path -AllowLegacy) } | ForEach-Object { $_.Path })
  if ($blocked.Count -gt 0) {
    throw "HEAD contains files outside the repository allowlist: $($blocked -join ', ')"
  }
  $violations = @(Test-GitObjectPrivacy $entries -Revision 'HEAD')
  if ($violations.Count -gt 0) {
    throw "HEAD privacy scan failed: $($violations -join ' | ')"
  }
}

function Assert-WorkingSkillsMatchHead {
  $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
  $workingPaths = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'skills') -Recurse -Force -File | ForEach-Object {
    [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\', '/')
  } | Sort-Object)
  $headPaths = @(& git -C $repoRoot ls-tree -r --name-only HEAD -- skills | Sort-Object)
  if ($LASTEXITCODE -ne 0) { throw 'Unable to list HEAD skill files.' }
  $difference = @(Compare-Object $headPaths $workingPaths)
  if ($difference.Count -gt 0) {
    $details = $difference | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }
    throw "Working skill tree does not exactly match HEAD: $($details -join ', ')"
  }
  & git -C $repoRoot diff --quiet HEAD -- skills
  if ($LASTEXITCODE -eq 1) { throw 'Tracked skill files differ from HEAD.' }
  if ($LASTEXITCODE -ne 0) { throw 'Unable to compare working skills with HEAD.' }
  foreach ($path in $workingPaths) {
    try {
      $workingText = $strictUtf8.GetString([System.IO.File]::ReadAllBytes((Join-Path $repoRoot $path)))
      $headText = $strictUtf8.GetString([byte[]](Get-GitBlobBytes "HEAD`:$path"))
    } catch {
      throw "Unable to compare raw UTF-8 skill content for $path`: $($_.Exception.Message)"
    }
    $normalizedWorking = $workingText.Replace("`r`n", "`n").Replace("`r", "`n")
    $normalizedHead = $headText.Replace("`r`n", "`n").Replace("`r", "`n")
    if ($normalizedWorking -cne $normalizedHead) {
      throw "Working skill content differs from HEAD beyond line endings: $path"
    }
  }
}

function Assert-ReleaseTagInput([string]$ReleaseTag) {
  if ([string]::IsNullOrWhiteSpace($ReleaseTag)) { return }
  if ($ReleaseTag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:[-.][A-Za-z0-9][A-Za-z0-9.-]*)?$') {
    throw "Invalid release tag: $ReleaseTag"
  }
  $repoVersion = (Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'VERSION')).Trim()
  if ($ReleaseTag -ne "v$repoVersion") {
    throw "Release tag $ReleaseTag does not match VERSION $repoVersion"
  }
}

function Assert-SafeCommitMessage([string]$CommitMessage) {
  if ($CommitMessage.Length -gt 120 -or $CommitMessage -notmatch '\A(feat|fix|refactor|docs|chore|sync|release): [A-Za-z0-9][A-Za-z0-9 .,_()+:-]*\z') {
    throw 'Commit message must be one ASCII line of at most 120 characters using an approved maintenance prefix.'
  }
  if ($CommitMessage -match '(?i)(?:[A-Z]:[\\/]|/(?:Users|home)/|data:(?:image|audio|video)/|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|PRIVATE KEY)') {
    throw 'Commit message contains a path, media payload, or possible credential marker.'
  }
}

function Publish-Tag([string]$ReleaseTag) {
  if ([string]::IsNullOrWhiteSpace($ReleaseTag)) { return }
  Assert-ReleaseTagInput $ReleaseTag

  $head = (& git -C $repoRoot rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve HEAD.' }
  & git -C $repoRoot show-ref --verify --quiet "refs/tags/$ReleaseTag"
  $localTagExists = $LASTEXITCODE -eq 0
  if ($localTagExists) {
    $localType = (& git -C $repoRoot cat-file -t "refs/tags/$ReleaseTag").Trim()
    if ($LASTEXITCODE -ne 0 -or $localType -ne 'tag') {
      throw "Local tag $ReleaseTag is not annotated. Refusing to publish it."
    }
    $localTarget = (& git -C $repoRoot rev-list -n 1 $ReleaseTag).Trim()
    if ($LASTEXITCODE -ne 0 -or $localTarget -ne $head) {
      throw "Local tag $ReleaseTag does not point to HEAD. Refusing to move it."
    }
  } else {
    Invoke-Git @('tag','-a',$ReleaseTag,'-m',"Codex Short Drama Director $ReleaseTag")
  }

  $remoteLines = @(& git -C $repoRoot ls-remote --tags origin "refs/tags/$ReleaseTag" "refs/tags/$ReleaseTag^{}")
  if ($LASTEXITCODE -ne 0) { throw "Unable to inspect remote tag $ReleaseTag" }
  if ($remoteLines.Count -gt 0) {
    $peeled = $remoteLines | Where-Object { $_ -match '\^\{\}$' } | Select-Object -First 1
    if (-not $peeled) {
      throw "Remote tag $ReleaseTag is not annotated. Refusing to overwrite it."
    }
    $remoteTarget = ($peeled -split "`t")[0]
    if ($remoteTarget -ne $head) {
      throw "Remote tag $ReleaseTag already exists at another commit. Refusing to overwrite it."
    }
    Write-Host "[sync] Remote tag already matches HEAD: $ReleaseTag"
    return
  }
  Invoke-Git @('push','origin',"refs/tags/$ReleaseTag`:refs/tags/$ReleaseTag")
}

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
  throw "Not a Git repository: $repoRoot"
}

if (-not [string]::IsNullOrWhiteSpace($Tag) -and $Action -notin @('sync','push')) {
  throw 'Release tags are supported only by sync or push actions.'
}
Assert-ReleaseTagInput $Tag

if ($Action -eq 'status') {
  Invoke-Git @('status','--short','--branch')
  exit 0
}

$branch = (& git -C $repoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') {
  throw "Sync is restricted to the main branch; current branch: $branch"
}
$origin = (& git -C $repoRoot remote get-url origin).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($origin)) { throw 'Remote origin is not configured.' }
$upstream = (& git -C $repoRoot rev-parse --abbrev-ref --symbolic-full-name '@{u}').Trim()
if ($LASTEXITCODE -ne 0 -or $upstream -ne 'origin/main') {
  throw "Expected upstream origin/main; current upstream: $upstream"
}

$preStaged = (& git -C $repoRoot diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw 'git diff --cached failed' }
if ($preStaged) {
  throw "Refusing to alter an existing staged index. Commit or unstage first: $($preStaged -join ', ')"
}

if ($Action -in @('sync','pull')) {
  Invoke-Git @('pull','--ff-only')
}

& (Join-Path $PSScriptRoot 'validate.ps1') -SkillsRoot (Join-Path $repoRoot 'skills')

if ($Action -eq 'pull') {
  Assert-HeadTree
  Assert-WorkingSkillsMatchHead
  & (Join-Path $PSScriptRoot 'install.ps1')
  Write-Host '[sync] Pull, validation, and local skill installation completed.'
  exit 0
}

$changes = (& git -C $repoRoot status --porcelain) | Out-String
if ($LASTEXITCODE -ne 0) { throw 'git status failed' }
if ([string]::IsNullOrWhiteSpace($changes)) {
  Write-Host '[sync] No changes to commit.'
  Assert-HeadTree
  Assert-WorkingSkillsMatchHead
  & (Join-Path $PSScriptRoot 'install.ps1')
  Invoke-Git @('push','origin','main:main')
  Publish-Tag $Tag
  exit 0
}

Invoke-Git @('add','-A','--','.gitignore','AGENTS.md','README.md','VERSION','docs','scripts','skills')
$stagedLines = @(& git -C $repoRoot diff --cached --name-status --no-renames)
if ($LASTEXITCODE -ne 0) { throw 'git diff --cached failed' }
if ($stagedLines.Count -eq 0) {
  Write-Host '[sync] No allowlisted changes to commit.'
  Assert-HeadTree
  Assert-WorkingSkillsMatchHead
  Invoke-Git @('push','origin','main:main')
  & (Join-Path $PSScriptRoot 'install.ps1')
  Publish-Tag $Tag
  exit 0
}
$entries = @($stagedLines | ForEach-Object {
  $parts = $_ -split "`t", 2
  [pscustomobject]@{ Status = $parts[0]; Path = $parts[1] }
})
$stagedPaths = @($entries | ForEach-Object { $_.Path })
$blocked = @($entries | Where-Object {
  -not (Test-AllowedSyncPath $_.Status $_.Path)
} | ForEach-Object { $_.Path })
if ($blocked.Count -gt 0) {
  Reset-Staging $stagedPaths
  throw "Files outside the strict skill allowlist are blocked from cloud sync: $($blocked -join ', ')"
}

$privacyViolations = @(Test-GitObjectPrivacy $entries)
if ($privacyViolations.Count -gt 0) {
  Reset-Staging $stagedPaths
  throw "Privacy scan blocked cloud sync: $($privacyViolations -join ' | ')"
}
& (Join-Path $PSScriptRoot 'install.ps1')
$expectedTree = (& git -C $repoRoot write-tree).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedTree)) {
  Reset-Staging $stagedPaths
  throw 'Unable to record the audited index tree.'
}
if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = 'sync: update skills ' + (Get-Date -Format 'yyyy-MM-dd HH-mm')
}
Assert-SafeCommitMessage $Message
try {
  Invoke-Git @('commit','-m',$Message)
} catch {
  Reset-Staging $stagedPaths
  throw
}
$committedTree = (& git -C $repoRoot rev-parse 'HEAD^{tree}').Trim()
if ($LASTEXITCODE -ne 0 -or $committedTree -ne $expectedTree) {
  throw 'The committed tree differs from the audited index. Refusing to push or tag.'
}
$committedMessage = (& git -C $repoRoot log -1 --format='%s').Trim()
if ($LASTEXITCODE -ne 0 -or $committedMessage -ne $Message) {
  throw 'The committed message differs from the approved message. Refusing to push or tag.'
}
Assert-HeadTree
Assert-WorkingSkillsMatchHead
Invoke-Git @('push','origin','main:main')
Publish-Tag $Tag
