# Time UI

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Preparation Over Reflexes

## Overview

The Time UI displays the current time period and game day to the player. It reads from the Time System (S07) and presents the information as a small HUD element showing the current period name (e.g., "Highsun", "Gloamhour", "Stilldark") with a corresponding sun/moon icon. The player never sees an exact clock time — only the poetic period names. A day counter shows how many game days have passed.

## Player Fantasy

You read the sky, not a clock. "Stilldark" tells you everything you need to know — it's the deepest part of night, visibility is low, dangerous creatures are abroad. "Highsun" means you're in the bright heart of day, safe and fast. The time display is information, but it's also atmosphere — it immerses you in the world's rhythm.

## Detailed Design

### Core Rules

1. **Display elements** (shown as a single compact HUD element):
   - **Period name**: The current time period (e.g., "Highsun", "Gloamhour")
   - **Period icon**: A small sun/moon icon showing the sun's position (sun at zenith for Highsun, crescent moon for Gloamhour, full moon for Stilldark, rising sun for Firstlight, etc.)
   - **Day counter**: "Day 3" — displayed less prominently below the period name

2. **Data source**: Reads from S07 Time System:
   - `get_current_period()` → string (e.g., "Highsun")
   - `get_game_day()` → integer

3. **Update timing**: The display updates in real-time as time periods change on the world map. Smooth transition between period names (instant) and icons (icon swap).

4. **Position**: Top-centre or top-right of the HUD, near the minimap but visually distinct. Compact enough to not obstruct the game view.

5. **Period icon designs** (16×16px):
   - Stilldark: Full moon + two stars
   - Lowlight: Crescent moon, horizon glow
   - Firstlight: Sun half-rising, rays
   - Highsun: Sun at zenith, full rays
   - Suncrest: Sun slightly past zenith
   - Falling sun: Sun descending, longer rays
   - Dusktide: Sun half-set, orange glow
   - Gloamhour: Thin crescent, single star

6. **Colour coding**: The period name text is tinted to match the period's mood:
   - Night periods (Stilldark, Gloamhour): Deep indigo/blue text
   - Dawn/dusk (Lowlight, Dusktide): Warm orange/amber text
   - Day periods (Firstlight through Falling sun): Warm gold/white text

### States and Transitions

| State | Description |
|-------|-------------|
| **Visible** | Default. Time display is shown on the HUD. |
| **Hidden** | Time display hidden (inside locations, menus, combat). Not needed in those contexts. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S07 Time System | Reads | `get_current_period()`, `get_game_day()` |

## Formulas

No formulas. Pure display logic.

## Edge Cases

- **If the player is in a location or combat**: Time UI is hidden. Time does not advance in those contexts.
- **If the game day resets (wraps to 0)**: Day counter should never reset — it increments monotonically.
- **If the period icon asset is missing**: Fall back to text-only display. The period name still shows.
- **At 800×600 resolution**: The Time UI scales with the rest of the HUD. Slightly smaller but still readable.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S07 Time System | Hard | `get_current_period()`, `get_game_day()` |

**Depended on by:** (presentation only)

## Tuning Knobs

- **Display position**: Screen coordinate. Default: top-right, below minimap.
- **Text colour**: Per-period configurable. Defaults as described in Core Rules.
- **Font size**: Body font for period name (8×10), smaller for day counter (6×8).
- **Icon size**: 16×16px per period icon. Configurable to 12×12 for smaller HUD.

## Visual/Audio Requirements

- **Period icons**: 16×16px pixel-art icons per period. Each icon must clearly communicate the time of day at a glance.
- **Period name text**: Custom pixel font, coloured per period, with a subtle glow on night periods (Stilldark, Gloamhour).
- **Day counter**: Smaller text below the period name in parchment colour.
- **No audio requirements.** The Time UI is silent. (Time period changes may trigger ambient audio shifts via S03 Audio System.)

## UI Requirements

- **HUD element**: Compact, top-right area. Three lines or a single line with icon+text.
- **Layout options**:
  - Vertical: [icon] [period name] / [Day X]
  - Horizontal: [icon] [period name] — [Day X]
  - Preferred: vertical, minimal space.
- **Period transition**: When the period changes, a brief subtle pulse or icon swap animation (0.3s). Not intrusive.

## Acceptance Criteria

- **GIVEN** it is Highsun, **WHEN** the HUD is visible, **THEN** the Time UI shows "Highsun" with the sun-at-zenith icon.
- **GIVEN** it is Stilldark, **WHEN** the HUD is visible, **THEN** the Time UI shows "Stilldark" with the full moon icon, in deep indigo text.
- **GIVEN** the player enters a location, **WHEN** the location scene loads, **THEN** the Time UI is hidden.
- **GIVEN** it is game day 5, **WHEN** the Time UI is visible, **THEN** "Day 5" is displayed below the period name.
- **GIVEN** the period changes from Day to Night, **WHEN** the transition occurs, **THEN** the Time UI updates with a brief animation.
- **GIVEN** the game is at 800×600 resolution, **WHEN** the Time UI is rendered, **THEN** it scales appropriately.

## Open Questions

- **Period transition animation**: Should the icon animate smoothly (sun sets across the icon) or swap instantly? Proposed: instant icon swap with a brief glow pulse. Smooth animation would be nice but adds art cost for 8×16px icon sets. Deferred to polish.
- **Tooltip on hover**: Should hovering over the Time UI show a tooltip with more detail? Proposed: not needed for MVP. The period name is self-explanatory.
