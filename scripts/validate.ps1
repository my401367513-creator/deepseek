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
  'short-drama-story-writing',
  'short-drama-assets',
  'short-drama-prompts',
  'short-drama-image-design'
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
  'references\libraries\directing-decisions.md',
  'references\libraries\shot-scale-atmosphere.md',
  'references\libraries\axis-line.md',
  'references\libraries\lighting.md',
  'references\libraries\ritual-vfx.md',
  'references\quality\delivery-checklist.md',
  'references\quality\generation-recovery.md',
  'references\maintenance\rule-index.md'
)
foreach ($relative in $requiredPromptFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $promptRoot $relative) -PathType Leaf)) {
    throw "Missing prompt module: $relative"
  }
}
$requiredAnalysisFiles = @(
  'references\downstream-handoff.schema.json',
  'references\fixtures\handoff-valid.json',
  'references\fixtures\handoff-invalid-route.json'
)
$analysisRoot = Join-Path $SkillsRoot 'short-drama-script-analysis'
foreach ($relative in $requiredAnalysisFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $analysisRoot $relative) -PathType Leaf)) {
    throw "Missing analysis handoff contract file: $relative"
  }
}
$assetReviewPath = Join-Path $SkillsRoot 'short-drama-assets\references\quality\asset-review.md'
if (-not (Test-Path -LiteralPath $assetReviewPath -PathType Leaf)) { throw 'Missing asset review contract.' }
$videoExecutionPath = Join-Path $SkillsRoot 'short-drama-director\references\video-site-execution.md'
if (-not (Test-Path -LiteralPath $videoExecutionPath -PathType Leaf)) { throw 'Missing video site execution contract.' }
$narrativePrinciplesPath = Join-Path $SkillsRoot 'short-drama-director\references\narrative-directing-principles.md'
if (-not (Test-Path -LiteralPath $narrativePrinciplesPath -PathType Leaf)) { throw 'Missing director narrative principles.' }

function Assert-Contains([string]$RelativePath, [string]$Expected) {
  $path = Join-Path $SkillsRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing invariant file: $RelativePath" }
  $text = Get-Content -LiteralPath $path -Raw -Encoding utf8
  if (-not $text.Contains($Expected)) { throw "Confirmed invariant missing in $RelativePath`: $Expected" }
}

function Assert-NotContains([string]$RelativePath, [string]$Forbidden) {
  $path = Join-Path $SkillsRoot $RelativePath
  $text = Get-Content -LiteralPath $path -Raw -Encoding utf8
  if ($text.Contains($Forbidden)) { throw "Regressed rule detected in $RelativePath`: $Forbidden" }
}

