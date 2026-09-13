# JellyCat / 水母喵 — Codex Master Handoff + APK Roadmap

Last updated: 2026-09-13

This document consolidates the current design, engineering state, GitHub/Notion authority links, near-term runtime closure plan, art integration plan, and future APK roadmap for Codex handoff.

## 1. Authority Links

### GitHub

- Repository: https://github.com/JackTzeng/JellyCat-Godot
- Default branch: `main`
- Visibility: private
- Owner: `JackTzeng`

### Notion

- Project Hub: https://app.notion.com/p/3d9f53bbd3b281228b16f4e99764ee76
- Development Backlog: https://app.notion.com/p/2d5affc30bce434d9a2a4b86a3231807
- Art Asset Register: https://app.notion.com/p/7dee00a7dad945f28e4ad8d9effe7a83
- GitHub Bootstrap Packet: https://app.notion.com/p/3d9f53bbd3b281789b83c3e661f76557

### Existing GitHub Issues

- #1 P0 Runtime Log Cleanup / Action Debounce: https://github.com/JackTzeng/JellyCat-Godot/issues/1
- #2 P0 Stage 5 + SaveLoad Final QA: https://github.com/JackTzeng/JellyCat-Godot/issues/2
- #3 P1 Side Panel Aquarium UI Layout: https://github.com/JackTzeng/JellyCat-Godot/issues/3
- #4 P1 Main JellyCat Motion Patch: https://github.com/JackTzeng/JellyCat-Godot/issues/4
- #5 P1 Art Asset Spec + Naming Freeze: https://github.com/JackTzeng/JellyCat-Godot/issues/5
- #6 P2 Windows Export Plan: https://github.com/JackTzeng/JellyCat-Godot/issues/6
- #7 P2 Android APK Future Preparation: https://github.com/JackTzeng/JellyCat-Godot/issues/7

## 2. Critical Current-State Note

The GitHub repository has been initialized with planning documents, release checklists, asset specifications, and backlog issues.

However, the user's existing local Godot project source may not yet be imported into this repository. Do not assume `project.godot`, `scenes/`, `scripts/`, `data/`, or `assets/` are already present until repository contents confirm it.

Expected local project path on the user's machine:

```text
C:\Users\user\Documents\遊戲製作\JellyCat
```

Recommended repository clone/import path:

```text
C:\Users\user\Documents\遊戲製作\JellyCat-Godot-Repo
```

The user should copy the existing Godot project into the cloned repo, excluding generated/cache/build/signing files.

## 3. Product Vision

`JellyCat / 水母喵` is a cozy 2D aquarium virtual pet game built with Godot 4.

The player opens the game and sees a cute jellyfish-cat creature floating in a dreamy aquarium. The intended feeling is quiet, soft, therapeutic, cute, and immersive. The project should not feel like a noisy gacha game, horror ocean game, competitive game, or ad-driven mobile product.

Core product principles:

- Local-first single-player experience.
- Cozy, low-pressure pet care.
- Aquarium observation should be satisfying even when the player does not actively grind.
- No ads.
- No analytics.
- No login.
- No payment system.
- No cloud dependency in early versions.
- Desktop-first prototype; Android APK later.

## 4. Current Technical Direction

- Engine: Godot 4.x
- Language: GDScript
- Game type: 2D virtual pet / idle aquarium / electronic pet
- Save model: local JSON save
- Initial target: Windows desktop prototype
- Future target: Android APK after runtime, UI, touch UX, and art prototype stabilize

Expected logical design from prior implementation discussions:

- Scenes: boot, title, egg_select, hatch, aquarium, pet actor, status panel, action bar, evolution bar, debug/log panels, shop panel, coin pickup.
- Autoloads: GameApp, GameState, SceneRouter, SaveManager, VersionManager, TimeManager, RuntimeLogger.
- Systems: CareSystem, CurrencySystem, CoinDropSystem, EvolutionSystem, ShopSystem, InventorySystem, EggSystem, HatchSystem.
- Data files: species.json, evolution.json, items.json, balance.json, version.json.

## 5. v0.1.0 Existing Gameplay Scope

The current local prototype has been discussed and tested around these systems:

