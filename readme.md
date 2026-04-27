# Pirate TRPG Foundation (Godot)

This foundation now supports a pirate-themed game loop with three combat contexts:
- Ship-to-ship turn-based combat (cannons and boarding attempts).
- Boarding tactical combat (defend or assault on deck).
- Town assault tactical combat (prototype entry point).

It also includes an auto-travel Caribbean world map inspired by `Sid Meier's Pirates!`.

## Current Gameplay Loop
1. Start on the Caribbean map.
2. Click a port to auto-sail.
3. Random encounter can trigger ship combat.
4. Ship combat can lead into boarding tactical combat.
5. Successful defense can return initiative and allow a counter-assault.

## Controls
- **World map**
  - **Left click port**: Set auto-sail destination.
- **Ship combat**
  - **Enter (`ui_accept`)**: Fire cannons.
  - **Space (`ui_select`)**: Attempt boarding.
- **Tactical combat (boarding/town assault prototype)**
  - **Left click**: Select/move unit.
  - **Left click adjacent enemy**: Melee attack.
  - **Enter (`ui_accept`)**: End turn.
- **Debug scenario shortcut**
  - **Page Down (`ui_page_down`)**: Start town assault prototype.

## Project Layout
- `scenes/main.tscn` - Main scene with all mode systems.
- `scripts/game.gd` - Top-level mode routing and encounter flow.
- `scripts/game_flow.gd` - Global mode/combat-type state.
- `scripts/world_map.gd` - Caribbean auto-travel and encounter triggers.
- `data/caribbean_land.json` - Imported real coastline polygons.
- `data/wind_tiles_monthly.json` - Monthly wind speed/direction by map tile.
- `tools/import_caribbean_land.py` - Natural Earth -> game polygon importer.
- `tools/build_wind_tiles.py` - NASA POWER climatology -> wind tile grid.
- `scripts/ship_battle.gd` - Naval turn phases + boarding transition.
- `scripts/grid.gd` - Tactical grid rendering/helpers.
- `scripts/unit.gd` - Tactical unit data and visuals.
- `scripts/pathfinder.gd` - Reachable cell flood-fill.
- `scripts/turn_manager.gd` - Tactical team turns.

## Real Map Data Pipeline
- Coastlines now come from Natural Earth (`ne_50m_land`) rather than hand-authored polygons.
- Rebuild coastline data with:
  - `python3 tools/import_caribbean_land.py`
- Runtime automatically loads `res://data/caribbean_land.json` if present.

## Wind Data Pipeline
- Monthly wind climatology comes from NASA POWER (`WS10M`, `WD10M`) at tile centers.
- Build wind tiles with:
  - `python3 tools/build_wind_tiles.py --cols 12 --rows 8`
- Output includes per-tile monthly averages (`speed_m_s`, `direction_deg`) for months `01`-`12`.

## Boarding Rules (Current Prototype)
- Attacker wins by defeating all defenders or occupying the layout's helm objective tile.
- Defender wins by defeating all attackers or surviving 3 defender rounds.
- Successful defense returns to naval combat with counter-boarding opportunity.
- Boarding maps now include deck obstacles, gangplank entry tiles, and a chokepoint lane to create close-quarters fights.
- Boarding encounter now randomly selects one of three ship layouts: `sloop`, `brig`, or `frigate`.
- Spawn points are now layout-specific, with attackers and defenders entering from different positions per ship class.
- Spawn validation fallback is enabled: if a preferred spawn is blocked or occupied, crew auto-deploy to the nearest valid tile.

## Next Steps
- Expand boarding objective tiles beyond a single helm control point.
- Add cannon arcs, range bands, sail state, and wind in ship combat.
- Build dedicated town assault maps with defenders and objective points.
- Persist campaign state (fleet, cargo, crew morale, reputation, ports).
