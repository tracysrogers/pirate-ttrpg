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
- `scenes/main_v2.tscn` - Main scene with all mode systems.
- `scripts/core/game_main.gd` - Top-level mode routing, UI, and encounter flow.
- `scripts/game_logic_state.gd` - Global mode/combat-type state.
- `scripts/map_system.gd` - Caribbean auto-travel and encounter triggers.
- `data/caribbean_land.json` - Imported real coastline polygons.
- `data/wind_tiles_monthly.json` - Monthly wind speed/direction by map tile.
- `tools/import_caribbean_land.py` - Natural Earth -> game polygon importer.
- `tools/build_wind_tiles.py` - NASA POWER climatology -> wind tile grid.
- `scripts/ship_combat/` - Rebuilt plan-then-execute naval combat (manager, ship unit/data, projectile, iso helpers).
- `scripts/previous_ship_combat/` - Legacy naval combat kept for reference.
- `scripts/core/tactical_combat_v3.gd` - Boarding/town-assault tactical combat.
- `scripts/grid.gd` - Tactical grid rendering/helpers.
- `scripts/core/combat_unit.gd` - Tactical unit data and visuals.
- `scripts/pathfinder.gd` - Reachable cell flood-fill.
- `scripts/core/combat_turn_manager.gd` - Tactical team turns.

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


## 4/29 notes:
Still called out in readme (or only prototype)
Boarding: more than one objective type (not only helm-style control).
Ship combat: cannon arcs / range bands, sail state, and wind wired into naval turns the way they are for the world map (readme still lists this).
Town assault: real maps, defender setups, and objectives—not just a demo entry from the port flow.
Docs: refresh readme so “Next steps” matches what’s shipped (save, career, politics, etc.).
Classic “Pirates!” depth you don’t have yet
Strategic layer: multiple ships / fleet, prizes, repairs, crew splits, clearer loot from naval wins feeding the economy.
Living world: your slow wars are a start; still light on missions (escort, blockade, hunt X), smuggling, and time-limited port prices or shortages.
Character: duels, tavern games, rank with nations beyond a rep number, named rivals.
Exploration: discoveries that aren’t only port + scripted treasure/family beats.
Presentation & feel
Art/audio: port “illustration” placeholders, no systematic SFX/music called out in repo.
Onboarding: one guided run through sail → encounter → dock → trade would help; systems are dense.
Polish / accessibility
Rebinds, UI scale, colorblind-safe route/wind/faction colors, save slots if you stay single-file save.
Bottom line
You have a strong vertical slice: map + wind + politics skeleton + naval/boarding/town hooks + career loop + save. What’s missing most for a “full game” feel is deeper naval and town content, richer economy and missions, and presentation/onboarding—not more core modes.


## CC Assets
Scallywag Ships from Foozle
https://foozlecc.itch.io/scallywag-ships

Scallywag Pirates from Foozle
https://foozlecc.itch.io/scallywag-pirates

3D Stylized Pirate Island Props Pack
https://adobemano.itch.io/3d-stylized-pirate-island-props-pack