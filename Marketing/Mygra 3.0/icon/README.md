# Mygra 3.0 icon: flat layers for Icon Composer

Concept D "Quiet": a calm head held in a halo, the halo broken into eight segments. Three flat, opaque layers. Icon Composer shares an icon's layers between its appearances, so there is one set of three layers; only the background changes between Default and Dark.

| Appearance | Background | Layers |
|---|---|---|
| Default | White gradient, `#FFFFFF` (top) to `#E9E8EF` (bottom) | The same three |
| Dark | Black gradient, `#34303D` (top) to `#121015` (bottom) | The same three |
| Mono | The system's (Clear and Tinted) | The same three, rendered without hue |

These are the same backgrounds as Opalite 2.0, so the two icons sit together as a family.

## Layers (`layers/`, back to front)

| File | Shape | Fill |
|---|---|---|
| `1-back-halo` | Eight ring segments around centre (512, 400), inner radius 172, outer 300, one every 45 degrees with 7 degree gaps, one segment centred straight up. One layer, eight shapes | Lilac `#AEA7FF` |
| `2-middle-head` | Circle, radius 150, centre (512, 400) | Mygra purple `#6E60FF` |
| `3-front-shoulders` | Half-disc on a short base, 560 wide, bottom edge at y 870 | Mygra blue `#6CB8F4` |

Each is a single opaque shape on a 1024 x 1024 canvas, already in position, so the files line up when dropped in together. SVG with a PNG copy. Nothing is baked in: no shadows, highlights or glass.

## Reference

- `reference/flat-composite-default.png`, `flat-composite-dark.png`: the layers stacked on each background, no glass, to confirm order and position.
- `reference/mockup-default.png`, `mockup-dark.png`: the chosen design in the rounded icon shape (flat, not Liquid Glass).
- `shared/`: the two backgrounds as images, for reference only. Set the background with Icon Composer's own fill for each appearance.

## Building it in Icon Composer

Starting values, not tried in Icon Composer; adjust by eye.

### Background (the document's fill, set once per appearance)

Select the top of the sidebar (the icon itself), then Fill in the inspector:

| Appearance | Fill | Colour 1 (top) | Colour 2 (bottom) |
|---|---|---|---|
| Default | Gradient, vertical | `#FFFFFF` | `#E9E8EF` |
| Dark | Gradient, vertical | `#34303D` | `#121015` |
| Mono | Leave Automatic | | |

Do not import `shared/background-*` as layers; they are references only.

### Groups (one layer each, top to bottom in the sidebar = front to back)

| Group | Layer file | Liquid Glass | Specular | Translucency | Shadow | Opacity |
|---|---|---|---|---|---|---|
| Shoulders (front) | `3-front-shoulders.svg` | On | On | Off | Chromatic, 50% | 100% |
| Head | `2-middle-head.svg` | On | On | Off | Chromatic, 40% | 100% |
| Halo (back) | `1-back-halo.svg` | On | On | On, 40% | Neutral, 25% | 100% |

- Drag the three SVGs in so each lands in its own group (Icon Composer creates a group per dropped layer; if two end up in one group, drag one out). Order in the sidebar, top to bottom: Shoulders, Head, Halo.
- Keep every layer's own Fill as "Automatic" so it uses the SVG colour (lilac `#AEA7FF`, purple `#6E60FF`, blue `#6CB8F4`).
- Positions are already baked into the SVGs; leave each group's offset at 0 and scale at 100%.
- Halo: translucency lets the background show faintly through the segments so they glow rather than sit flat. If the gaps blur closed, turn Blur down or translucency off.

### Per-appearance tweaks

- **Default (white):** the chromatic shadows can read heavy on white; if so, lower Shoulders and Head to about 30%.
- **Dark:** raise the Halo translucency a little (about 50%) so it does not glare; shadows as in the table.
- **Mono (Clear and Tinted):** check the three still separate. If the head and halo merge, give this appearance's layer fills distinct greys: halo `#7C7C82`, head `#EEEEF2`, shoulders `#B4B4BA`.

### Saving

Save as `MygraIcon.icon` and replace `Apps/Mygra/Mygra/MygraIcon.icon` (the app's icon name is `MygraIcon`). Preview in Icon Composer at the small sizes: the eight gaps should stay visible at 60 px; at 29 px the halo is allowed to read as a ring.
