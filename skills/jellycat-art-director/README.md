# JellyCat Art Director Skill

Project-local Codex skill for visual production in `JackTzeng/JellyCat-Godot`.

## Scope

This folder is the machine-readable art-production authority for JellyCat visual work. It is inspired by the engineering pattern of reusable art-direction skills: a compact `SKILL.md`, focused references, preflight scripts, tests, and QA.

It does **not** copy another project's visual style. JellyCat keeps its own art direction.

## Structure

```text
skills/jellycat-art-director/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── art-bible.md
│   ├── jellycat-character-standard.md
│   ├── aquarium-environment.md
│   ├── animation-standard.md
│   ├── ui-visual-standard.md
│   ├── asset-production-spec.md
│   └── qa-checklist.md
├── scripts/
│   └── check_asset_prompt.py
└── tests/
    ├── character-idle.md
    ├── aquarium-background.md
    └── ui-asset.md
```

## Codex use

Open the repository in Codex and invoke:

`$jellycat-art-director`

Example:

`$jellycat-art-director prepare and generate a 6-frame transparent idle-floating animation for the base JellyCat.`

The skill should first create an Asset Specification, then generate / edit, then QA the result.
