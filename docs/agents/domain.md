# Domain Docs

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- `CONTEXT-MAP.md`, if present, and the context documents relevant to the task.
- Relevant ADRs under `docs/adr/`.

If these files do not exist, proceed silently. Domain-modeling skills create them lazily when terminology or architectural decisions are resolved.

## Layout

This is a single-context repository:

```
/
├── CONTEXT.md
├── docs/adr/
└── skills/
```

## Vocabulary

Use terminology defined in `CONTEXT.md`. Do not drift to synonyms the glossary explicitly avoids. If a needed concept is absent, reconsider whether it belongs to the project or record the gap for domain modeling.

## ADR conflicts

If proposed work contradicts an existing ADR, identify the conflict explicitly instead of silently overriding the decision.
