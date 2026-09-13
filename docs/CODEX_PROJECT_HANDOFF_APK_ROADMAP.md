# JellyCat / 水母喵 — Codex Master Handoff + APK Roadmap

Last updated: 2026-09-13

## 1. Authority Links

- GitHub: https://github.com/JackTzeng/JellyCat-Godot
- Notion Project Hub: https://app.notion.com/p/3d9f53bbd3b281228b16f4e99764ee76
- Notion Development Backlog: https://app.notion.com/p/2d5affc30bce434d9a2a4b86a3231807
- Notion Art Asset Register: https://app.notion.com/p/7dee00a7dad945f28e4ad8d9effe7a83
- Working clone: `C:\Users\user\Documents\遊戲製作\JellyCat-Godot-Repo`

## 2. Current Source State

The original Godot source is present in GitHub and in the working clone. It includes `project.godot`, scenes, GDScript systems/controllers, data tables, assets, automated acceptance tooling, and export presets.

Baseline headless verification passes:

```text
RUNTIME_ACCEPTANCE_OK checks=88
```

## 3. Product and Platform Decision

JellyCat is a cozy 2D aquarium virtual pet with a local-first, single-player core. Android APK is now the primary application target.

Development policy:

- No Godot GUI/editor dependency.
- Source and project configuration are maintained as text.
- Automated checks run with Godot 4.2.1 in headless mode.
- APK export runs from PowerShell.
- Final visual/touch/save acceptance runs on a physical Android device.
- Windows packaging is deferred.

Product constraints remain:

- No ads, analytics, login, payments, or cloud dependency.
- No new species, breeding, minigames, or true multi-pet persistence during APK/runtime closure.
- Local JSON save remains the source of player state.

## 4. Current Gameplay Scope

- Boot / Title / Egg Select / Hatch / Aquarium flow
- Hatch after 10 egg taps
- Single main JellyCat
- Feed / Cookie / Touch / Clean / Medicine
- Five evolution stages with Stage 5 guard
- Bubble Coin spawn, pickup, and auto-collect
- Shop and daily free food
- Local save/load and reset
- Development Runtime Log

## 5. Immediate Execution Order

1. Complete the Android CLI toolchain: OpenJDK 17, Android SDK, ADB, debug keystore.
2. Build the first debug APK using `tools/build_android.ps1`.
3. Install with ADB and run physical-device boot/touch/save smoke tests.
4. Execute runtime log cleanup and no-op save fixes.
5. Freeze mobile landscape layout and touch-safe controls.
6. Add main JellyCat motion and baseline art.
7. Re-run device acceptance after each player-facing milestone.

## 6. Android Technical Baseline

- Engine: Godot 4.2.1 stable
- Language: GDScript
- Package ID: `com.jacktzeng.jellycat`
- Orientation: landscape
- Rendering: mobile renderer
- Distribution: personal sideload first
- Build preset: `Android APK`
- Build entrypoint: `tools/build_android.ps1`
- Artifact: `exports/builds/android/JellyCat-debug.apk`

Required Godot 4.2 toolchain:

- OpenJDK 17
- Platform-Tools 30.0.5 or later
- Build-Tools 33.0.2
- Android Platform 33
- Command-line Tools latest
- CMake 3.10.2.4988404
- NDK 23.2.8568313

The build script uses an isolated Godot user home, checks required components, generates a local debug keystore outside the repo when absent, runs 88 headless checks, and only reports success if a new APK file was actually produced.

## 7. APK Acceptance Gate

- [ ] Headless acceptance passes 88 checks
- [ ] CLI debug export creates a new APK
- [ ] ADB sees the target device
- [ ] APK installs or upgrades successfully
- [ ] Title, New Game, Egg Select, Hatch, and Aquarium flow work by touch
- [ ] Feed / Cookie / Touch / Clean / Medicine work
- [ ] Shop, currency, evolution, and Stage 5 guard work
- [ ] Save persists across close/reopen
- [ ] Landscape UI remains usable across target aspect ratios
- [ ] Runtime Log is hidden or developer-gated
- [ ] No missing assets, parser errors, runtime crashes, or close/reopen crashes

## 8. Mobile UI and Motion Direction

- Keep the main JellyCat visually central.
- Use side/bottom controls sized for touch.
- Respect safe areas and wide phone aspect ratios.
- Keep debug UI out of player builds.
- Motion should remain visual-only: idle float, breathing, subtle rotation, and short interaction reactions.
- Motion must not change save data, economy, or evolution rules.

## 9. Repository Hygiene

Commit source, scenes, data, assets, documentation, export presets, and build scripts.

Do not commit:

- `.godot/` or `.import/`
- APK, AAB, EXE, PCK, ZIP, or generated build output
- CLI-local Godot home/cache
- Keystores, signing keys, passwords, or credentials
- Logs and temporary files

## 10. Version Roadmap

- `v0.1.0-runtime-ready`: headless-stable aquarium core.
- `v0.1.1-motion`: main JellyCat idle and interaction motion.
- `v0.1.2-art-prototype`: coherent mobile-readable baseline art.
- `v0.2.0-android-apk`: CLI toolchain, debug APK, mobile UI, device acceptance.
- `v0.3.0-content-expansion`: multiple species/collection after APK stability.
- `v0.4.0-resonance-breeding`: future long-term retention system.

Windows packaging has no committed version and is reassessed only after Android APK readiness.

## 11. Next Codex Prompt

```text
Continue JellyCat / 水母喵 as architect and PM. Android APK is the primary target. Do not use or require the Godot GUI. Work through text/source edits, Godot 4.2.1 headless checks, tools/build_android.ps1, and physical Android device acceptance. Preserve the current gameplay architecture and product constraints. Do not commit exported binaries or signing material. First read README.md, docs/CODEX_HANDOFF.md, docs/EXPORT_PLAN.md, docs/TODO.md, and the linked Notion Project Hub; then continue the highest-priority incomplete APK/runtime item.
```
