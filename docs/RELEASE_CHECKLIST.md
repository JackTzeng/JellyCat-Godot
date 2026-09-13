# Release Checklist

## v0.1.0 Runtime Ready Checklist

- [ ] Reset Save works
- [ ] New Game works
- [ ] Egg Select works
- [ ] Hatch 10 taps works
- [ ] Aquarium loads
- [ ] Feed works
- [ ] Cookie works
- [ ] Touch cooldown works
- [ ] Touch daily cap works
- [ ] Clean works
- [ ] Medicine works
- [ ] Daily Food works
- [ ] Bubble Coin spawn works
- [ ] Bubble Coin pickup works
- [ ] Bubble Coin auto-collect works
- [ ] Shop buy works
- [ ] Not enough item does not crash
- [ ] Not enough coin does not crash
- [ ] Evolution works
- [ ] Stage 5 max stage does not crash
- [ ] Save / Load works
- [ ] Hide Log / Show Log works
- [ ] Runtime Log does not spam
- [ ] No parser error
- [ ] No runtime error

## v0.1.0 UI Layout Checklist

- [ ] Status Panel is not top-center full-width
- [ ] Status Panel is left-top or side-panel style
- [ ] Inventory is right-top or right-middle
- [ ] Action Buttons are right-bottom
- [ ] Runtime Log is left-bottom during development
- [ ] Center remains clear for the main JellyCat
- [ ] UI does not cover Bubble Coin pickups

## v0.1.1 Main JellyCat Motion Checklist

- [ ] Main JellyCat slowly floats
- [ ] Main JellyCat has light breathing / pulsing motion
- [ ] Main JellyCat has subtle rotation only
- [ ] Touch success reaction works
- [ ] Feed success reaction works
- [ ] Cookie success reaction works
- [ ] Medicine success reaction works
- [ ] Evolve success reaction works
- [ ] Failed actions do not play success reactions
- [ ] Sick state has gentle visual difference
- [ ] Animation does not modify save data

## P3 Deferred Windows Build Checklist

- [ ] Export preset configured
- [ ] Build launches
- [ ] Save file works
- [ ] Window size correct
- [ ] UI visible
- [ ] Controls usable
- [ ] No missing assets
- [ ] No crash on close / reopen
- [ ] ZIP package created
- [ ] GitHub Release created

## P0 Android APK Checklist

- [x] Matching Android export template installed
- [x] Android APK export preset configured
- [x] Package name selected: `com.jacktzeng.jellycat`
- [x] GUI-free CLI build entrypoint added
- [ ] OpenJDK 17 installed
- [ ] Required Android SDK packages installed
- [ ] Headless 88-check acceptance passes immediately before export
- [ ] New debug APK exported successfully
- [ ] Landscape mode verified on device
- [ ] Touch targets reviewed
- [ ] Safe areas reviewed
- [ ] Runtime Log hidden by default
- [ ] App icon ready
- [ ] Splash screen ready
- [ ] Signing key prepared outside repo
- [ ] APK installs through ADB on a physical device
- [ ] Core gameplay smoke test passes by touch
- [ ] Save/load survives close/reopen on device
