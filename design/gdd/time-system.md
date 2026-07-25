# Time System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Preparation Over Reflexes

## Overview

The Time System tracks the passage of time in the game world. Time advances only while the player is active on the world map (moving, waiting, or performing time-consuming actions). It pauses in menus, dialogue, town scenes, and combat. A full day cycle lasts approximately 16 seconds of real time — night is shorter than day. The system uses 8 named time periods instead of clock times; the player knows the current period (e.g., "Highsun" or "Gloamhour") but never an exact hour. The system tracks total game days elapsed for quest timing, faction events, and save data.

## Player Fantasy

The world breathes through its named hours. You set out at *Firstlight*, crest the ridge at *Highsun*, spot enemy campfires as *Dusktide* falls. The player learns to read the sky — "If I push through this forest, I'll reach the town by *Falling sun* — but if I stop to explore these ruins, I'll be travelling in *Gloamhour*." Night (Stilldark) is shorter than day, but deep and dangerous: different creatures emerge, other parties are harder to spot, the world is cloaked in blue.

## Detailed Design

### Core Rules

1. **Time advancement**: Time advances only while the player is active on the world map. Activities that advance time:
   - Moving on the world map (time passes at a rate proportional to distance travelled)
   - Waiting/resting at a location (time advances by the specified duration)
   - Performing time-consuming location actions (resting at a geyser, exploring a crypt)
   - Time does NOT advance in: menus, dialogue, combat scenes, town/location interior scenes

2. **Named time periods** (8 periods, each 3 in-game hours, but different real-time durations):

   | Period | In-game Hours | Real-time (16s cycle) | Character |
   |--------|---------------|----------------------|-----------|
   | Stilldark | 0–3 | 2.0s | Deep night, darkest hour |
   | Lowlight | 3–6 | 2.0s | Pre-dawn glow, first emergence from darkness |
   | Firstlight | 6–9 | 2.0s | Morning sun, warm amber light |
   | Highsun | 9–12 | 2.0s | Brightest, full daylight, warm palette |
   | Suncrest | 12–15 | 2.0s | Afternoon, golden light |
   | Falling sun | 15–18 | 2.0s | Late afternoon, long shadows |
   | Dusktide | 18–21 | 2.0s | Evening, orange fading, light decreasing |
   | Gloamhour | 21–24 | 2.0s | Twilight, blue encroaching, night begins |

   Night periods (**Stilldark** + **Gloamhour**): 4 seconds total (25%)
   Day periods (**Lowlight** through **Dusktide**): 12 seconds total (75%)
   *Night is shorter than day.*

3. **Time units**: The system uses two representations:
   - **Game days**: Integer counter. Increments after 8 full cycles. Used for quest timing and save data.
   - **Time period**: String — one of the 8 named periods. This is what the player sees.

4. **The player never sees exact time**. The HUD shows the current period name and an icon (sun/moon position). The player estimates duration from context — "I've been travelling through *Falling sun* and *Dusktide*, night is coming soon."

5. **Visibility at night**: During Stilldark, `visibility_modifier = 0.4`. During Gloamhour, `visibility_modifier = 0.6` (twilight — not as dark). All day periods: `visibility_modifier = 1.0`.

6. **Night encounters**: Stilldark and Gloamhour use `night_encounter_table` per biome. Day periods (Lowlight through Dusktide) use standard encounter tables. Dawn/dusk-adjacent periods (Lowlight, Dusktide) may sample from both tables.

7. **Waiting**: The player can wait at a location or on the world map (if safe). Waiting advances time in period increments — a UI shows which period they'll arrive at. Maximum wait: 8 periods (one full cycle).

8. **Time paused indicator**: When time is paused (menus, dialogue, combat), the current period name remains displayed but does not advance.

### States and Transitions

| Phase | Duration | Entry | Exit |
|-------|----------|-------|------|
| Dawn | ~1s | Night → time threshold | → Day |
| Day | ~8s | Dawn | → Dusk |
| Dusk | ~1s | Day → time threshold | → Night |
| Night | ~8s | Dusk | → Dawn |

Transitions (dawn/dusk) use a 1-second lerp for both visual tint and gameplay parameters (visibility, encounter tables).

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| World Map Navigation | Provides | `get_day_phase()` → current phase for visibility calculations |
| Party Encounter System | Provides | `is_night()` → bool for encounter table selection. `get_visibility_modifier()` → float. |
| Biome System | Provides | Night encounter tables per biome |
| Visual/Rendering (blue tint) | Provides | `get_night_tint()` → `{r, g, b, a}` for post-processing overlay |
| Save/Load System | Provides | `game_days`, `total_time_elapsed` for save data |
| Location/Town System | Provides | Time passes while resting at geysers or waiting in towns |

## Formulas

**Time period determination:**