function Get-HandoffValidationErrors([string]$RelativePath) {
  $path = Join-Path $SkillsRoot $RelativePath
  $errors = New-Object System.Collections.Generic.List[string]
  try {
    $root = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100 -ErrorAction Stop
  } catch {
    return @("JSON parse failed: $RelativePath - $($_.Exception.Message)")
  }

  foreach ($required in @('schema_version','source_script','analysis_status','global_model','scenes','facts','issues','assumptions','confirmed_actions','routes')) {
    if (-not $root.PSObject.Properties[$required]) { $errors.Add("Missing top-level field: $required") }
  }
  if ($root.schema_version -ne '1.0') { $errors.Add('schema_version must be 1.0') }
  if ($root.analysis_status -notin @('candidate','approved')) { $errors.Add('analysis_status must be candidate or approved') }

  $source = $root.PSObject.Properties['source_script']
  if ($source) {
    foreach ($required in @('path','version','scope','evidence_locator')) {
      if (-not $source.Value.PSObject.Properties[$required] -or [string]::IsNullOrWhiteSpace([string]$source.Value.$required)) {
        $errors.Add("source_script.$required must be non-empty")
      }
    }
  }

  $entityNames = @('scenes','facts','issues','assumptions','confirmed_actions')
  $entityIdNames = @{ scenes = 'scene_id'; facts = 'id'; issues = 'id'; assumptions = 'id'; confirmed_actions = 'id' }
  $entityIds = @{}
  $entityItems = @{}
  foreach ($entityName in $entityNames) {
    $entityIds[$entityName] = @{}
    $entityItems[$entityName] = @()
    $property = $root.PSObject.Properties[$entityName]
    if (-not $property) { continue }
    if ($property.Value -is [string] -or $property.Value -isnot [System.Collections.IEnumerable]) {
      $errors.Add("$entityName must be an array")
      continue
    }
    $entityItems[$entityName] = @($property.Value)
    foreach ($item in @($property.Value)) {
      if ($null -eq $item) { $errors.Add("$entityName contains null"); continue }
      $idName = $entityIdNames[$entityName]
      $idProperty = $item.PSObject.Properties[$idName]
      $id = if ($idProperty) { [string]$idProperty.Value } else { '' }
      if ($id -notmatch '^[A-Za-z][A-Za-z0-9_-]{1,63}$') {
        $errors.Add("$entityName has invalid stable ID: $id")
        continue
      }
      $duplicate = $entityIds[$entityName].ContainsKey($id)
      if (-not $duplicate) {
        foreach ($existingEntity in $entityIds.Keys) {
          if ($existingEntity -ne $entityName -and $entityIds[$existingEntity].ContainsKey($id)) {
            $duplicate = $true
            break
          }
        }
      }
      if ($duplicate) {
        $errors.Add("Duplicate stable ID: $id")
      } else {
        $entityIds[$entityName][$id] = $true
      }
    }
  }

  $assumptionStatuses = @{}
  foreach ($item in @($entityItems['assumptions'])) {
    $id = [string]$item.id
    if ($id -notmatch '^[A-Za-z][A-Za-z0-9_-]{1,63}$') { continue }
    $assumptionStatuses[$id] = [string]$item.status
    if ($item.status -notin @('temporary','superseded')) { $errors.Add("Invalid assumption status: $id") }
    if ($item.status -eq 'superseded') {
      $confirmation = $item.PSObject.Properties['confirmation']
      $promoted = if ($confirmation -and $confirmation.Value.PSObject.Properties['promoted_fact_id']) { [string]$confirmation.Value.promoted_fact_id } else { '' }
      if ($promoted -notmatch '^[A-Za-z][A-Za-z0-9_-]{1,63}$' -or -not $entityIds['facts'].ContainsKey($promoted)) {
        $errors.Add("Superseded assumption must point to a fact: $id")
      }
    }
  }

  $issueSeverities = @('阻断','严重','一般','优化')
  $issueStatuses = @('仅诊断，禁止实施','待导演确认','导演已确认，可实施','已由下游处理，待复核','已复核关闭')
  foreach ($item in @($entityItems['issues'])) {
    if ([string]$item.severity -notin $issueSeverities) { $errors.Add("Invalid issue severity: $($item.id)") }
    if ([string]$item.status -notin $issueStatuses) { $errors.Add("Invalid issue status: $($item.id)") }
  }
  foreach ($item in @($entityItems['facts'])) {
    $promotedProperty = $item.PSObject.Properties['promoted_from_assumption_id']
    if ($promotedProperty -and -not [string]::IsNullOrWhiteSpace([string]$promotedProperty.Value)) {
      $promoted = [string]$promotedProperty.Value
      if (-not $entityIds['assumptions'].ContainsKey($promoted)) { $errors.Add("Fact points to unknown assumption: $($item.id)") }
    }
  }

  foreach ($scene in @($entityItems['scenes'])) {
    foreach ($field in @('facts','issues','assumptions')) {
      $property = $scene.PSObject.Properties[$field]
      if (-not $property) { continue }
      foreach ($id in @($property.Value)) {
        if (-not $entityIds[$field].ContainsKey([string]$id)) { $errors.Add("Scene $($scene.scene_id) references unknown $field ID: $id") }
      }
    }
  }

  $routeProperty = $root.PSObject.Properties['routes']
  $routeNames = @('short-drama-story-writing','short-drama-assets','short-drama-prompts','short-drama-image-design')
  if ($routeProperty) {
    foreach ($routeName in $routeNames) {
      $route = $routeProperty.Value.PSObject.Properties[$routeName]
      if (-not $route) { $errors.Add("Missing route: $routeName"); continue }
      foreach ($field in @('fact_ids','issue_ids','assumption_ids_candidate_only','confirmed_action_ids')) {
        $fieldProperty = $route.Value.PSObject.Properties[$field]
        if (-not $fieldProperty -or $fieldProperty.Value -is [string] -or $fieldProperty.Value -isnot [System.Collections.IEnumerable]) {
          $errors.Add("Route $routeName.$field must be an array")
          continue
        }
        $entityName = switch ($field) {
          'fact_ids' { 'facts' }
          'issue_ids' { 'issues' }
          'assumption_ids_candidate_only' { 'assumptions' }
          'confirmed_action_ids' { 'confirmed_actions' }
        }
        foreach ($id in @($fieldProperty.Value)) {
          $idText = [string]$id
          if (-not $entityIds[$entityName].ContainsKey($idText)) { $errors.Add("Route $routeName.$field references unknown ID: $idText") }
          if ($field -eq 'assumption_ids_candidate_only' -and $assumptionStatuses.ContainsKey($idText) -and $assumptionStatuses[$idText] -ne 'temporary') {
            $errors.Add("Route $routeName contains non-temporary assumption: $idText")
          }
          if ($field -in @('fact_ids','confirmed_action_ids') -and $assumptionStatuses.ContainsKey($idText)) {
            $errors.Add("Temporary assumption leaked into $routeName.${field}: $idText")
          }
        }
      }
    }
  }
  return $errors.ToArray()
}

