# 4.3 规则归属索引

本文件同时用于运行期依赖闭包和规则维护定位，不复制规则正文。每次提示词任务先选择规则域，再递归加载其“必需依赖”；未来更新先找到唯一所有者，再修改最小模块。

| 规则域 | 唯一所有者 | 必需依赖 | 条件参考 | 主要检查项 |
|---|---|---|---|---|
| 原文、前后文、推文正文范围、EP／场景边界、旁白／对白分类、黄色可选段、逐镜映射、抽象信息、重复文本与结果封口 | `modules/source-context.md`；跨阶段约束见 `short-drama-director/references/tweet-storyization-workflow.md` | 无 | 无 | 1–3、19、24 |
| 导演叙事动力、事件—冲突—反应—空间张力判断、细节功能、事实／知情／揭示边界、演绎空间与观众空间、桥接卡字段 | `short-drama-director/references/narrative-directing-principles.md` | source-context、performance、shot | 故事化、导演执行手册、关键帧桥接、复杂镜头或长文本提示词任务读取 | 2–3、6、12、15–16、19、25、39 |
| 旁白音频保留片段、对白替换位、角色对白单独生成、对白避让、参考音频、模型声音 | `modules/audio-timeline.md`；跨阶段约束见 `short-drama-director/references/tweet-storyization-workflow.md` | source-context | 重新分段时读timing | 4、7–8、18、27–28 |
| 人物／场景／道具、参考职责、三视图、可读文字资产 | `modules/assets-references.md` | source-context | 声音资产读audio | 10–11、29–33、38 |
| 对白表演、故事动力传递、对白行动／潜台词、关系权力、情绪词、微动作、长对白、反应 | `modules/performance.md` | source-context、audio | 明显动作或跨镜时读shot | 6、12、23、25、39 |
| 摄影机、空间、连续结构动作链、背景运动层级、专业处置／武器射线、透视、受力动作、段间快照、硬切、视觉节点承载、三层序列审核与连续面部近景／特写判定 | `modules/shot-continuity.md` | source-context | 对白表演读performance；镜长读timing；选镜读camera | 9、13、15–16、22 |
| 故事画面阶段的视觉节点、音频／成片／生成素材／生成段四种时长、完整视觉变化、最短承载时间、最早有效切点、受控视觉提前／滞后与余量、最终执行阶段镜长标尺、长镜头自审、状态边界、蒙太奇蓝图／独立素材／粗剪、语言／动作／信息／画面表现力四层审查、按工具分段与核算 | `modules/timing-segmentation.md` | source-context | 正式音频读audio；动作可完成性读shot | 7、9、21 |
| 视觉媒介、项目风格、画幅、光影边界 | `modules/project-style.md` | 无 | 建立或核对光影时读lighting | 14、24、26 |
| 提示词／制作参考分区、交付层级、资产区、字段、省略、负向 | `modules/output-format.md` | 本次已加载的业务模块 | 正式单集读template；工具差异读adapter | 5、17、20、34–38 |
| 景别、角度、焦点与基础运镜选项 | `libraries/camera.md` | 无 | 由shot按需查询 | 15、22 |
| 第一镜追看任务、观看目标、动作／情绪主体标注、对白观察关系、近景／特写戏剧强度、注意力交接、分级运镜决策、相对运动与段界叙事落点 | `libraries/directing-decisions.md` | camera | 正式单集、首镜设计、复杂对白／调度／运镜或镜头语言诊断时读取 | 15、39 |
| 景别跳级、景运耦合、场景化景别、氛围、转场匹配与声画对位 | `libraries/shot-scale-atmosphere.md` | camera | 正式单集必读；相关窄任务按需读取 | 15–16、18、22 |
| 关系轴、运动轴、方向轴、180度法则与合法／主动越轴 | `libraries/axis-line.md` | camera、shot | 正式单集必读；涉及对话、动作、群像、方向或换侧时读取 | 13、15–16、22 |
| 光型、色彩、光线故障修正 | `libraries/lighting.md` | 无 | 由project-style按需查询 | 14 |
| 仪式阵列、等级映射、特效变化、递进对比 | `libraries/ritual-vfx.md` | source-context、shot | camera、lighting | 15 |
| Seedance／即梦工具特有字段 | `adapters/seedance.md` | output-format | assets | 5、10、20 |
| 导演偏好紧凑排版 | `templates/director-compact.md` | output-format | 本次已加载的业务模块 | 5、20、34–37 |
| 五层审核门、证据账本、交付状态与检查映射 | `quality/delivery-checklist.md` | 本次全部业务模块 | 相关条件库 | 1–40 |
| 已发生生成失败后的单变量修复、最后有效帧续段与停止条件 | `quality/generation-recovery.md` | 原方案实际使用的规则模块 | 仅有可观察失败或导演明确要求修复时读取；需改图时路由image-design恢复 | 40 |

## 更新协议

1. 项目事实只写当前本地项目，不进入本索引或技能。
2. 新规则先判断是否跨阶段；跨阶段更新 `short-drama-director/SKILL.md`，提示词内部规则更新上表唯一所有者。
3. 唯一所有者按“当前要裁决的字段或操作”确定：剧情事实归source-context，声音归audio，资产引用归assets，表演归performance，镜头执行与空间归shot，镜长与分段归timing，媒介与风格归project-style，交付结构归output-format；依赖模块提供输入，不取得被依赖字段的裁决权。适配器只能覆盖工具字段和硬边界，模板只能排版，检查表只能判定。
4. 同一决定被两个模块同时声明、或跨模块结论无法按字段拆开时，登记为规则架构冲突；运行期先服从导演当前明确指令和更高层跨阶段约束，停止采用互相矛盾的新规则，由维护任务确定唯一所有者、删除其他正文并更新依赖与检查映射后再恢复执行。
5. 模板只在字段或排版变化时更新；库只在可选方法变化时更新；检查表只在判定或可见检查项变化时更新。
6. 同一规则不得在多个文件重新表述。其他文件只链接所有者或填入模板占位。
7. 中心技能的核心约束属于防漏载安全摘要，不是第二规则源；详细语义由上表唯一所有者维护。修改涉及摘要的规则时同步核对中心文字，避免漂移。
8. 修改后核对中心路由、相对链接、相关检查项、仓库与安装副本；不得改变未获导演授权的核心功能。
9. 修改前后运行仓库 `scripts/validate.ps1`，并通过 `scripts/install.ps1` 复核安装副本。审计不变量、链接、版本或安装哈希失败时不得提交或上传。
10. 已被导演新结论替代的规则必须从现行模块移除；历史记录可以存档，但不得继续出现在当前模板或项目状态入口中。
