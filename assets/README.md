# JellyCat Asset Structure

- `backgrounds/`: aquarium and scene backgrounds.
- `jellycats/<species_id>/stages/`: one PNG for each evolution stage.
- `eggs/<species_id>/`: egg art for each species.
- `items/`: food, cookie, medicine, and future inventory art.
- `ui/icons/`: interface icons.
- `ui/panels/`: panel and frame textures.
- `audio/music/`: background music.
- `audio/sfx/`: interaction sound effects.
- `effects/`: particles and effect textures.

JellyCat stage files follow this convention:

`assets/jellycats/<species_id>/stages/stage_<number>.png`

Example:

`assets/jellycats/normal_jellycat/stages/stage_3.png`

Use the same `species_id` in `data/species.json`, `data/evolution.json`, and the asset folder name.
