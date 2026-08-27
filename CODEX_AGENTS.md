# Repository rules

This repository stores reusable short-drama Codex skills only. Detailed creative behavior belongs in the relevant `SKILL.md` or its references; do not duplicate it here or in `README.md`.

## Scope and privacy

- Treat each drama project as isolated. Read only the active project's source and local project directory unless the director explicitly names another project as a reference.
- Keep scripts, characters, assets, prompts, conclusions, feedback, and media inside that local project directory. Never commit project data, credentials, tokens, private documents, generated media, or machine-specific absolute paths.
- Re-read the invoked skill and the active project's current memory and deliverables at the start of every relevant task, after context compaction, after a long interruption, or when the active project changes.
- Deliver plain text in chat by default; save `.txt` only when useful. Use another format only when explicitly requested.
- In skill-related work, address the user as “导演” and refer to yourself as “小猪”.

## Skill evolution

- Preserve user intent and do not invent project facts or preferences.
- When a correction could become reusable behavior, explain the proposed rule and ask before editing a skill. A direct request to update counts as confirmation.
- When the director explicitly authorizes automatic handling of a clearly defined class of equivalent follow-ups, apply later equivalent cases without asking again. Keep that standing authorization narrowly scoped and request confirmation for materially different rules.
- Only confirmed reusable rules enter this repository. Local project facts never do.

## 3.0 modular architecture

- `short-drama-director` owns only cross-stage routing, isolation, privacy, handoff, and update authorization.
- The analysis, assets, and prompts skills remain independently usable secondary skills. Do not move their domain rules into the center skill.
- Within `short-drama-prompts`, every reusable rule has one owner listed in `references/maintenance/rule-index.md`. Update the smallest owning module and its affected check mapping.
- Templates define fields and layout, libraries offer optional methods, adapters contain tool-specific differences, and quality files define validation. Do not restate rule bodies in them.
- Preserve 2.0 behavior unless the director explicitly confirms a functional change. Structural cleanup alone never authorizes a behavior change.

## Validation and sync

- After skill changes, run `scripts/validate.ps1`, install through `scripts/install.ps1`, validate the installed copy, then use `scripts/sync.ps1 push` when a remote is configured.
- Pull fast-forward only. Never force-push, rewrite remote history, or silently resolve concurrent conflicts.
- A failed push must leave the local commit intact and be reported. Do not create empty commits.
