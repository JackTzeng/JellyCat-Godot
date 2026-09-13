# TODO

## P0 - Android APK CLI Pipeline

- [x] Install matching Godot 4.2.1 Android export templates
- [x] Add Android APK export preset
- [x] Add a GUI-free PowerShell build entrypoint
- [ ] Install OpenJDK 17
- [ ] Install the Godot 4.2 Android SDK package baseline
- [ ] Generate local debug keystore outside the repo
- [ ] Export the first debug APK
- [ ] Install APK with ADB on a physical device
- [ ] Complete Android touch and save/load smoke test

## P0 - Runtime Safety

- [ ] Runtime Log Cleanup / Action Debounce
- [ ] Feed failure should not log `Aquarium UI refreshed`
- [ ] Cookie failure should not log `Aquarium UI refreshed`
- [ ] Clean no-op should not save
- [ ] Medicine already healthy should not save
- [ ] Evolve cannot evolve should not save
- [ ] Daily Food already claimed should not save
- [ ] Repeated no-op and error logs should be throttled
- [ ] Touch should not spam logs
- [ ] Stage 5 max-stage behavior should not crash
- [ ] Save / Load final QA on Android
- [ ] Reset Save final QA on Android

## P1 - Mobile UI and Touch

- [ ] Freeze landscape-only orientation
- [ ] Verify touch target sizes
- [ ] Verify safe areas and common aspect ratios
- [ ] Hide Runtime Log by default
- [ ] Keep main JellyCat visible in the center
- [ ] Prepare Android launcher and adaptive icons
- [ ] Prepare splash screen

## P1 - v0.1.1 Motion

- [ ] Main JellyCat idle floating
- [ ] Breathing / pulsing
- [ ] Subtle rotation
- [ ] Touch reaction
- [ ] Feed reaction
- [ ] Cookie reaction
- [ ] Medicine success reaction
- [ ] Evolve success reaction
- [ ] Sick-state idle and color adjustment

## P1 - v0.1.2 Art Integration

- [ ] Freeze asset naming rules
- [ ] Freeze target Godot paths
- [ ] Generate / import normal JellyCat stages 1 to 5
- [ ] Generate / import egg sprites
- [ ] Generate / import bubble coin sprites
- [ ] Generate / import item icons
- [ ] Generate / import UI assets
- [ ] Generate / import aquarium background and overlays

## P3 - Deferred Windows Packaging

- [ ] Reassess Windows export only after APK-ready acceptance