$directorSkill = 'short-drama-director\SKILL.md'
$analysisSkill = 'short-drama-script-analysis\SKILL.md'
$storySkill = 'short-drama-story-writing\SKILL.md'
$analysisReview = 'short-drama-script-analysis\references\quality\analysis-review.md'
$analysisWorkflow = 'short-drama-script-analysis\references\analysis-workflow.md'
$analysisHandoff = 'short-drama-script-analysis\references\downstream-handoff.md'
$analysisCommercial = 'short-drama-script-analysis\references\commercial-observation.md'
$storyReview = 'short-drama-story-writing\references\quality\story-review.md'
$promptSkill = 'short-drama-prompts\SKILL.md'
$template = 'short-drama-prompts\references\templates\director-compact.md'
$output = 'short-drama-prompts\references\modules\output-format.md'
$assets = 'short-drama-prompts\references\modules\assets-references.md'
$audio = 'short-drama-prompts\references\modules\audio-timeline.md'
$performance = 'short-drama-prompts\references\modules\performance.md'
$shots = 'short-drama-prompts\references\modules\shot-continuity.md'
$timing = 'short-drama-prompts\references\modules\timing-segmentation.md'
$checklist = 'short-drama-prompts\references\quality\delivery-checklist.md'
$directing = 'short-drama-prompts\references\libraries\directing-decisions.md'
$recovery = 'short-drama-prompts\references\quality\generation-recovery.md'
$assetSkill = 'short-drama-assets\SKILL.md'
$imageSkill = 'short-drama-image-design\SKILL.md'
$imageWorkflow = 'short-drama-image-design\references\workflow.md'
$imageComposition = 'short-drama-image-design\references\composition.md'
$imageIdentity = 'short-drama-image-design\references\identity-reference.md'
$imageSpatial = 'short-drama-image-design\references\spatial-topology.md'
$imageSeries = 'short-drama-image-design\references\series-visual-language.md'
$imageChecklist = 'short-drama-image-design\references\quality\image-delivery-checklist.md'
$imageRecovery = 'short-drama-image-design\references\quality\image-generation-recovery.md'
$assetReview = 'short-drama-assets\references\quality\asset-review.md'
$videoExecution = 'short-drama-director\references\video-site-execution.md'
$tweetWorkflow = 'short-drama-director\references\tweet-storyization-workflow.md'
$narrativePrinciples = 'short-drama-director\references\narrative-directing-principles.md'
$analysisSchema = 'short-drama-script-analysis\references\downstream-handoff.schema.json'
$handoffValidFixture = 'short-drama-script-analysis\references\fixtures\handoff-valid.json'
$handoffInvalidFixture = 'short-drama-script-analysis\references\fixtures\handoff-invalid-route.json'

