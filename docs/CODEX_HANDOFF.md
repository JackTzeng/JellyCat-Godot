# Codex Handoff

## Role

You are continuing the JellyCat / 水母喵 Godot 4 project.

This is not a redesign. Continue the existing architecture and stabilize the current v0.1.0 aquarium core prototype.

## Repository

```text
https://github.com/JackTzeng/JellyCat-Godot
```

## Local Working Directory

```text
C:\Users\user\Documents\遊戲製作\JellyCat
```

## Current Priority

Do not add new gameplay until v0.1.0 runtime-ready is certified.

Priority order:

1. Runtime Log cleanup / action debounce
2. No-op actions should not save
3. Failed actions should not log `Aquarium UI refreshed`
4. Stage 5 and SaveLoad final QA
5. Aquarium side-panel UI layout freeze
6. Main JellyCat motion patch
7. Art asset spec and integration
8. Windows export
9. Android APK preparation

## Hard Constraints

Do not:

- Add new JellyCat species during runtime cleanup
- Add true multi-pet save system
- Add breeding / resonance systems
- Add mini-games
- Add ads
- Add analytics
- Add login
- Add cloud service
- Change viewport unless explicitly requested
- Replace background during non-art tasks
- Rewrite the whole project
- Commit exported builds
- Commit signing keys

## Current Known Runtime Problems

Observed Runtime Log symptoms:

```text
ACTION Feed food clicked
ERROR Not enough item: food_basic
INFO Aquarium UI refreshed
```

This pattern should be fixed. Failed/no-op actions should not save or write `Aquarium UI refreshed`.

Repeated no-op/error logs should be throttled.

## v0.1.1 Motion Direction

Before adding many background JellyCats, make the current main JellyCat move:

- idle floating
- breathing / pulsing
- subtle rotation
- success reaction animations
- sick idle difference

## Notion Authority

Project Hub:

```text
https://app.notion.com/p/3d9f53bbd3b281228b16f4e99764ee76
```

Development Backlog:

```text
https://app.notion.com/p/2d5affc30bce434d9a2a4b86a3231807
```

Art Asset Register:

```text
https://app.notion.com/p/7dee00a7dad945f28e4ad8d9effe7a83
```
