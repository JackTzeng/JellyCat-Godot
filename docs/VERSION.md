# Version Status

## Current Version

`v0.1.0 Aquarium Core Prototype`

## Runtime Status

`Prototype`

Do not mark as `Runtime Ready` until the full Godot Editor validation passes.

## Automated Validation

- Godot version: 4.2.1 stable
- Result: `RUNTIME_ACCEPTANCE_OK checks=88`
- Imported source commit: `2cbd847`
- Manual graphical editor playthrough: pending

## Current Target

Windows desktop prototype first.

## Future Target

Android APK after:

1. Aquarium UI layout is stable.
2. Main JellyCat motion is stable.
3. Core art assets are integrated.
4. Touch UX is verified.
5. Runtime Log is hidden or developer-gated by default.

## Version Plan

| Version | Status | Goal |
|---|---|---|
| v0.1.0 | Active | Runtime-ready aquarium core prototype |
| v0.1.1 | Planned | Main JellyCat motion patch |
| v0.1.2 | Planned | Art prototype integration |
| v0.1.3 | Planned | Windows export package |
| v0.2.0 | Planned | Android APK preparation |
| v0.3.0 | Planned | Resonance / multi-JellyCat long-term system |

## v0.1.0 Runtime-Ready Gate

The version may be marked runtime-ready only after:

- Boot flow passes
- New Game passes
- Egg Select passes
- Hatch 10 taps passes
- Aquarium loads
- Feed / Cookie / Touch / Clean / Medicine pass
- Daily Food passes
- Bubble Coin spawn / pickup / auto-collect pass
- Shop buy passes
- Not enough item / coin does not crash
- Evolution and Stage 5 max-stage pass
- Save / Load pass
- Reset Save pass
- Runtime Log does not spam
- No parser error
- No runtime error
