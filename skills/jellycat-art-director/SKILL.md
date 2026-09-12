# JellyCat Art Director

Codex-native visual production skill for the JellyCat Godot project.

## Purpose

Use this skill whenever work involves JellyCat visual direction, image generation, sprite production, aquarium backgrounds, UI art, animation frames, asset briefs, or visual QA.

This skill is an art-production layer. It does not redefine gameplay rules, economy, save data, scene routing, or other game logic.

## Invocation

Invoke for requests such as:

- design or generate a JellyCat character asset
- create idle / swim / touch / feed / sick / happy animation art
- create aquarium or tank backgrounds and decorations
- create visual assets for menus, panels, buttons, icons, items, coins, food, medicine, cookies, or effects
- convert a feature request into an art-production brief
- review whether an asset matches the project's visual identity
- prepare assets for Godot integration

Suggested explicit invocation:

`$jellycat-art-director <request>`

## Required reference order

Read only the references needed for the current task, but resolve conflicts in this order:

1. `references/art-bible.md`
2. task-specific reference (`jellycat-character-standard.md`, `aquarium-environment.md`, `animation-standard.md`, `ui-visual-standard.md`)
3. `references/asset-production-spec.md`
4. `references/qa-checklist.md`
5. explicit current user instruction overrides default preferences unless it would break an approved asset invariant

## Production workflow

1. Classify the requested asset.
2. Resolve the visual invariants that must not change.
3. Resolve target use in Godot: scene, control, sprite, animation, icon, background, effect, or concept art.
4. Create an Asset Specification before generation.
5. Build a production-ready image prompt.
6. Run prompt preflight when available:

   `python3 skills/jellycat-art-director/scripts/check_asset_prompt.py <prompt-file>`

7. Generate or edit the image using the available image tool.
8. Run visual QA against `references/qa-checklist.md`.
9. Do not silently replace approved assets. New outputs remain candidates until explicitly adopted.
10. When integrating into Godot, preserve source files and record target path, dimensions, transparency, anchor assumptions, and animation frame order.

## Asset Specification minimum fields

Every production task should resolve as many of these as apply:

- `asset_id`
- `asset_type`
- `purpose`
- `subject`
- `visual_state`
- `target_resolution`
- `aspect_ratio`
- `background_mode`
- `transparency`
- `frame_count`
- `loop_mode`
- `anchor`
- `lighting`
- `palette_notes`
- `material_notes`
- `motion_notes`
- `godot_target`
- `must_preserve`
- `must_avoid`

## Hard constraints

- Preserve JellyCat's recognizable jelly-body + cat identity.
- Do not invent permanent anatomy changes unless explicitly requested.
- Transparent gameplay assets must remain truly transparent.
- Animation frames must use consistent canvas size, scale, subject placement, and anchor.
- Avoid baked-in UI text unless the request explicitly requires text art.
- Avoid generic AI-art clutter, random symbols, fake UI, illegible text, or unnecessary decorative noise.
- Do not combine unrelated production assets into one flattened image when separate files are needed by Godot.
- Do not treat generated details as established game canon automatically.
- Do not overwrite an approved asset without explicit instruction.

## Default output behavior

If an image generation tool is available, produce the asset and perform QA.
If no image generation tool is available, return a production-ready prompt and Asset Specification; never claim an image was generated.

## Visual target

The project should feel healing, immersive, soft, aquatic, and suitable for long-duration desktop viewing. Character readability and gentle motion take priority over decorative complexity.
