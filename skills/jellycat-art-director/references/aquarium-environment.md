# Aquarium Environment Standard

## Purpose

The aquarium is both a habitat and the persistent visual stage of the game. It must support observation, interaction, and multiple moving JellyCats.

## Composition

Prefer three readable depth bands:

1. foreground accents: sparse decor, bubbles, glass edge, plants, props
2. midground gameplay zone: primary JellyCat movement space
3. background atmosphere: water depth, tank structure, distant decor, light gradients

Keep the midground open enough for several creatures to overlap minimally.

## Lighting

Use gentle aquatic lighting with soft directional cues. Subtle caustics, gradients, and water diffusion are appropriate. Avoid harsh spotlights unless used for a specific state or event.

## Motion compatibility

Backgrounds should not imply fixed JellyCat positions. Avoid painting permanent character shadows or character-shaped light pools into reusable backgrounds.

## Decorative asset rule

Decor should be modular when practical so it can be placed independently in Godot instead of being irreversibly baked into the background.

## Readability

Interactive drops, coins, food, medicine, cookies, and JellyCats must remain distinguishable against the environment.
