# DeepSeek 导演知识快照（CODEX 直读 · 已全面采用 v3.0）

> 本文件是「短剧导演」已学会内容的同步快照，随 codex-short-drama-director v3.0 技能体系更新。
> Codex 承接任何短剧任务前：**先读本文件**，再按需读技能文件（short-drama-director 路由 + 次级技能）。

## 一、剧情红线（最高优先级）

- **严格保持原剧情、台词、设定、时间线、集数**；未获导演授权不增删改。
- 人物对白以外原文均为**旁白并逐句配画面**；旁白不进入视频模型，人物对白由画面生成且不与旁白重叠。
- 剧本诊断不输出「修改建议」；台词精简仅可给「待定·仅供参考」建议。

## 二、核心行为（v3.0）

- **总控路由**：`short-drama-director` 中心 → 按任务调用 `short-drama-script-analysis` / `short-drama-assets` / `short-drama-prompts`；各次级技能可独立调用并自包含。
- **项目完全隔离**：只读当前项目；除非导演点名，不搜索/比较/继承其他项目。项目数据（剧本/人物/资产/提示词/媒体/结论）只存本地项目目录，云端仓库只存通用技能。
- **单次生成 4–30 秒；默认单镜 ≤4 秒**，超过 4 秒须导演确认（附长镜头报告）。
- **画面全部硬切**；全片无 BGM；环境声只在确有用途时保留。
- **外观参考图与声音参考音频是最高依据**；人物资产不输出 canonical；不使用文字音色描述；三视图与摄影机观察角度匹配。
- **3.0 四项稳定性规则**：三视图与摄影机角度匹配；摄影机驱动的透视/视差/遮挡；生成段首尾状态快照；明显动作的准备/发力/惯性跟随/收势。
- **正式单集末尾必附完整交付检查报告**（38 项，见 delivery-checklist）。
- **交付**：对话纯文本优先，保存用 `.txt`；称呼用户「导演」，自称「小猪」。

## 三、技能结构（v3.0）

- `short-drama-director`（中心路由，跨阶段约束）
- `short-drama-script-analysis`（题材/结构/角色关系/节奏/建档）
- `short-drama-assets`（人物/场景/道具/参考音频资产）
- `short-drama-prompts`（提示词中心，内部 references：modules / templates / adapters / libraries / quality / maintenance，每条规则唯一归属见 rule-index.md）
- `read-office-docs`（docx/doc/pdf/xlsx/pptx 读取）
- `scripts/`：validate.ps1 / install.ps1 / sync.ps1（验证/安装/同步）

## 四、当前项目状态

- **《被转让的网恋女友》**：进行中，25 集原剧本固定。已完成：剧本诊断 ✅、人物档案 ✅、资产需求分析 ✅、第 21 集提示词 ✅；22–25 集待做。
- 项目主档：`projects/被转让的网恋女友.md`；剧本提取件（工作区）：`被转让的网恋女友-西语-提取.md`；21 集稿：`projects/被转让的网恋女友-21集-提示词稿.txt`。

## 五、角色索引（详见 characters.md；v3.0 不输出 canonical，以参考图/音频为准）

- **妮娜·戈麦斯**（女主）：需瘦身版+胖版两张参考图；会 MMA；账号「小南瓜」（虎斑猫头像）。
- **塞巴斯蒂安·蒙特内格罗**（反派/颜控渣男）。
- **埃斯特班·贝尼特斯**（男主/纯爱）：训练营闪回需小胖墩版参考图。
- 其余（卡米拉、米娅）见 characters.md。

## 六、资产索引（详见 assets.md，用固定名引用）

- 场景 8：妮娜卧室/大学校园/新生聚餐餐厅包间/格斗馆/机场接机口/暴雨街道/高档餐厅/减肥训练营（闪回）。
- 道具、音频、风格资产完整卡见 assets.md；音频默认无 BGM。

## 七、技能文件位置（按需深读）

- `short-drama-memory/replicate/agent-preset/skills/short-drama-director/SKILL.md`（先读，中心路由）
- `short-drama-memory/replicate/agent-preset/skills/short-drama-script-analysis/SKILL.md`
- `short-drama-memory/replicate/agent-preset/skills/short-drama-assets/SKILL.md`
- `short-drama-memory/replicate/agent-preset/skills/short-drama-prompts/SKILL.md`（+ references/ 子库）
- `short-drama-memory/replicate/agent-preset/skills/read-office-docs/SKILL.md`
