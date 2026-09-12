# JellyCat / 水母喵 Game Design

## Core Pitch

JellyCat / 水母喵 is a cozy 2D aquarium virtual pet game. The player cares for a cute jellyfish-cat creature floating in a dreamy aquarium.

The game should feel quiet, therapeutic, soft, and low-pressure. The aquarium view and the JellyCat itself are the emotional center of the game.

## Current Version

`v0.1.0 Aquarium Core Prototype`

## Core Loop

```text
Open game
→ see JellyCat in aquarium
→ feed / touch / clean / give medicine
→ JellyCat mood and growth improve
→ happy JellyCat produces Bubble Coins
→ use coins to buy items
→ gain enough growth EXP
→ evolve to the next stage
```

## v0.1 Gameplay Scope

- One main JellyCat
- One active aquarium
- Egg selection
- Hatch by tapping the egg 10 times
- Care actions: Feed, Cookie, Touch, Clean, Medicine
- Five evolution stages
- Bubble Coin generation, pickup, and auto-collect
- Shop for basic consumables
- Daily free food safeguard
- Local save/load
- Runtime Log for development validation

## Current Care Actions

| Action | Intended Effect |
|---|---|
| Feed | Consumes `food_basic`, increases hunger, mood, and growth EXP |
| Cookie | Consumes `cookie_basic`, increases mood and growth EXP |
| Touch | Increases mood and limited daily growth EXP |
| Clean | Restores cleanliness to 100 |
| Medicine | Cures sick JellyCat if medicine is available |
| Evolve | Advances stage when growth EXP requirement is met |
| Daily Food | Grants one free food per day to prevent deadlock |

## Evolution

The normal JellyCat currently uses five stages:

1. Stage 1: infant
2. Stage 2: small growth form
3. Stage 3: mid-growth form
4. Stage 4: mature form
5. Stage 5: max stage

Stage 5 must be treated as max stage and must never try to read missing next-stage data.

## Bubble Coin

Bubble Coins are the early economy loop:

- A happy, healthy JellyCat can generate coin bubbles.
- The player can click them manually.
- Unclicked bubbles auto-collect after a short time.
- Offline income is capped and settled directly.
- Evolution rewards are settled directly.

## UI Layout Direction

The aquarium should preserve a clean central viewing area:

- Center: main JellyCat
- Left top: status panel
- Left bottom: Runtime Log during development
- Right side: inventory / action buttons
- UI should not cover the JellyCat or break the aquarium mood

## Main JellyCat Motion

Planned for v0.1.1:

- Slow idle floating
- Light breathing / pulsing
- Subtle rotation
- Gentle reaction on successful touch, feed, cookie, medicine, and evolve
- Sick state moves more slowly and appears slightly muted

Animation is visual-only and must not modify save data or gameplay values.

## Ambient JellyCats

Planned after the main JellyCat motion is stable:

- Multiple background JellyCats may float in the tank.
- They are visual-only ambient actors.
- They do not have hunger, mood, health, EXP, evolution, inventory, or save state.
- The main JellyCat remains the only interactable pet in early versions.

## Out of Scope for v0.1

- True multi-pet save system
- Breeding / resonance hatching
- Mini-games
- Cloud save
- Login
- Ads
- Payment integration
- Mobile-specific UI overhaul
- Full content expansion
