# JellyCat / 水母喵 Technical Architecture

## Project Type

- Engine: Godot 4.x
- Language: GDScript
- Save: local JSON
- Current target: Android APK
- Workflow: text/source editing, headless checks, CLI export, physical-device acceptance
- Deferred target: Windows packaging

## Recommended Structure

```text
JellyCat-Godot/
├─ project.godot
├─ scenes/
│  ├─ boot/
│  ├─ title/
│  ├─ egg_select/
│  ├─ hatch/
│  ├─ aquarium/
│  ├─ pet/
│  └─ ui/
├─ scripts/
│  ├─ core/
│  ├─ systems/
│  ├─ controllers/
│  └─ debug/
├─ data/
├─ assets/
│  ├─ backgrounds/
│  ├─ pets/
│  ├─ eggs/
│  ├─ coins/
│  ├─ icons/
│  ├─ effects/
│  └─ ui/
├─ docs/
└─ exports/
```

## Scene Flow

```text
Boot
→ load version
→ load data tables
→ load save
→ route to Title / Hatch / Aquarium
```

### Expected Scenes

- `res://scenes/boot/boot.tscn`
- `res://scenes/title/title.tscn`
- `res://scenes/egg_select/egg_select.tscn`
- `res://scenes/hatch/hatch.tscn`
- `res://scenes/aquarium/aquarium.tscn`
- `res://scenes/pet/jellycat_actor.tscn`
- UI scenes under `res://scenes/ui/`

## Core Autoloads

Expected existing or planned autoloads:

- `GameApp`
- `GameState`
- `SceneRouter`
- `SaveManager`
- `VersionManager`
- `TimeManager`
- `RuntimeLogger`

## Systems

Expected system responsibilities:

| System | Responsibility |
|---|---|
| `CareSystem` | Feed, cookie, touch, clean, medicine state changes |
| `EvolutionSystem` | Stage progression and max-stage guard |
| `CurrencySystem` | Bubble coin mutations and rewards |
| `ShopSystem` | Item purchase validation and transaction mutation |
| `CoinDropSystem` | Bubble coin pickup spawning / pickup / auto-collect |
| `InventorySystem` | Item count reads and writes |
| `EggSystem` | Egg selection state |
| `HatchSystem` | Hatch tap progression |

## Main Save Model

Current save model should remain single-main-pet during v0.1:

```json
{
  "save_version": "0.1.0",
  "player": {"player_id": "local_player", "created_at": ""},
  "egg": null,
  "jellycat": null,
  "currency": {"bubble_coin": 20},
  "inventory": {
    "food_basic": 5,
    "cookie_basic": 3,
    "medicine_basic": 1
  },
  "unlocked_species": ["normal_jellycat"],
  "timestamps": {"last_saved_at": "", "last_opened_at": ""},
  "care_stats": {
    "touch_growth_exp_today": 0,
    "touch_exp_date": "",
    "last_touch_effect_at": 0.0,
    "touch_cap_notified_date": ""
  },
  "daily_claim": {"last_free_food_date": ""}
}
```

## Controller Rules

Aquarium controller should distinguish successful state changes from no-op attempts:

- `changed == true`: refresh UI and request save
- `changed == false`: no save; no `Aquarium UI refreshed` log
- Button actions should use debounce to reduce repeated accidental input
- Repeated no-op/error logs should be throttled

## Visual Layering

Recommended z-order:

| Layer | z_index |
|---|---:|
| Background | 0 |
| Ambient visual actors | 10 |
| Main JellyCat | 20 |
| Coin bubbles | 30 |
| UI | 100 |

## Motion Architecture

`JellyCatActor` should own visual-only motion:

- idle floating
- breathing / pulsing
- subtle rotation
- successful action reactions
- sick-state visual adjustment

Animation state must not be persisted.

## Export Policy

- First app target: Android debug APK
- Godot GUI/editor is not required for development or release validation
- Windows packaging is deferred until after APK-ready acceptance
- Exported builds should be attached to GitHub Releases, not committed
- Signing keys must never be committed
