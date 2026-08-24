# 短剧导演 · 完整复刻教程（REPLICATE）

> 本文件是本仓库的**自我复刻套件**：`本文件 + replicate/ 目录` 就是完整的复制包。
> 新设备、或新的 Agent 实例，拿到本仓库后按本教程逐步执行，即可 1:1 复刻「短剧导演」：
> ① Agent 预设（人设 / 技能 / 记忆协议） ② 血蓝条插件（上下文 + DeepSeek 余额，应用启动自动装载） ③ 记忆库本体（就是本仓库）。
>
> 适用对象：具备文件读写、PowerShell 执行能力的 Agent。所有命令用 PowerShell 语法。

---

## 0. 前置检查

- [ ] 目标机器已安装 DSH 桌面版并能正常对话
- [ ] 已把本仓库克隆/放置到工作区：`git clone <仓库地址> short-drama-memory`（第 4 步详述）
- [ ] 目标机器有 git（Windows 建议 Git for Windows）；DSH 自带 node/pnpm（第 3 步使用，无需单独安装）

## 1. 定位 DSH 关键路径（每台机器不一样，先解析再动手）

```powershell
# DSH 用户数据根（桌面版）
$DSH_HOME = $env:DSH_HOME
if (-not $DSH_HOME) { $DSH_HOME = Join-Path $env:APPDATA "dsh-desktop\harness" }

# DSH 应用安装根（含 node_modules\@deepseek-ai\dsh）—— 桌面版安装目录下的 resources\app
$DSH_APP_ROOT = $env:DSH_APP_ROOT   # 可自行设为实际路径，如 "D:\...\resources\app"
```

- 预设根：`<DSH_HOME>\.agent-presets\`（**注意：桌面版只读 DSH_HOME 下这个目录，不是 `~\.dsh\.agent-presets`** —— 这是本机踩过的坑）
- profile 根：`<DSH_HOME>\profiles\web\`（插件包装载位置）
- 工作区：Agent 会话的工作目录（记忆库默认放这里）

## 2. 复刻 Agent 预设「短剧导演」

### 2.1 放置文件

把 `replicate\agent-preset\` 里的内容按原结构复制到预设根：

```
<DSH_HOME>\.agent-presets\short-drama\
├── agent.cordis.yml
├── preset.yml
└── skills\short-drama-production\SKILL.md
```

`agent.cordis.yml` 是完整组合：人设（六大能力 + Seedance 2.0 + 强记忆协议）、fs/shell/jobs/skill/goal/plan/compaction/delegation 等工具行、`skill-filesystem` 的 `customSkillDirs` 指向预设内 `skills/`。**不要改动行的 realm 结构**，直接整体复制。

### 2.2 校验挂载

方式 A（有 cordis 工具集时，推荐）：用临时动态插件注册探针工具，调用 `agentPresets.standingKeyFor('short-drama')`，返回 `mounted OK` 即通过。探针宿主代码：

```js
return {
  name: 'preset-probe',
  inject: ['agentPresets', 'tools'],
  apply(ctx) {
    harness.registerTool(ctx, harness.defineTool({
      name: 'preset_check',
      description: 'Mount-validate one preset by id.',
      parameters: { id: { type: 'string', required: true } },
      output: { schema: { type: 'string' }, render(_a, v) { return [{ type: 'text', text: v }] } },
      async execute(args) {
        try { await ctx.agentPresets.standingKeyFor(args.id); return 'mounted OK' }
        catch (error) { return error.message }
      },
    }))
  },
}
```

方式 B（无 cordis 工具时）：确认文件齐全（含 `skills\short-drama-production\SKILL.md`），并请用户在新建会话的 Agent 选择器里能看到「短剧导演」。

## 3. 复刻血蓝条插件（应用启动自动装载）

### 3.1 放置插件源码

把 `replicate\plugin\` 整体复制到工作区（或任意便于修改的位置），例如：

```
<工作区>\dsh-hpmp-meters\
├── package.json        # 声明 dsh.bundle + dsh.client
├── cordis.patch.yml    # 补丁：- id: hpmp-meters / name: dsh-hpmp-meters
└── lib\
    ├── index.js        # Host：注册同源路由 GET /hpmp/balance（凭证+curl 查余额）
    └── client.js       # Client：dock 血蓝条（__ModuleLoader__ 格式）