`cycle_time = total_world_map_time % 16` (16-second cycle)

| cycle_time range | Period | Type |
|------------------|--------|------|
| 0–2 | Stilldark | Night |
| 2–4 | Lowlight | Day (dawn-adjacent) |
| 4–6 | Firstlight | Day |
| 6–8 | Highsun | Day |
| 8–10 | Suncrest | Day |
| 10–12 | Falling sun | Day |
| 12–14 | Dusktide | Day (dusk-adjacent) |
| 14–16 | Gloamhour | Night |

**Visibility at night:**

`effective_visibility = base_visibility * night_visibility_multiplier`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Cycle time | `cycle_time` | float | 0–16 | Current position in day cycle in seconds |
| Total world map time | `total_world_map_time` | float | 0+ | Accumulated active time on world map |
| Night visibility (Stilldark) | `night_visibility` | float | 0.4 | Visibility reduction in deep night |
| Night visibility (Gloamhour) | `gloam_visibility` | float | 0.6 | Visibility reduction in twilight |
| Game days | `game_days` | int | 0+ | Integer days elapsed |

## Edge Cases

- **If the player is in a biome with no night encounter table**: Fall back to the day encounter table. Night still affects visibility.
- **If the player transitions between biomes during a period change**: Both transitions complete independently.
- **If the player enters combat exactly on a period boundary**: The current period is locked for the duration of combat. Time does not advance in combat.
- **If the player waits through a full cycle**: Time advances normally. Visuals skip to the target period instantly.
- **If the player saves during any period**: The exact `cycle_time` is saved. On load, the period resumes from the saved position.
- **If the current period is unknown (initial game start)**: Default to Firstlight (day start).

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S01 Input System | Hard | Detects when player is actively moving (time advances) vs. paused |
| S06 Biome System | Soft | Night encounter tables per biome |

**Depended on by:** World Map Navigation (visibility), Party Encounter System (encounter selection), Visual/Rendering Layer (night tint).

## Tuning Knobs

- **Cycle duration**: Float seconds. Default: 16. Range: 8–60. Total day cycle length.
- **Period durations**: Each period individually configurable as a fraction of the total cycle. Default: all 1/8.
- **Night visibility (Stilldark)**: Float 0.0–1.0. Default: 0.4.
- **Night visibility (Gloamhour)**: Float 0.0–1.0. Default: 0.6.
- **Night tint opacity**: Float 0.0–1.0. Default: 0.3.
- **Wait max periods**: Integer. Default: 8. Maximum periods the player can wait in one action.

## Visual/Audio Requirements

- **Night blue tint**: A full-screen blue overlay (`{0, 0, 0.3, opacity}`) applied when `is_night() = true`. Opacity ramps during dawn/dusk transitions.
- **Dawn/dusk orange tint**: Warm orange overlay during transitions. Composited with the night/day palette.
- **Sky colour shift**: The sky/ambient colour shifts through the day phases (warm amber at dawn, pale blue at day, orange at dusk, deep indigo at night).
- **Audio shift**: Ambient audio may shift subtly at night (crickets, owl hoots replacing bird calls). Handled by Audio/Music System reading `day_phase`.

## UI Requirements

- **Time indicator**: A small sundial, moon phase, or hourglass icon in the HUD showing current day phase and game time. (HUD system, not Time System UI.)
- **Wait UI**: A simple slider or increment selector showing how long to wait, with a preview of the resulting time of day.

## Acceptance Criteria

- **GIVEN** the player is moving on the world map, **WHEN** time advances, **THEN** the period cycles through all 8 named periods in order.
- **GIVEN** the player is in a menu, **WHEN** time is checked, **THEN** no time has passed.
- **GIVEN** it is Stilldark, **WHEN** `get_visibility_modifier()` is called, **THEN** it returns 0.4.
- **GIVEN** it is Highsun, **WHEN** `get_visibility_modifier()` is called, **THEN** it returns 1.0.
- **GIVEN** it is Stilldark, **WHEN** the blue tint overlay is queried, **THEN** the alpha is at full night opacity.
- **GIVEN** the player waits for 4 periods on the world map, **WHEN** the wait completes, **THEN** the current period has advanced by 4 positions.
- **GIVEN** the player enters combat, **WHEN** time is checked during combat, **THEN** no time has advanced.
- **GIVEN** the game is saved during Falling sun and loaded, **WHEN** the save is loaded, **THEN** the period resumes at Falling sun.
- **GIVEN** the player sees the time display, **WHEN** the HUD is visible, **THEN** the period name (e.g., "Highsun") is shown, never an exact hour.

## Open Questions

- **Time display format**: Period name + sun/moon icon shown in HUD. Deferred to HUD design.
- **Encounter table blending**: During Lowlight and Dusktide (dawn/dusk-adjacent), both day and night encounters may be possible. Confirmed in design.
