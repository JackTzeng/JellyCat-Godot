# Changelog

## Unreleased

### Added

- Imported the existing Godot 4 runtime source, scenes, data tables, assets, export preset, and automated acceptance tooling into GitHub.
- Preserved the planning documents already established in the repository.

### Verification

- Godot 4.2.1 headless acceptance passed: `RUNTIME_ACCEPTANCE_OK checks=88`.
- Verified all 72 imported file blobs against the local source commit with zero SHA mismatches.
- Graphical editor playthrough and visual QA remain pending.

## v0.1.0 Aquarium Core Prototype

### Added

- Initial project planning authority for JellyCat / 水母喵.
- Core aquarium virtual pet feature scope.
- GitHub repository documentation scaffold.
- Notion Project Hub alignment references.
- Runtime-ready checklist and export planning documents.

### Planned Runtime Fixes

- Action debounce for aquarium buttons.
- No-op actions should not request save.
- Failed operations should not log `Aquarium UI refreshed`.
- Repeated error and no-op messages should be throttled.
- Stage 5 max-stage behavior should be verified.

### Planned UI Changes

- Move status information to a side panel.
- Keep the main JellyCat visible in the center.
- Keep Runtime Log and action buttons out of the central aquarium area.

## v0.1.1 Main JellyCat Motion Patch

### Planned

- Main JellyCat idle floating.
- Breathing / pulsing motion.
- Subtle rotation.
- Successful action reaction animations.
- Sick-state visual and motion adjustment.

## v0.1.2 Art Prototype

### Planned

- Normal JellyCat stages 1 to 5.
- Aquarium background and overlays.
- Egg and hatch sprites.
- Bubble coin art.
- Item icons.
- UI panel, button, and progress bar assets.

## v0.1.3 Windows Build

### Planned

- Windows desktop export.
- Release ZIP packaging.
- GitHub Release attachment.

## v0.2.0 Android Preparation

### Planned

- Landscape mobile layout review.
- Touch-friendly UI.
- Runtime Log hidden by default.
- Android export template and signing flow.
- APK device test.
