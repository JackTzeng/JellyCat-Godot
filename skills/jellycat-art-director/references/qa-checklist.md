# JellyCat Visual QA Checklist

## Identity

- [ ] JellyCat remains clearly readable as jellyfish + cat.
- [ ] Face and body proportions are consistent with the intended reference.
- [ ] No unintended anatomy was introduced.

## Style

- [ ] Overall mood is healing, soft, and aquatic.
- [ ] Material reads as translucent jelly rather than hard plastic.
- [ ] Visual noise is controlled.
- [ ] Character remains readable at gameplay scale.

## Production

- [ ] Dimensions match the requested target.
- [ ] Transparency is correct where required.
- [ ] No unwanted background pixels or matte edges.
- [ ] No accidental text, fake UI, watermarks, or random symbols.
- [ ] Asset is separated appropriately for Godot integration.

## Animation

- [ ] Frame canvas sizes match.
- [ ] Subject scale is stable.
- [ ] Anchor is stable.
- [ ] Lighting and palette are stable.
- [ ] Loop transition is acceptable.
- [ ] No unintended jitter or morphology drift.

## Environment

- [ ] Midground has usable movement space.
- [ ] JellyCat sprites remain readable against the background.
- [ ] Reusable background does not bake in character-specific shadows or positions.

## UI

- [ ] Text is not baked into image unless explicitly requested.
- [ ] Icons remain legible at target size.
- [ ] UI does not dominate the aquarium view.

## Final gate

Classify result as one of:

- `PASS_APPROVED_CANDIDATE`
- `PASS_WITH_MINOR_FIX`
- `REGENERATE`
- `CONCEPT_ONLY`

Generated output is not automatically an approved production asset.
