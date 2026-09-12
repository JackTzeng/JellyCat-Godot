# Asset Production Specification

Before generating a production asset, prepare a compact specification.

## Template

```yaml
asset_id: JC-...
asset_type: sprite | sprite_sheet | background | ui | icon | item | effect | concept
purpose: ...
subject: ...
visual_state: ...
target_resolution: WIDTHxHEIGHT
aspect_ratio: ...
background_mode: transparent | opaque | environment
transparency: required | not_required
frame_count: 1
loop_mode: none | seamless
anchor: center | bottom_center | custom
lighting: ...
palette_notes: ...
material_notes: ...
motion_notes: ...
godot_target: ...
must_preserve:
  - ...
must_avoid:
  - ...
```

## Production prompt structure

A production prompt should normally contain:

1. asset purpose
2. subject and state
3. JellyCat visual identity
4. composition / framing
5. material
6. lighting
7. background / transparency rule
8. target dimensions or ratio
9. animation consistency requirements when relevant
10. negative constraints

## Godot handoff

For finished assets, record:

- source file name
- intended repository path
- pixel dimensions
- alpha / transparency expectation
- import filtering expectation if known
- pivot / anchor assumption
- frame order for sprite sheets
- whether the file is approved, candidate, or experimental

Do not silently infer approval status.
