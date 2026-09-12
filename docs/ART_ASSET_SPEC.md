# Art Asset Specification

## Visual Direction

JellyCat / 水母喵 should use a cozy pastel underwater fantasy style:

- Soft blue, cyan, lavender, pale teal, and pearl white
- Translucent jelly body
- Soft glow
- Rounded shapes
- Clean silhouette
- Cute but not overly childish
- Calm and therapeutic aquarium mood

## General Rules

- Do not bake text into UI assets.
- Do not include logos or watermarks.
- Character and UI assets should support transparent PNG when needed.
- Center the main subject in the canvas.
- Leave safe transparent margins around characters and effects.
- Keep assets readable at game size.

## v0.1 Art Package Target

Recommended v0.1 art package size: 38 PNG assets.

### Background Assets

| Filename | Size | Transparent | Target Path |
|---|---:|---|---|
| `aquarium_background.png` | 1672 x 941 | No | `assets/backgrounds/` |
| `aquarium_foreground_glass_overlay.png` | 1672 x 941 | Yes | `assets/backgrounds/` |
| `water_light_overlay.png` | 1672 x 941 | Yes | `assets/effects/` |
| `bubble_particle_sheet.png` | 512 or 1024 square | Yes | `assets/effects/` |

### Normal JellyCat Stages

| Filename | Size | Transparent | Target Path |
|---|---:|---|---|
| `normal_jellycat_stage_1.png` | 1024 x 1024 | Yes | `assets/pets/` |
| `normal_jellycat_stage_2.png` | 1024 x 1024 | Yes | `assets/pets/` |
| `normal_jellycat_stage_3.png` | 1024 x 1024 | Yes | `assets/pets/` |
| `normal_jellycat_stage_4.png` | 1024 x 1024 | Yes | `assets/pets/` |
| `normal_jellycat_stage_5.png` | 1024 x 1024 | Yes | `assets/pets/` |

### Egg Assets

| Filename | Size | Transparent | Target Path |
|---|---:|---|---|
| `normal_egg_idle.png` | 1024 x 1024 | Yes | `assets/eggs/` |
| `normal_egg_crack_1.png` | 1024 x 1024 | Yes | `assets/eggs/` |
| `normal_egg_crack_2.png` | 1024 x 1024 | Yes | `assets/eggs/` |
| `normal_egg_hatch_effect.png` | 1024 x 1024 | Yes | `assets/effects/` |

### Bubble Coin Assets

| Filename | Size | Transparent | Target Path |
|---|---:|---|---|
| `bubble_coin_idle.png` | 512 x 512 | Yes | `assets/coins/` |
| `bubble_coin_hover.png` | 512 x 512 | Yes | `assets/coins/` |
| `bubble_coin_collect_effect.png` | 512 x 512 | Yes | `assets/effects/` |
| `bubble_coin_auto_collect_effect.png` | 512 x 512 | Yes | `assets/effects/` |

### Item Icons

| Filename | Size | Transparent | Target Path |
|---|---:|---|---|
| `icon_food_basic.png` | 512 x 512 | Yes | `assets/icons/` |
| `icon_cookie_basic.png` | 512 x 512 | Yes | `assets/icons/` |
| `icon_medicine_basic.png` | 512 x 512 | Yes | `assets/icons/` |

### UI Assets

Use nine-patch/stretch-capable images where appropriate.

| Filename | Target Path |
|---|---|
| `ui_panel_glass.png` | `assets/ui/` |
| `ui_panel_dark_transparent.png` | `assets/ui/` |
| `ui_button_normal.png` | `assets/ui/` |
| `ui_button_hover.png` | `assets/ui/` |
| `ui_button_pressed.png` | `assets/ui/` |
| `ui_button_disabled.png` | `assets/ui/` |
| `ui_progress_bar_bg.png` | `assets/ui/` |
| `ui_progress_bar_fill_hunger.png` | `assets/ui/` |
| `ui_progress_bar_fill_mood.png` | `assets/ui/` |
| `ui_progress_bar_fill_cleanliness.png` | `assets/ui/` |
| `ui_progress_bar_fill_evolution.png` | `assets/ui/` |
| `ui_shop_card.png` | `assets/ui/` |
| `ui_log_panel.png` | `assets/ui/` |
