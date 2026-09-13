# Android APK CLI Plan

## Product Direction

Android APK is the primary application target. Development, validation, and export must not depend on the Godot graphical editor.

The supported workflow is:

1. Edit project text files and assets directly.
2. Run Godot in `--headless` mode.
3. Run the automated runtime acceptance scene.
4. Export a debug APK from the command line.
5. Install and test the APK on a physical Android device with ADB.

Windows export is deferred and is not a release gate.

## Toolchain Baseline

- Godot 4.2.1 stable console executable
- Matching Godot 4.2.1 Android export templates
- OpenJDK 17
- Android SDK Platform-Tools 30.0.5 or later
- Android SDK Build-Tools 33.0.2
- Android SDK Platform 33
- Android SDK Command-line Tools latest
- CMake 3.10.2.4988404
- Android NDK 23.2.8568313

## Debug APK Build

From PowerShell:

```powershell
.\tools\build_android.ps1
```

If the tools are not in their default locations:

```powershell
.\tools\build_android.ps1 `
  -GodotPath "C:\path\to\Godot_console.exe" `
  -JavaSdkPath "C:\path\to\jdk-17" `
  -AndroidSdkPath "C:\path\to\Android\Sdk"
```

Expected local artifact:

```text
exports/builds/android/JellyCat-debug.apk
```

The build script uses an isolated Godot CLI home under `exports/.godot-cli-home`, configures Android paths without opening the GUI, runs the headless acceptance suite, generates a local debug keystore when needed, and exports the APK.

## APK Acceptance Gate

- [ ] `RUNTIME_ACCEPTANCE_OK checks=88`
- [ ] Headless export returns exit code 0
- [ ] APK exists at the expected output path
- [ ] `adb install -r` succeeds on a physical device
- [ ] App boots into the title flow
- [ ] Touch targets respond in landscape orientation
- [ ] Aquarium core loop works
- [ ] Save data survives closing and reopening the app
- [ ] No missing assets or crash on exit

## Signing and Repository Policy

- Package ID: `com.jacktzeng.jellycat`
- Debug builds use the local Android debug keystore.
- Release signing keys and passwords must stay outside the repository.
- Do not commit APK, AAB, generated caches, or signing credentials.
- Publish distributable builds through GitHub Releases after device acceptance.
