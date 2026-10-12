# Palworld Minimap

A lightweight native minimap for [Palworld Mods](../palworld-mods). Original Lua
modules use the shared runtime API and the licensed game's own map textures.
There are no external mod assets, loader binaries or personal settings here.

## Use

Open **Options → Mods → Manage mods → Minimap** in the game. Installation,
uninstallation and settings apply without a restart. Select **Minimap** on the
Mods page to enable it or change its settings.

- Square or round map, opacity, size, position and range.
- Camera-follow orientation and larger player/point-of-interest icons.
- Replicated guild members inside the visible map area, without name labels.
- Bosses, fast-travel points and dungeons controlled independently.
- Defeated bosses hidden by default; distinct progress icons when shown.
- Routes to game-map markers where the game's navigation data is available.
- Loading/fade suppression, mount-aware position and dungeon trail support.

Dungeon trails are supported; a complete room-and-wall floor plan is not part
of this release. A route cannot cross unloaded or unavailable navigation data.
Guild visibility depends on information replicated to the client by the host.

## Develop

The sibling `palworld-mods` repository packages this repository's manifest and
`src/*.lua` into its offline catalogue. Modules cover geometry, rendering,
rosters, POIs, routes, loading, dungeon trails and validated settings.

```sh
python3 scripts/verify.py
lua tests/geometry.lua
```

No user data is required to build or test. Settings live in the runtime's local
Application Support directory. CPU work is sampled and cached, but cold asset
loads and UMG creation can still cause isolated frame-time spikes.
