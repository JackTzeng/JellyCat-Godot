# Version Status

## Current Version

`v0.1.0 Aquarium Core Prototype`

## Runtime Status

`APK Integration`

Do not mark as `APK Ready` until the CLI export and physical-device acceptance gate passes.

## Automated Validation

- Godot version: 4.2.1 stable
- Current headless result: `RUNTIME_ACCEPTANCE_OK checks=88`
- Imported source commit: `2cbd847`
- Godot GUI/editor validation: intentionally removed from the release gate

## Current Target

Android debug APK built entirely through CLI/headless tooling.

## Deferred Target

Windows desktop packaging is deferred and is not a dependency of Android development.

## Version Plan

| Version | Status | Goal |
|---|---|---|
| v0.1.0 | Active | Headless-validated aquarium core prototype |
| v0.1.1 | Planned | Main JellyCat motion patch |
| v0.1.2 | Planned | Art prototype integration |
| v0.2.0 | Active | Android APK CLI pipeline and device acceptance |
| v0.3.0 | Planned | Resonance / multi-JellyCat long-term system |

## APK-Ready Gate

The Android build may be marked APK-ready only after:

- Headless boot and gameplay acceptance passes
- Debug APK exports from `tools/build_android.ps1`
- APK installs on a physical Android device
- New Game / Egg Select / Hatch 10 taps pass by touch
- Aquarium loads in landscape orientation
- Feed / Cookie / Touch / Clean / Medicine pass
- Daily Food passes
- Bubble Coin spawn / pickup / auto-collect pass
- Shop buy and insufficient-resource cases do not crash
- Evolution and Stage 5 max-stage pass
- Save / Load and Reset Save pass on Android
- Runtime Log is hidden or developer-gated by default
- No parser, export, install, or runtime error
