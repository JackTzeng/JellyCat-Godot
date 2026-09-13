# JellyCat / 水母喵

A cozy 2D aquarium virtual pet game built with Godot 4.

## Current Version

`v0.1.0 Aquarium Core Prototype`

This repository is the GitHub authority for the JellyCat / 水母喵 Godot project.

## Current Gameplay Scope

The current prototype focuses on one main JellyCat in an aquarium:

- Boot / Title / Egg Select / Hatch / Aquarium flow
- Hatch a JellyCat from an egg
- Feed / Cookie / Touch / Clean / Medicine interactions
- Five evolution stages
- Bubble Coin pickup and auto-collect
- Shop for basic items
- Daily free food safeguard
- Local Save / Load
- Runtime Log for development validation

## Development Environment

- Engine: Godot 4.x
- Language: GDScript
- Save model: local JSON save
- Primary target: Android APK
- Workflow: text/code edits, headless validation, CLI export, and physical-device testing
- Godot GUI/editor is not part of the required development or release workflow

## Development Policy

- No ads
- No analytics
- No login
- No cloud service in early versions
- No payment integration
- Local-first
- Cozy, low-pressure gameplay

## Recommended Local Project Path

```text
C:\Users\user\Documents\遊戲製作\JellyCat
```

## How to Validate

Run the automated acceptance scene with the Godot 4.2.1 console executable:

```powershell
& "C:\path\to\Godot_v4.2.1-stable_win64_console.exe" --headless --path . res://tools/runtime_acceptance_check.tscn
```

Build a debug APK without opening the Godot editor:

```powershell
.\tools\build_android.ps1
```

See `docs/EXPORT_PLAN.md` for the required Android toolchain and device acceptance gate.

## Repository Notes

- Do not commit exported builds.
- Do not commit Android signing keys.
- Do not commit Godot cache folders.
- Packaged builds should be attached to GitHub Releases.

## Roadmap Snapshot

| Version | Goal |
|---|---|
| v0.1.0 | Runtime-ready aquarium core prototype |
| v0.1.1 | Main JellyCat motion and aquarium life polish |
| v0.1.2 | Art prototype integration |
| v0.2.0 | Android APK CLI pipeline and device acceptance |
| v0.3.0 | Long-term resonance / multi-JellyCat systems |