- Boot flow.
- Title screen.
- Egg selection.
- Hatch by tapping egg 10 times.
- Aquarium scene.
- Single main JellyCat.
- Feed food.
- Feed cookie.
- Touch interaction.
- Touch cooldown and daily touch EXP cap.
- Clean tank.
- Medicine.
- Evolution stages 1 to 5.
- Stage 5 max-stage guard.
- Bubble Coin currency.
- Bubble Coin spawn, click pickup, and auto-collect.
- Shop purchase for food, cookie, and medicine.
- Daily free food.
- Save/load.
- Runtime Log panel.

## 6. Latest Runtime Observations from User Logs

Observed working behaviors:

- Boot to Aquarium works.
- Version/data load works.
- Save/load works.
- Daily free food can be claimed once.
- Daily free food repeat is blocked.
- Bubble Coin spawn works.
- Cookie consumption works.
- Cookie increases growth EXP.
- Feed food correctly blocks when inventory is zero.
- Medicine correctly detects already healthy.
- Evolve correctly blocks when EXP is insufficient.
- Clean works.

Observed issues needing closure:

- Failed/no-op operations still log `Aquarium UI refreshed`.
- Rapid repeated clicks can spam Runtime Log.
- `Clean` can trigger save even when cleanliness is already 100.
- `Medicine already healthy` can still refresh/log unnecessarily.
- `Evolve cannot evolve yet` can still refresh/log unnecessarily.
- Touch still risks noisy `ACTION Touch clicked` spam.

These are runtime signal-quality and no-op handling issues, not fundamental gameplay failures.

## 7. Immediate Execution Order for Codex

Work must proceed in this order unless the user explicitly reprioritizes:

1. Import local Godot source into GitHub repository, if not already imported.
2. Execute Issue #1: Runtime Log Cleanup / Action Debounce.
3. Execute Issue #2: Stage 5 + SaveLoad Final QA.
4. Execute Issue #3: Side Panel Aquarium UI Layout.
5. Execute Issue #4: Main JellyCat Motion Patch.
6. Execute Issue #5: Art Asset Spec + Naming Freeze.
7. Execute Issue #6: Windows Export Plan.
8. Execute Issue #7: Android APK Future Preparation.

Do not jump directly to APK before v0.1.0 runtime-ready closure and v0.1.x UI/art/motion stabilization.

## 8. v0.1.0 Runtime Closure Blueprint

Goal: freeze the first stable playable core.

Required closure items:

- Reset Save works.
- New Game works.
- Egg Select works.
- Hatch 10 taps works.
- Aquarium loads.
- Feed works.
- Cookie works.
- Touch cooldown works.
- Touch daily cap works.
- Clean works.
- Medicine works.
- Daily Food works.
- Bubble Coin spawn works.
- Bubble Coin pickup works.
- Bubble Coin auto-collect works.
- Shop buy works.
- Not enough item does not crash.
- Not enough coin does not crash.
- Evolution works.
- Stage 5 max stage does not crash.
- Save/load works after all key state changes.
- Hide Log / Show Log works.
- Runtime Log does not spam.
- No parser error.
- No runtime error.

Issue #1 specifically requires:

- Same action within 0.3 seconds ignored without log/save/refresh.
- Failed actions do not write `Aquarium UI refreshed`.
- No-op actions do not save.
- Repeated no-op/error messages are throttled.

## 9. Aquarium UI Layout Blueprint

The Aquarium scene must preserve the central JellyCat visual focus.

Target layout:

- Left top: Status Panel.
- Left bottom: Runtime Log during development.
- Right top or right middle: Inventory / Shop status.
- Right bottom: Action Buttons.
- Center: main JellyCat only.

Do not stack all windows in the top center. Do not cover the JellyCat or central aquarium view with a wide opaque panel.

Current viewport from prior tests: 1672 x 941. Do not change viewport unless the issue explicitly requires responsive/mobile layout work.

## 10. Main JellyCat Motion Blueprint

Before adding many JellyCats, make the current main JellyCat feel alive.

Expected motion:

- Idle floating.
- Breathing / pulsing.
- Subtle rotation.
- Touch success reaction.
- Feed success reaction.
- Cookie success reaction.
- Medicine success reaction.
- Evolve success reaction.
- Sick-state visual and motion difference.

Motion must be visual-only:

- Do not modify save data.
- Do not modify economy.
- Do not modify evolution rules.
- Do not add ambient/multi-pet systems yet.
- Do not add AnimationTree unless truly needed.
- Prefer simple procedural sine motion plus short Tween reactions.

