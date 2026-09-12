# Export Plan

## Current Recommendation

The first app target should be a Windows desktop export.

Android APK should be treated as future work after UI layout, touch UX, and art prototype stabilization.

## Windows Export Plan

### Prerequisites

- Godot 4 export templates installed
- Local project opens without parser error
- Runtime-ready checklist passes in Godot Editor

### Build Steps

1. Open project in Godot 4.
2. Install matching export templates.
3. Create a Windows Desktop export preset.
4. Export the build to a local build folder.
5. Verify whether the output requires a `.pck` beside the `.exe`.
6. Launch exported build.
7. Test save/load.
8. Zip the build folder.
9. Attach the ZIP to a GitHub Release.

### Windows Build Checklist

- [ ] Build launches
- [ ] Window size is correct
- [ ] Aquarium scene displays correctly
- [ ] Controls work
- [ ] Save file writes correctly
- [ ] Reopening build loads save
- [ ] No missing assets
- [ ] No crash on close

## Android APK Future Plan

Android is not the v0.1.0 target.

### Required Preparation

- Landscape layout decision
- Touch-friendly button sizes
- Safe-area review
- Runtime Log hidden by default
- Android export template installed
- Package name decision
- App icon
- Splash screen
- Save path verification
- APK signing key stored outside the repo
- Device test on real Android hardware

### Android Risks

- Current 1672 x 941 layout is desktop-first.
- UI may need substantial repositioning for phones.
- Debug Runtime Log is not appropriate as a default player-facing panel.
- APK signing must not be committed to GitHub.

## Repository Policy

Do not commit exported builds, signing keys, or generated caches.

Use GitHub Releases for packaged builds.
