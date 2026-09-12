# JellyCat UI Visual Standard

## Goal

The UI must support an aquarium-first experience. Controls should feel accessible without making the screen look like a dashboard covering the tank.

## Principles

- keep the aquarium visually dominant
- use compact, soft-edged panels
- maintain clear hierarchy for primary actions
- keep status feedback readable at a glance
- avoid placing every control at the top center
- preserve space for observing multiple JellyCats

## Asset separation

Generate these separately when they are independent Godot controls:

- button background
- icon
- panel frame
- state badge
- item art
- currency art

Do not flatten an entire interactive UI into a single screenshot-style image unless the task is explicitly a mockup.

## States

Interactive UI assets should account for states where relevant:

- normal
- hover / focus
- pressed
- disabled
- selected
- warning

## Text

Prefer rendering text in Godot rather than baking it into generated images. Image generation should normally create text-free UI assets unless decorative lettering is explicitly required.