```

### 3.2 安装进 web profile（关键：这样每次启动自动装载）

先做一个 pnpm 垫片（桌面版自带 node/pnpm，批处理里**不要写含中文的绝对路径**，用环境变量）：

`<任意目录>\pnpm.cmd` 内容：
```bat
@echo off
"%DSH_APP_ROOT%\node_modules\node\bin\node.exe" "%DSH_APP_ROOT%\node_modules\pnpm\bin\pnpm.cjs" %*
```

然后执行（用 `link:` 安装，改源码后无需重装）：

```powershell
$env:DSH_HOME   = "<DSH_HOME>"
$env:DSH_APP_ROOT = "<DSH_APP_ROOT>"
$env:PATH = "<垫片目录>;" + $env:PATH
& "<DSH_APP_ROOT>\node_modules\node\bin\node.exe" `
  "<DSH_APP_ROOT>\node_modules\@deepseek-ai\dsh\lib\bin.js" `
  plugin --profile web add "link:<插件绝对路径>"
```

### 3.3 验证

```powershell
# 1) bundles 列表应含 dsh-hpmp-meters
Get-Content "<DSH_HOME>\profiles\web\package.json"

# 2) 组合树应含 hpmp-meters 行
& "<DSH_APP_ROOT>\node_modules\node\bin\node.exe" `
  "<DSH_APP_ROOT>\node_modules\@deepseek-ai\dsh\lib\bin.js" `
  --profile web --dump-config   # 输出中应有：- id: hpmp-meters / name: dsh-hpmp-meters
```

### 3.4 重启生效

**完全退出并重新打开 DSH 桌面应用**。之后每次启动，输入框下方自动出现：
- 🔴「上下文」血条：剩余上下文 token（数据来自宿主 `contextPressure` 投影，无需配置）
- 🔵「DeepSeek」蓝条：余额（数据来自 `/hpmp/balance` 路由；需要有效的 DeepSeek API Key）

蓝条无 Key 时显示「未配置 Key」；Key 无效时显示「Key 无效」——在 设置→模型 存入有效的 `sk-` Key（凭证 `DEEPSEEK_API_KEY`）后自动生效。

## 4. 恢复记忆库本体

本仓库即记忆库。在新设备工作区：

```powershell
git clone <仓库地址> short-drama-memory
```

- 记忆根解析（见技能 1.1）：环境变量 `SHORT_DRAMA_MEMORY` 优先（非空且存在），否则默认 `<工作区>\short-drama-memory\`
- 会话开始时读 `MEMORY.md`；按技能协议维护 `characters.md / assets.md / prompt-templates.md / lessons.md / projects\`
- 每次交付后同步：`.\short-drama-memory\sync-memory.ps1`（或 Agent 自动 pull/push）

## 5. 完成后核对清单

- [ ] `<DSH_HOME>\.agent-presets\short-drama\` 四个文件齐全，preset_check → `mounted OK`
- [ ] `<DSH_HOME>\profiles\web\package.json` 的 bundles 含 `dsh-hpmp-meters`
- [ ] `--dump-config` 输出含 `- id: hpmp-meters`
- [ ] 重启应用后输入框下有血条/蓝条
- [ ] 记忆库在本机工作区，`git status` 干净、可 pull/push
- [ ] 配置有效 Key 后蓝条显示余额（¥/$）

## 6. 常见排错

| 症状 | 原因 / 处理 |
|---|---|
| 选择器里没有「短剧导演」 | 预设放错根：必须放 `<DSH_HOME>\.agent-presets\`，桌面版不读 `~\.dsh` |
| 预设挂载报 realm/service 错误 | 复制时改动了行结构；用仓库里的原文件整体覆盖 |
| 重启后没有血蓝条 | 检查 bundles 列表；确认 `dsh plugin` 执行成功；完全退出应用再启动 |
| `dsh plugin` 报 pnpm 找不到 | 垫片目录没加进 PATH，或 `DSH_APP_ROOT` 未设置 |
| pnpm 报 EPERM 重命名 | 桌面版自带重试机制，重试一次即可 |
| 蓝条显示 Key 无效 | 凭证过期/错误，去 设置→模型 更新 `DEEPSEEK_API_KEY` |

## 7. 维护约定（重要）

- 每次修改预设或插件后，**把新文件同步回本仓库的 `replicate\` 目录并提交推送**，保证复制包永远是最新状态。
- 记忆内容只记录「事实 + 用户确认的偏好」，不写设备相关的绝对路径（本教程第 7 节除外）。

---

## 附：第一台设备的实际路径（仅参考，勿照抄到其他机器）

- DSH_HOME：`C:\Users\JZ\AppData\Roaming\dsh-desktop\harness`
- App Root：`D:\新建文件夹\DSH Desktop\resources\app`
- 工作区：`C:\Users\JZ\Desktop\deepseek`
- 插件源码：`C:\Users\JZ\Desktop\deepseek\dsh-hpmp-meters`
- pnpm 垫片：`C:\Users\JZ\Desktop\deepseek\.pnpm-shim\pnpm.cmd`
