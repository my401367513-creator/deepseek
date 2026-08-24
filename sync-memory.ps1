<#
  sync-memory.ps1 — 短剧创作助手记忆库的 Git 云端同步脚本
  用法（在记忆库目录内，或在任意位置执行）：
    .\sync-memory.ps1            # 同步：先拉取，有改动则提交并推送
    .\sync-memory.ps1 pull       # 只拉取远端
    .\sync-memory.ps1 push       # 提交本地改动并推送
    .\sync-memory.ps1 status     # 查看仓库状态

  记忆根目录解析：环境变量 $env:SHORT_DRAMA_MEMORY 存在则用之，否则用本脚本所在目录。
  首次使用需先初始化 git 私有仓库（见下方提示）。
#>
param([ValidateSet('sync', 'pull', 'push', 'status')][string]$Action = 'sync')

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
if ($env:SHORT_DRAMA_MEMORY -and (Test-Path $env:SHORT_DRAMA_MEMORY)) {
  $root = $env:SHORT_DRAMA_MEMORY
}

if (-not (Test-Path (Join-Path $root '.git'))) {
  Write-Host "[sync-memory] $root 还不是 git 仓库。" -ForegroundColor Yellow
  Write-Host "初始化步骤：" -ForegroundColor Yellow
  Write-Host "  cd $root"
  Write-Host "  git init"
  Write-Host "  git add -A"
  Write-Host "  git commit -m init"
  Write-Host "  git remote add origin <你的私有仓库地址, 如 https://gitee.com/you/memory.git>"
  Write-Host "  git push -u origin HEAD"
  exit 2
}

function Invoke-Git([string]$Label, [string[]]$GitArgs) {
  Write-Host "[sync-memory] $Label ..." -ForegroundColor Cyan
  & git -C $root @GitArgs
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[sync-memory] $Label 失败 (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
  }
}

$dirty = (& git -C $root status --porcelain) | Out-String
$hasChanges = $dirty.Trim().Length -gt 0

switch ($Action) {
  'status' {
    & git -C $root status --short --branch
    Write-Host "[sync-memory] status 完成" -ForegroundColor Green
    break
  }
  'pull' {
    Invoke-Git 'pull' @('pull', '--ff-only')
    Write-Host "[sync-memory] pull 完成" -ForegroundColor Green
    break
  }
  'push' {
    if (-not $hasChanges) { Write-Host "[sync-memory] 没有本地改动，跳过提交" -ForegroundColor DarkGray }
    else {
      Invoke-Git 'add' @('add', '-A')
      Invoke-Git 'commit' @('commit', '-m', ("sync " + (Get-Date -Format 'yyyy-MM-dd HH:mm')))
      Invoke-Git 'push' @('push')
    }
    Write-Host "[sync-memory] push 完成" -ForegroundColor Green
    break
  }
  default {
    Invoke-Git 'pull' @('pull', '--ff-only')
    if (-not $hasChanges) { Write-Host "[sync-memory] 没有本地改动，跳过提交" -ForegroundColor DarkGray }
    else {
      Invoke-Git 'add' @('add', '-A')
      Invoke-Git 'commit' @('commit', '-m', ("sync " + (Get-Date -Format 'yyyy-MM-dd HH:mm')))
      Invoke-Git 'push' @('push')
    }
    Write-Host "[sync-memory] 同步完成" -ForegroundColor Green
  }
}