## 11. Multi-JellyCat Future Direction

The user wants many JellyCats moving in the aquarium eventually. The recommended architecture is layered:

- Main JellyCat: the only fully interactive pet with hunger, mood, cleanliness, health, growth EXP, evolution, save/load, and action effects.
- Ambient JellyCats: visual-only background actors for aquarium life and mood.

Do not implement true multi-pet ownership yet.

Future ambient design:

- 6 to 10 ambient JellyCats.
- Visual-only.
- No hunger/mood/health/growth.
- No individual save records.
- No bubble coin production.
- No feeding/touch/evolution.
- Do not intercept main JellyCat or bubble coin clicks.

True multi-pet ownership should be deferred to a later version with explicit schema design:

```json
{
  "owned_jellycats": [],
  "active_jellycat_id": "jc_001",
  "tank_roster": []
}
```

Do not add that schema in v0.1.x unless explicitly requested.

## 12. Art Direction Summary

The art direction is:

- 2D casual mobile game art.
- Pastel underwater fantasy.
- Dreamy aquarium.
- Soft blue, cyan, lavender, pale teal, pearl white.
- Translucent jelly body.
- Soft glow.
- Rounded shapes.
- Clean silhouette.
- Cozy, quiet, therapeutic.
- Cute but not childish.
- Readable at mobile-game scale.

Avoid:

- Horror ocean.
- Realistic scary jellyfish.
- Sharp dangerous tentacles.
- Heavy cyberpunk neon.
- Noisy gacha-game UI.
- Text baked into sprites or UI images.
- Logos and watermarks.

## 13. v0.1 Art Asset Baseline

The v0.1 recommended art asset baseline is 38 images:

- Aquarium background and overlays: 4.
- Normal JellyCat stages 1 to 5: 5.
- State/effect overlays: 5.
- Egg and hatch assets: 4.
- Bubble Coin assets: 4.
- Item icons: 3.
- UI elements: 13.

Detailed asset names and target paths are in:

- GitHub: `docs/ART_ASSET_SPEC.md`
- Notion: JellyCat Art Asset Register

Do not expand to five full species before the normal JellyCat 5-stage baseline is validated in-engine.

## 14. Version Roadmap

### v0.1.0-runtime-ready

Purpose: stable core prototype.

Contains:

- Hatch.
- Care actions.
- Evolution.
- Bubble Coin.
- Shop.
- Daily Food.
- Save/load.
- Runtime Log.
- Stage 5 guard.
- UI readable and non-blocking.

### v0.1.1-motion

Purpose: make the main JellyCat feel alive.

Contains:

- Main JellyCat idle floating.
- Breathing / pulsing.
- Touch/feed/cookie/medicine/evolve reactions.
- Sick-state motion/visual difference.

### v0.1.2-art-prototype

Purpose: replace placeholders with coherent art.

Contains:

- Normal JellyCat stage 1 to 5 art.
- Egg art.
- Bubble coin art.
- Item icons.
- Aquarium background layers.
- UI panel/button/progress assets.

### v0.1.3-windows-build

Purpose: first packaged desktop app.

Contains:

- Windows desktop export.
- Local save verified in exported build.
- ZIP package.
- GitHub Release attachment.

### v0.2.0-android-prep

Purpose: prepare Android APK without breaking desktop prototype.

Contains:

- Landscape mobile layout decision.
- Touch-friendly UI sizing.
- Safe area handling.
- Runtime Log hidden by default for player builds.
- Android export templates.
- Package ID.
- App icon and splash screen.
- Save path verification.
- APK signing policy.
- Real device test checklist.

### v0.3.0-content-expansion

Purpose: content expansion after core is stable.

Contains:

- Multiple JellyCat species.
- Collection / gallery.
- Unlock conditions.
- Potential ambient JellyCats.

### v0.4.0-resonance-breeding

Purpose: long-term retention system.

Potentially contains:

- Resonance hatching / breeding-like system.
- Mature JellyCat pair logic.
- New egg results.
- Rare species progression.

## 15. APK Roadmap

Android APK is feasible, but should not be the immediate next step until runtime closure, layout, motion, and art prototype are stable.

Recommended Android target:

