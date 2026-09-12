# JellyCat Animation Standard

## Default animation character

JellyCat movement should feel buoyant, soft, delayed, and low-stress.

## Idle float

Recommended first implementation:

- 6 to 8 frames for hand-authored sprite animation, or equivalent key poses for interpolation
- seamless loop
- subtle vertical drift
- very small body squash / stretch
- tentacles lag behind body movement
- no sudden acceleration
- face remains readable

## Frame consistency

All frames in one animation set must preserve:

- identical canvas dimensions
- identical nominal scale
- stable anchor / pivot
- stable camera and orientation
- controlled centroid drift
- consistent lighting direction
- consistent palette and material

Unintentional positional jitter is a failure.

## Motion families

Potential animation families:

- idle_float
- swim_left / swim_right
- touch_react
- eat
- happy
- sick_idle
- sleep
- collect_coin reaction
- evolve

Do not create all families unless requested. Build one verified loop before expanding.

## Transparent sprite rule

Animation sprites intended for gameplay compositing must use a transparent background with no baked aquarium scenery, fake shadows, or frame borders.

## Multi-character performance awareness

Because several JellyCats may move simultaneously, avoid effects that require excessively large sprite canvases or huge overdraw unless the feature explicitly justifies it.
