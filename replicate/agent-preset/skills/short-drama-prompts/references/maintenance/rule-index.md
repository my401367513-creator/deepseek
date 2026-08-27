# 3.0 规则归属索引

本文件只用于定位维护位置，不复制规则正文。未来更新先找到唯一所有者，再修改最小模块。

| 规则域 | 唯一所有者 | 必需依赖 | 条件参考 | 主要检查项 |
|---|---|---|---|---|
| 原文、前后文、旁白／对白分类、逐镜映射 | `modules/source-context.md` | 无 | 无 | 1–3、19 |
| 旁白音频、对白避让、参考音频、模型声音 | `modules/audio-timeline.md` | source-context | 重新分段时读timing | 4、7–8、18、27–28 |
| 人物／场景／道具、参考职责、三视图、可读文字资产 | `modules/assets-references.md` | source-context | 声音资产读audio | 10–11、29–33、38 |
| 对白表演、情绪词、微动作、长对白、反应 | `modules/performance.md` | source-context、audio | 明显动作或跨镜时读shot | 6、12、23、25 |
| 摄影机、空间、透视、受力动作、段间快照、硬切 | `modules/shot-continuity.md` | source-context | 对白表演读performance；镜长读timing；选镜读camera | 9、13、15–16、22 |
| 单镜时长、4–30秒分段、核算、长镜头审批 | `modules/timing-segmentation.md` | source-context | 正式音频读audio；动作可完成性读shot | 7、9、21 |
| 视觉媒介、项目风格、画幅、光影边界 | `modules/project-style.md` | 无 | 建立或核对光影时读lighting | 14、24、26 |
| 交付层级、资产区、字段、省略、负向 | `modules/output-format.md` | 本次已加载的业务模块 | 正式单集读template；工具差异读adapter | 5、17、20、34–38 |
| 景别、角度、焦点、运镜选项 | `libraries/camera.md` | 无 | 由shot按需查询 | 15、22 |
| 光型、色彩、光线故障修正 | `libraries/lighting.md` | 无 | 由project-style按需查询 | 14 |
| 仪式阵列、等级映射、特效变化、递进对比 | `libraries/ritual-vfx.md` | source-context、shot | camera、lighting | 15 |
| Seedance／即梦工具特有字段 | `adapters/seedance.md` | output-format | assets | 5、10、20 |
| 导演偏好紧凑排版 | `templates/director-compact.md` | output-format | 本次已加载的业务模块 | 5、20、34–37 |
| 交付状态与检查映射 | `quality/delivery-checklist.md` | 本次全部业务模块 | 相关条件库 | 1–38 |

## 更新协议

1. 项目事实只写当前本地项目，不进入本索引或技能。
2. 新规则先判断是否跨阶段；跨阶段才更新 `short-drama-director`，提示词内部规则更新上表唯一所有者。
3. 模板只在字段或排版变化时更新；库只在可选方法变化时更新；检查表只在判定或可见检查项变化时更新。
4. 同一规则不得在多个文件重新表述。其他文件只链接所有者或填入模板占位。
5. 中心技能的核心约束属于防漏载安全摘要，不是第二规则源；详细语义由上表唯一所有者维护。修改涉及摘要的规则时同步核对中心文字，避免漂移。
6. 修改后核对中心路由、相对链接、相关检查项、仓库与安装副本；不得改变未获导演授权的核心功能。