- Android package ID: `com.jacktzeng.jellycat` or `com.jacktzeng.jellycatgodot`.
- Orientation: landscape.
- Distribution: personal sideload first.
- Monetization: none.
- Ads: none.
- Analytics: none.
- Login: none.
- Network: none unless explicitly added later.
- Save: local app storage.

Required APK preparation work:

1. Confirm Godot Android export template version matches local Godot editor version.
2. Add Android export preset locally.
3. Decide package ID.
4. Add app icon.
5. Add splash screen.
6. Verify landscape lock.
7. Verify touch input for all core actions.
8. Redesign/scale UI for touch target size.
9. Hide Runtime Log by default in non-debug/player builds.
10. Verify save/load path on Android.
11. Create signing key outside repository.
12. Ensure `.gitignore` excludes signing files.
13. Export APK.
14. Install on physical Android device.
15. Test complete new-game to aquarium flow.
16. Test close/reopen save persistence.
17. Test UI safe area and different aspect ratios.

Do not commit exported APK, signing keys, or keystore files. APK builds should be attached to GitHub Releases, not committed to `main`.

## 16. Repository Hygiene

Do not commit:

- `.godot/`
- `.import/`
- Exported builds
- `.exe`
- `.apk`
- `.aab`
- `.pck`
- `.zip`
- Log files
- Keystores
- JKS files
- P12 files
- Temporary files

Commit:

- `project.godot`
- `scenes/`
- `scripts/`
- `data/`
- source assets under `assets/`
- docs under `docs/`
- `.gitignore`
- `README.md`

## 17. Strict Scope-Control Rules for Codex

Codex must follow these unless the user explicitly overrides:

- Do not add new gameplay while fixing P0 runtime issues.
- Do not change viewport/background while fixing log/action/runtime issues.
- Do not add new JellyCat species during runtime closure.
- Do not add multi-pet ownership during v0.1.x unless explicitly requested.
- Do not change save schema without documenting migration.
- Do not change economy balance unless working on a balance issue.
- Do not export APK before Android prep issue is reached.
- Do not commit exported binaries.
- Do not commit signing files.
- Prefer small commits tied to one issue.
- Update docs when behavior changes.

## 18. First Codex Execution Prompt

Use this prompt when handing the repository to Codex:

```text
You are now working on JellyCat / 水母喵, a Godot 4 cozy 2D aquarium virtual pet game.

Authority links:
- GitHub repo: https://github.com/JackTzeng/JellyCat-Godot
- Notion Project Hub: https://app.notion.com/p/3d9f53bbd3b281228b16f4e99764ee76
- Notion Development Backlog: https://app.notion.com/p/2d5affc30bce434d9a2a4b86a3231807
- Notion Art Asset Register: https://app.notion.com/p/7dee00a7dad945f28e4ad8d9effe7a83

Read these GitHub docs first:
- README.md
- docs/CODEX_PROJECT_HANDOFF_APK_ROADMAP.md
- docs/CODEX_HANDOFF.md
- docs/GAME_DESIGN.md
- docs/TECH_ARCHITECTURE.md
- docs/RELEASE_CHECKLIST.md
- docs/ART_ASSET_SPEC.md

Important: first verify whether the actual local Godot source has already been imported into the repository. If `project.godot`, `scenes/`, `scripts/`, and `data/` are missing, report that the repository currently contains planning docs only and request/import the local Godot project before editing runtime code.

Immediate work order:
1. Confirm repository contents.
2. If source exists, execute GitHub Issue #1: P0 Runtime Log Cleanup / Action Debounce.
3. Do not add gameplay, art, APK export, new species, or multi-pet systems while working on Issue #1.
4. Keep changes small and issue-scoped.
5. Update docs/CHANGELOG.md after changes.
6. Report modified files, parser/runtime errors, and manual Godot verification status.

Future roadmap:
- v0.1.0 runtime-ready closure.
- v0.1.1 main JellyCat motion.
- v0.1.2 art prototype.
- v0.1.3 Windows export.
- v0.2.0 Android APK preparation.

Android APK is future work, not the next immediate task.
```

## 19. Completion Definition

This handoff is complete when Codex can answer these before writing code:

- What is the current repository?
- Where are the Notion planning pages?
- What is the current v0.1 gameplay scope?
- What is the immediate P0 issue?
- What must not be changed during P0 runtime closure?
- What is the future Android APK sequence?
- Which files should not be committed?
- Whether the actual Godot source is present in the repo.
