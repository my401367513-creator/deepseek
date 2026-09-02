# 下游交接工具

正式分析生成 `剧本分析交接说明.txt` 与 `剧本分析交接索引.json`；前者供人阅读，后者供技能消费。索引引用原文和报告位置，不复制完整剧本。JSON字段合同见 [downstream-handoff.schema.json](downstream-handoff.schema.json)；发布前同时执行可解析性、枚举、稳定ID、路由引用和临时假设隔离校验。

冲突按：导演最新确认 → 原文明示 → 前后文可唯一推出 → 当前有效分析结论 → 临时工作假设 → 分析判断。低级内容不得覆盖高级内容。临时假设升级的唯一流程由 `analysis-workflow.md` 维护；本文件只消费已审核通过的升级结果。

## JSON结构

```json
{
  "schema_version": "1.0",
  "source_script": {"path": "episode-01.md", "version": "sha256:example", "scope": "第1集", "evidence_locator": "原文第1段"},
  "analysis_status": "candidate",
  "global_model": {"causal_chain": [], "information_reveals": [], "emotion_curve": [], "relationship_changes": [], "timeline": [], "locations": [], "prop_states": []},
  "scenes": [{"scene_id": "scene-001", "source_range": "第1段", "dramatic_beats": [], "entry_state": {}, "exit_state": {}, "facts": ["fact-001"], "issues": ["issue-001"], "assumptions": ["assumption-001"]}],
  "facts": [{"id": "fact-001", "claim": "人物在场", "evidence_level": "原文明示", "source": "原文第1段", "status": "已复核关闭"}],
  "issues": [{"id": "issue-001", "severity": "一般", "status": "已复核关闭", "affected_ids": ["scene-001"], "allowed_direction": "保持原文", "forbidden_changes": []}],
  "assumptions": [{"id": "assumption-001", "claim": "待核实的空间连接", "evidence": ["原文第1段"], "rejected_alternatives": [], "affected_ids": ["scene-001"], "invalidation_conditions": ["出现相反证据"], "status": "temporary", "confirmation": {"record": "", "date": "", "scope": "", "promoted_fact_id": ""}}],
  "confirmed_actions": [],
  "routes": {
    "short-drama-story-writing": {"fact_ids": [], "issue_ids": [], "assumption_ids_candidate_only": [], "confirmed_action_ids": []},
    "short-drama-assets": {"fact_ids": [], "issue_ids": [], "assumption_ids_candidate_only": [], "confirmed_action_ids": []},
    "short-drama-prompts": {"fact_ids": [], "issue_ids": [], "assumption_ids_candidate_only": [], "confirmed_action_ids": []},
    "short-drama-image-design": {"fact_ids": [], "issue_ids": [], "assumption_ids_candidate_only": [], "confirmed_action_ids": []}
  }
}
```

所有元素使用稳定ID（字母开头，只允许字母、数字、`_`、`-`，同一索引内不得重复）。临时工作假设只能进入`assumption_ids_candidate_only`，不得混入`fact_ids`或`confirmed_action_ids`；路由中的每个ID必须存在于对应实体集合，`superseded`假设必须指向已建立的升级事实。正式JSON必须可解析，无注释、尾逗号或未解析占位。仓库验证脚本以 `references/fixtures/handoff-valid.json` 和 `references/fixtures/handoff-invalid-route.json` 作为通过／失败回归样例。

## 权限路由

- 故事技能读取剧情事实、因果链、情绪链、问题和确认处理；临时假设只生成候选，只有`导演已确认，可实施`能进入正式故事稿。
- 资产技能读取人物状态、时期造型、场景、道具、空间和确认状态；临时假设只建立候选资产规划，不得进入正式资产卡、参考绑定或确认状态。
- 提示词技能读取原文边界、知情状态、可见事件、表演节点、空间／道具状态和确认处理；临时假设不得进入正式提示词。
- 制图技能读取身份状态、场景时空、视觉基调、关键事件和构图事实；临时假设只生成候选方案，不得进入正式图片提示词、成品或权威绑定。

`商业与平台观察.txt`不进入索引、项目创作结论或下游路由。下游只读取`00-当前状态.md`明确指向且`analysis_status`为`approved`的索引；候选索引只用于审核。
