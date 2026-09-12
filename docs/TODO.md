# TODO

## P0 - v0.1.0 Runtime Ready

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
- [ ] Save / Load final QA
- [ ] Reset Save final QA

## P1 - v0.1.0 UI Layout Freeze

- [ ] Status Panel should move to left top
- [ ] Inventory Panel should move to right top or right middle
- [ ] Runtime Log should remain left bottom during development
- [ ] Action Buttons should remain right bottom
- [ ] Center should be reserved for the main JellyCat

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

## P2 - v0.1.3 Export

- [ ] Install Godot export templates
- [ ] Configure Windows export preset
- [ ] Export Windows desktop build
- [ ] Test build launch
- [ ] Test save/load in exported build
- [ ] Attach ZIP to GitHub Release

## P2 - v0.2.0 Android Preparation

- [ ] Decide landscape-only orientation
- [ ] Verify touch target sizes
- [ ] Verify safe areas
- [ ] Hide Runtime Log by default
- [ ] Configure Android package name
- [ ] Prepare app icon and splash screen
- [ ] Prepare signing key outside repo
- [ ] Device test APK
