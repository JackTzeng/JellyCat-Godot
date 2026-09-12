# JellyCat Art Director Skill

The project now keeps a Codex-native art-production skill at:

`skills/jellycat-art-director/`

## Role

This skill is the project's visual-production framework for:

- JellyCat character assets
- aquarium / tank environments
- sprite animation art
- UI and item art
- image-generation prompts
- visual QA
- Godot asset handoff

It intentionally separates art production from gameplay logic.

## Authority

- `skills/jellycat-art-director/SKILL.md`: workflow and invocation authority
- `skills/jellycat-art-director/references/`: visual and production standards
- `skills/jellycat-art-director/scripts/`: machine-checkable preflight
- `skills/jellycat-art-director/tests/`: expected behavior examples

Generated images are candidates by default and do not automatically replace approved project assets.

## Design principle

The structure borrows the reusable Skill pattern (`SKILL.md + references + scripts + tests + QA`) while defining an independent JellyCat visual language. No external project's art style is inherited.