Assert-Contains $directorSkill '00-当前状态.md'
Assert-Contains $directorSkill '执行清单'
Assert-Contains $directorSkill '相对链接只是路由入口，不等于已经完成调用'
Assert-Contains $directorSkill '“短剧项目执行”还是“通用技能维护”'
Assert-Contains $directorSkill '技能更新必须在源仓库完成'
Assert-Contains $directorSkill '候选稿 → 审核 → 缺陷修正 → 全量回归复审 → 审核通过'
Assert-Contains $directorSkill '只有审核通过的交付才能写入 `00-当前状态.md`'
Assert-Contains $directorSkill '审核通过的故事稿须附故事动力传递摘要'
Assert-Contains $directorSkill '导演叙事判断总纲'
Assert-Contains $directorSkill '导演叙事桥接卡'
Assert-Contains $directorSkill 'Codex 自动创建最小状态入口'
Assert-Contains $directorSkill '文件大小和 SHA-256'
Assert-Contains $directorSkill '字段缺失本身判为文件失效'
Assert-Contains $directorSkill '不得在两个恢复模块之间循环转交'
foreach ($standaloneSkill in @($analysisSkill, $storySkill, $assetSkill)) {
  Assert-Contains $standaloneSkill '先定位项目 `00-当前状态.md`'
  Assert-Contains $standaloneSkill '不按文件名或修改时间猜测'
  Assert-Contains $standaloneSkill '由 `short-drama-director` 唯一维护'
}
Assert-Contains $analysisSkill 'references/quality/analysis-review.md'
Assert-Contains $analysisSkill 'references/analysis-workflow.md'
Assert-Contains $analysisSkill 'references/downstream-handoff.md'
Assert-Contains $analysisSkill 'references/commercial-observation.md'
Assert-Contains $storySkill 'references/quality/story-review.md'
Assert-Contains $analysisReview '不得用总分或平均分抵消失败'
Assert-Contains $analysisReview '重新执行全部十道审核门'
Assert-Contains $analysisWorkflow '## 临时假设升级'
Assert-Contains $analysisWorkflow 'promoted_from_assumption_id'
Assert-Contains $analysisHandoff '本文件只消费已审核通过的升级结果'
Assert-Contains $analysisSkill '导演叙事判断总纲'
Assert-Contains $analysisWorkflow '事件触发 → 冲突显形 → 反应波动 → 空间张力'
Assert-Contains $analysisWorkflow '受约束推定'
Assert-Contains $analysisWorkflow '编剧室逐场拆解.txt'
Assert-Contains $analysisHandoff 'assumption_ids_candidate_only'
Assert-Contains $analysisHandoff '不得进入正式资产卡'
Assert-Contains $analysisHandoff '不得进入正式图片提示词'
Assert-Contains $analysisCommercial '不属于剧本分析交接工具'
Assert-Contains $storyReview '新增内容追踪'
Assert-Contains $storyReview '重新执行全量复审'
Assert-Contains $storySkill '起始状态 → 可见或可听触发 → 主导情绪'
Assert-Contains $storySkill '少而强，但能留尽量留'
Assert-Contains $storySkill '故事动力传递摘要'
Assert-Contains $storySkill '事件触发冲突'
Assert-Contains $storySkill '导演叙事判断总纲'
Assert-Contains $storySkill '事件触发 → 冲突对象／阻碍 → 人物目标 → 当前策略 → 策略变化'
Assert-Contains $storySkill '处境 → 尝试 → 阻碍 → 改变策略 → 局部结果'
Assert-Contains $storyReview '不设固定轮次'
Assert-Contains $storyReview '详细报告单独保存并绑定候选故事稿版本'
Assert-Contains $storyReview '重要场景没有状态变化'
Assert-Contains $storyReview '高潮只有强烈表达而无决定性结果'
Assert-Contains $promptSkill '递归补齐“必需依赖”'
Assert-Contains $promptSkill '消费已审核的导演叙事桥接卡'
Assert-Contains $promptSkill '细节功能'
Assert-Contains $template '【第<集数>集统一词头·严格锁定】'
Assert-Contains $template '人物初始位置'
Assert-Contains $template '道具初始位置'
Assert-NotContains $template '场景流程：'
Assert-NotContains $template '用一个连续段落整合人物姓名'
Assert-NotContains $template '本段执行约束：'
Assert-NotContains $template '【通用负向】'
Assert-NotContains $template '【本段针对性负向】'
Assert-Contains $template '只填写当前段实际需要的人物、道具和场景'
Assert-Contains $output '【第<集数>集统一词头·严格锁定】'
Assert-Contains $assets '未绑定参考保留统一词头中的'
Assert-Contains $assets '@image<编号>'
Assert-Contains $assets '@音频<编号>'
Assert-Contains $audio '全片无背景音乐'
Assert-Contains $shots '画面全部使用硬切'
Assert-Contains $shots '镜头选择以画面表现力为第一优先级'
Assert-Contains $shots '下一镜从<继承的主体／动作／视线／方向／构图重心／声音锚点>承接'
Assert-Contains $template '下一镜从<主体、动作阶段、视线、方向、构图重心或声音锚点>承接'
Assert-Contains $template '══════════ 可直接提交的视频提示词 ══════════'
Assert-Contains $template '══════════ 制作参考与审核 ══════════'
Assert-Contains $template '自动修复记录'
Assert-Contains 'short-drama-prompts\references\libraries\camera.md' 'shot-scale-atmosphere.md'
Assert-Contains 'short-drama-prompts\references\libraries\shot-scale-atmosphere.md' '景别跳级与情绪量级'
Assert-Contains 'short-drama-prompts\references\libraries\shot-scale-atmosphere.md' '全场景高级景别切换'
Assert-Contains 'short-drama-prompts\references\libraries\shot-scale-atmosphere.md' '标志性技法族'
Assert-Contains 'short-drama-prompts\references\libraries\shot-scale-atmosphere.md' '氛围感进阶技法'
Assert-Contains 'short-drama-prompts\references\libraries\axis-line.md' '三类核心轴线'
Assert-Contains 'short-drama-prompts\references\libraries\axis-line.md' '合法越轴的工业级方法'
Assert-Contains 'short-drama-prompts\references\libraries\axis-line.md' '主动越轴的叙事技法'
Assert-Contains 'short-drama-prompts\references\libraries\axis-line.md' '越轴红线与创作分寸'
Assert-Contains $audio '核心声音焦点可随景别改变'
Assert-Contains $audio '对白替换位'
Assert-Contains $audio '角色对白必须在下游按固定原句'
Assert-NotContains $shots '稳定性后置评估'
Assert-NotContains $timing '模型承载量'
Assert-Contains $timing '默认Seedance／即梦为4–30秒，其他工具使用导演提供的明确边界'
Assert-Contains $timing '每个生成段最多9个镜头'
Assert-Contains $timing '同一段连续对白必须完整放在同一个生成段内'
Assert-Contains $checklist '执行与依据清单'
Assert-Contains $checklist '<实际状态>'
Assert-Contains $checklist '五层审核门'
Assert-Contains $checklist '原文覆盖矩阵'
Assert-Contains $checklist '连续性状态账本'
Assert-Contains $checklist '缺陷账本'
Assert-Contains $checklist '重新执行G0至G3全部检查'
Assert-Contains $performance '当前故事稿存在故事动力传递摘要时'
Assert-Contains $performance '重要对白先确认人物此刻执行的沟通行动'
Assert-Contains $checklist '故事动力传递摘要继承'
Assert-Contains $performance '人物对白期间的倾听者无声反应可由该句对白直接承载'
Assert-Contains $performance '旁白音频中对该原句的朗读不改变表演主体'
Assert-Contains $checklist '静默改变场景目标／阻碍'
Assert-Contains $promptSkill '普通单主体或已有明确镜头方案时不为保险加载'
Assert-Contains $promptSkill '它不得参与首次选镜或预先准备保守替代方案'
Assert-Contains $directing '注意力起点 → 可见或可听触发'
Assert-Contains $directing '启动理由和停止理由同等重要'
Assert-Contains $directing '提前引导、同步跟随或主体先动后短暂迟滞追随'
Assert-Contains $directing '连续反打若只交换肩位'
Assert-Contains $directing '近景与特写的戏剧强度'
Assert-Contains $directing '高潮前保留可收紧的景别距离'
Assert-Contains $directing '不因模型风险预先降级'
Assert-Contains $recovery '只在已有镜头实际生成失败'
Assert-Contains $recovery '每轮只改变一个主要变量'
Assert-Contains $recovery '不参与首次选镜'
Assert-Contains $recovery '最后有效帧续段修复'
Assert-Contains $recovery '<集数或片段>-<最后有效帧时间点>-定点修复提示词.txt'
Assert-Contains $recovery '不设固定轮次'
Assert-NotContains $directing '高稳定性'
Assert-NotContains $directing '中稳定性'
Assert-NotContains $directing '低稳定性'
Assert-NotContains $recovery '高稳定性：'
Assert-NotContains $recovery '中稳定性：'
Assert-NotContains $recovery '低稳定性：'
Assert-Contains 'short-drama-prompts\references\maintenance\rule-index.md' 'libraries/directing-decisions.md'
Assert-Contains 'short-drama-prompts\references\maintenance\rule-index.md' 'quality/generation-recovery.md'
foreach ($firstPassOwner in @($template, $output, $shots, $timing, 'short-drama-prompts\references\libraries\camera.md', $directing)) {
  Assert-NotContains $firstPassOwner 'generation-recovery.md'
}
Assert-Contains $checklist '39. 导演决策'
Assert-Contains $checklist '40. 生成失败修复'
Assert-Contains $shots '同一主体、相近景别、相近姿态或同一动作阶段'
Assert-Contains $shots '最后才单纯增加角度差'
Assert-Contains $shots '“连续拍同一张脸”'
Assert-Contains $shots '相邻镜头、当前场景和整集三层审核'
Assert-Contains $shots '持续迭代至全部通过'
Assert-Contains 'short-drama-prompts\references\libraries\camera.md' '约30度的机位差'
$checkText = Get-Content -LiteralPath (Join-Path $SkillsRoot $checklist) -Raw -Encoding utf8
if ($checkText -match '(?m)^\d+\..*：通过\s*$') { throw 'Delivery checklist must not prefill result rows as passed.' }
Assert-Contains $directorSkill 'short-drama-image-design'
Assert-Contains $directorSkill 'tweet-storyization-workflow.md'
Assert-Contains $tweetWorkflow 'EP1'
Assert-Contains $tweetWorkflow 'Q1–Q42'
Assert-Contains $tweetWorkflow '再议'
Assert-Contains $tweetWorkflow '默认只读取推文正文'
Assert-Contains $tweetWorkflow '标黄内容是可选旁白'
Assert-Contains $tweetWorkflow '不向已经制作完成的旁白音频新增朗读'
Assert-Contains $tweetWorkflow '旁白音频中如果已经朗读了对白'
Assert-Contains $tweetWorkflow '一个场景可以跨越多个 EP'
Assert-Contains $tweetWorkflow '现实动作不足以承载重要心理／认知转折'
Assert-Contains $tweetWorkflow '画面先行'
Assert-Contains $tweetWorkflow '原文映射'
Assert-Contains $imageSkill '00-当前状态.md'
Assert-Contains $imageSkill '身份参考、造型参考、场景参考、构图／风格参考或编辑目标'
Assert-Contains $imageSkill '它不得参与首次构图或预先生成保守替代方案'
Assert-Contains $imageWorkflow '待绑定模板'
Assert-Contains $imageWorkflow '文字生成模式'
Assert-Contains $imageWorkflow '正式绑定模式'
Assert-Contains $imageWorkflow '只有导演明确确认后'
Assert-Contains $imageComposition '动作正在发生的瞬间'
Assert-Contains $imageComposition '未完成动作'
Assert-Contains $imageComposition '标题安全区'
Assert-Contains $imageComposition '象征元素'
Assert-Contains $imageIdentity '原始身份权威参考'
Assert-Contains $imageIdentity '已漂移成图不得成为下一轮唯一身份依据'
Assert-Contains $imageSpatial '区域与通道'
Assert-Contains $imageSpatial '遮挡顺序'
Assert-Contains $imageSpatial '起点、路径、终点'
Assert-Contains $imageSeries '共同语法'
Assert-Contains $imageSeries '每张独立生成和验收'
Assert-Contains $imageChecklist '执行与依据清单'
Assert-Contains $imageChecklist '待绑定模板'
Assert-Contains $imageChecklist '候选，未升级为资产'
Assert-Contains $imageRecovery '已有图片出现可观察缺陷'
Assert-Contains $imageRecovery '一轮只修改一个主要变量'
Assert-Contains $imageRecovery '不参与首次构图'
Assert-Contains $assetSkill '复杂场景空间参考包'
Assert-Contains $assetSkill '身体拓扑锁'
Assert-Contains $assetSkill '主体结构｜固定肢体及数量｜连接来源'
Assert-Contains $assets 'AST-TOPO 身体拓扑与时期状态'
Assert-Contains 'short-drama-prompts\references\modules\source-context.md' 'SRC-05 抽象信息、重复与结果封口'
Assert-Contains 'short-drama-prompts\references\modules\source-context.md' '最后一个已确认动作完成'
Assert-Contains 'short-drama-prompts\references\modules\source-context.md' '推文项目默认只读取正文'
Assert-Contains 'short-drama-prompts\references\modules\source-context.md' '标黄段是可选旁白'
Assert-Contains 'short-drama-prompts\references\modules\source-context.md' '受控画面先行与滞后'
Assert-Contains $shots '来源位置 → 接近路径 → 首次接触'
Assert-Contains $timing '故事画面和首次镜头构思阶段不预设平均镜长或统一单镜硬上限'
Assert-Contains $timing '视频提示词与剪辑执行阶段，以正式旁白／对白音频的实测总时长为外边界'
Assert-Contains $timing '5–6秒高潮镜头是每集最多1处的例外'
Assert-Contains $timing '不得让同一主体以同一景别、同一构图和同一观察关系跨越多个独立视觉节点'
Assert-NotContains $timing '4秒是自动复核触发线'
Assert-Contains $timing 'TIM-VISUAL 镜长闭环与受控视觉余量'
Assert-Contains $timing '音频时长（旁白／对白的实际时间）、成片镜长'
Assert-Contains $timing '最短完整时间 → 停留价值 → 最早有效切点'
Assert-Contains $timing '约0–0.5秒'
Assert-Contains $timing '整段有效音频结束后不得无依据追加静默、空镜或环境画面'
Assert-Contains $timing '视觉余量复核必须同时确认'
Assert-Contains $output '正式视频提示词与剪辑执行阶段的最终镜长'
Assert-Contains $output '普通镜头4秒上限'
Assert-Contains $directing '0级静态观察'
Assert-Contains $directing '观看目标（观众此刻必须先读懂的可见变化）'
Assert-Contains $directing '导演叙事判断总纲'
Assert-Contains $directing '只有当做动作的人与承受情绪、掌握信息或改变关系的人不是同一人时'
Assert-Contains $shots '长旁白或长对白先按语义、动作、情绪和信息转折划分视觉节点'
Assert-Contains $shots '不得让同一主体以同一景别、同一构图和同一观察关系跨越多个独立视觉节点'
Assert-Contains $template '观看目标：<观众此刻必须先读懂的可见变化>'
Assert-Contains $template '导演叙事桥接：事件触发：'
Assert-Contains 'short-drama-prompts\references\modules\timing-segmentation.md' 'TIM-LONG 长旁白与长对白覆盖'
Assert-Contains $timing 'TIM-MONT 蒙太奇生成与剪辑'
Assert-Contains $timing '蓝图审核、单条素材审核和粗剪整体审核'
Assert-Contains $performance '沟通行动脊柱'
Assert-Contains $performance '锚点镜头 → 变化镜头'
Assert-Contains $performance '对白声音可连续跨硬切，画面必须持续提供新的观察任务'
Assert-Contains $performance '对白开始前或结束后可保留少量视觉提前／滞后'
Assert-Contains $template '镜长依据：<完成的主导视觉变化与最早有效切点'
Assert-Contains $template '时间关系：<无／视觉提前／视觉滞后／跨语义节点>'
Assert-Contains $template '视觉余量：<无／约X.X秒'
Assert-Contains $checklist '事件触发／冲突显形／反应波动'
Assert-Contains $checklist '导演叙事桥接卡继承'
Assert-Contains $checklist '细节功能'
Assert-Contains $narrativePrinciples '事件触发冲突'
Assert-Contains $narrativePrinciples '导演叙事桥接卡'
Assert-Contains $narrativePrinciples '但不能用留白掩盖事实缺失'
Assert-Contains $checklist '警告分为执行性与授权性'
Assert-Contains $checklist '故事段直接等同生成段'
Assert-Contains $directorSkill '导演持续授权提示词设计、自审和自动修复中的可逆执行选择'
Assert-Contains $recovery '外部生成不获得无限成本授权'
Assert-Contains $assetSkill '<场景名称>-空间参考包出图提示词.txt'
Assert-Contains $imageSpatial '空间参考包一致性'
Assert-Contains $imageSpatial '空间基准全景'
Assert-Contains $imageChecklist '13. 空间参考包的基准全景权威'
Assert-Contains $imageRecovery '最后有效帧定点改图'
Assert-Contains $imageRecovery '## 失败升级'
Assert-Contains $imageRecovery '不得把同一失败帧再次路由回来形成循环'
foreach ($imageFirstPassOwner in @($imageWorkflow, $imageComposition, $imageIdentity, $imageSpatial, $imageSeries)) {
  Assert-NotContains $imageFirstPassOwner 'image-generation-recovery.md'
}
$imageCheckText = Get-Content -LiteralPath (Join-Path $SkillsRoot $imageChecklist) -Raw -Encoding utf8
if ($imageCheckText -match '(?m)^\d+\..*：通过\s*$') { throw 'Image delivery checklist must not prefill result rows as passed.' }
Assert-Contains $analysisHandoff 'downstream-handoff.schema.json'
Assert-Contains $analysisHandoff 'handoff-invalid-route.json'
Assert-Contains $analysisHandoff '同一索引内不得重复'
Assert-Contains $assetSkill 'asset-review.md'
Assert-Contains $assetReview '七道审核门'
Assert-Contains $assetReview '未确认资产不得进入正式提示词'
Assert-Contains $videoExecution '代表帧'
Assert-Contains $videoExecution '口型与声音归属'
Assert-Contains $videoExecution '未完成的动作落幅'
Assert-Contains $videoExecution '硬切或节奏缺陷'
Assert-Contains $videoExecution '结果验收通过'
try {
  Get-Content -LiteralPath (Join-Path $SkillsRoot $analysisSchema) -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100 -ErrorAction Stop | Out-Null
} catch {
  throw "Handoff schema is not valid JSON: $($_.Exception.Message)"
}
$validHandoffErrors = @(Get-HandoffValidationErrors $handoffValidFixture)
if ($validHandoffErrors.Count -gt 0) { throw "Valid handoff fixture failed: $($validHandoffErrors -join ' | ')" }
$invalidHandoffErrors = @(Get-HandoffValidationErrors $handoffInvalidFixture)
if ($invalidHandoffErrors.Count -eq 0) { throw 'Invalid handoff fixture unexpectedly passed semantic validation.' }
$windowsAbsolutePathPattern = '(?i)\b[A-Z]:[\\/](?:[^\\/\s<>:"''|?*]+[\\/])*[^\\/\s<>:"''|?*]+'
$pathSeparator = [char]92
$uncAbsolutePathPattern = "(?i)${pathSeparator}${pathSeparator}[^\\/\s<>:|?*]+[\\/][^\r\n\s<>:|?*]+"
$unixAbsolutePathPattern = '(?i)(?<![\w:])/(?:Users|home|opt|srv|var|tmp|mnt|workspace|project|etc|usr|root|private|data|app|work)(?:/[^/\s<>:"''|?]+)+'
$privacyPattern = "(?:$windowsAbsolutePathPattern|$uncAbsolutePathPattern|$unixAbsolutePathPattern)"
$privacySamples = @(
  ('D' + ':' + $pathSeparator + 'client' + $pathSeparator + 'project' + $pathSeparator + 'script.md'),
  ($pathSeparator + $pathSeparator + 'server' + $pathSeparator + 'share' + $pathSeparator + 'project.md'),
  ('/' + 'opt' + '/project/script.md')
)
foreach ($sample in $privacySamples) {
  if ($sample -notmatch $privacyPattern) { throw "Absolute path privacy regression: $sample" }
}
if ('skills/short-drama-director/SKILL.md' -match $privacyPattern) { throw 'Relative skill link was misclassified as an absolute path.' }

Write-Host "[validate] Skills, versions, links, dependency routing, and confirmed invariants passed: $SkillsRoot"
