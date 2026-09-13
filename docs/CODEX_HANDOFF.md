# Codex Handoff

## Role

Continue JellyCat / 水母喵 as its game architect and PM. Preserve the existing Godot 4/GDScript architecture while making Android APK the primary delivery target.

## Authority

- Repository: https://github.com/JackTzeng/JellyCat-Godot
- Notion Project Hub: https://app.notion.com/p/3d9f53bbd3b281228b16f4e99764ee76
- Working clone: `C:\Users\user\Documents\遊戲製作\JellyCat-Godot-Repo`

## Current Direction

- Do not use or require the Godot graphical editor.
- Edit source and project configuration as text.
- Validate through Godot 4.2.1 `--headless` commands.
- Export Android debug APKs through `tools/build_android.ps1`.
- Validate the APK on a physical Android device using ADB.
- Defer Windows packaging until after APK-ready acceptance.

## Immediate Priority

1. Install OpenJDK 17 and the Godot 4.2 Android SDK package baseline.
2. Export the first debug APK with package ID `com.jacktzeng.jellycat`.
3. Install and smoke-test the APK on a physical Android device.
4. Fix runtime log/no-op save behavior and Android-specific touch/layout issues.
5. Integrate motion and art without destabilizing the mobile core loop.

## Hard Constraints

- No ads, analytics, login, payments, or cloud dependency.
- No new species, breeding, minigames, or true multi-pet save schema during runtime/APK closure.
- Do not commit APK/AAB files, generated caches, signing keys, or credentials.
- Runtime Log must be hidden or developer-gated in player builds.
- A Godot GUI playthrough is not a release requirement.

## Acceptance Authority

An APK is ready only when:

- `RUNTIME_ACCEPTANCE_OK checks=88` passes headlessly.
- A new APK is produced by the CLI build script.
- ADB installation succeeds.
- Touch, landscape layout, core aquarium loop, and Android save persistence pass on a physical device.
