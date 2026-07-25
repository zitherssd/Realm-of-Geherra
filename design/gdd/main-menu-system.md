# Main Menu System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Foundation — enables all pillars

## Overview

The Main Menu System is the first scene the player sees. As per ADR-0001's Scene Manager pattern, it is a scene that implements `init()`, `update(dt)`, `draw()`, `keypressed()`, and `mousepressed()` callbacks. It receives input through the Input System's action mapping (`select`, `cancel`, navigation) and renders the title screen with a menu of options. For MVP, the Main Menu provides three options: **New Game** (starts a fresh playthrough), **Load Game** (opens the save selection screen), and **Quit** (exits the application). The menu uses keyboard navigation (arrow keys + select) and mouse clicks.

## Player Fantasy

The Main Menu is a threshold — the player passes through it to reach the world. It should evoke the game's atmosphere (Antediluvian Earth: ancient, mythic, amber-lit) without getting in the way. The fantasy is *anticipation*: the title screen hints at the world beyond. The menu itself is infrastructure — players feel its absence (can't start the game) but not its presence.

## Detailed Design

### Core Rules

1. **Menu State Machine**: The Main Menu has four states — Title, Menu, SaveSelect, Transitioning.
2. **Navigation**: Up/Down arrow keys (or W/S) move the selection highlight. Select/Return activates the highlighted option. Mouse click on an option also activates it. Cancel/Escape does nothing on Title, exits to desktop prompt on Menu.
3. **Visual selection**: The currently highlighted option is visually distinct (amber glow on text, or a gem-facet cursor beside it per the art bible).
4. **New Game**: Creates a new save, initialises world generation, transitions to the gameplay scene.
5. **Load Game**: Transitions to a save selection sub-state showing available save slots.
6. **Quit**: Calls `love.event.quit()`.

### States and Transitions

| State | Entry | Exit | Transitions |
|-------|-------|------|-------------|
| **Title** | Scene starts | Player presses Select/clicks | → Menu |
| **Menu** | After Title or returning from SaveSelect | Player selects option | → SaveSelect (Load), → Gameplay (New Game), → Quit |
| **SaveSelect** | Player selects Load Game | Player picks a save or cancels | → Gameplay (save picked), → Menu (cancel) |
| **Transitioning** | Any option that changes scenes | Fade animation completes | → Target scene (via Scene Manager) |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Input System | Consumes | `select`, `cancel`, `move_up`, `move_down`, mouse click actions |
| Scene Manager | Uses | `Game:change_scene(scene)` to transition to gameplay |
| Save/Load System | Uses | `SaveLoad.list_saves()` for save selection, `SaveLoad.load_game(id)` to load |

## Formulas

Not applicable. The Main Menu System has no mathematical formulas. Menu navigation and selection are state and conditional logic.

## Edge Cases

- **If no save files exist**: Load Game option shows "No saves found" message. Player returns to Menu by pressing Cancel.
- **If the player spams Select**: The first press is processed; subsequent presses are ignored until the transition animation completes or the action resolves.
- **If a save file is corrupted**: SaveSelect shows a warning icon next to the corrupted save. Selecting it shows "Save corrupted — cannot load" and returns to the list.
- **If the game has just been started (no save created yet)**: New Game is the primary option. Load Game is dimmed/greyed out if no saves exist.
- **If the player presses mouse during Title animation**: The animation skips to completion and transitions to Menu immediately.
- **At 800×600 resolution**: All menu elements scale and reposition to fit the smaller canvas. Text and button sizes remain proportional.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S01 Input System | Hard (required) | Action-based: `select`, `cancel`, `move_up`, `move_down`, mouse position/click |
| S02 Save/Load System | Hard (required) | `SaveLoad.list_saves()` → table of save metadata. `SaveLoad.load_game(id)` → save data. `SaveLoad.new_game()` → initialises fresh state. |
| Scene Manager (ADR-0001) | Hard (required) | `Game:change_scene(scene)` for transitions |

**Depended on by:** S02 Save/Load System (load game entry point), S04 Audio System (menu music trigger)

## Tuning Knobs

- **Menu option labels** (`data/strings.lua`): All text displayed in the menu is data-driven.
- **Title animation duration**: Float in seconds. Range: 0.5–4.0. Default: 2.0.
- **Transition fade duration**: Float in seconds. Range: 0.1–1.0. Default: 0.3.
- **Highlight colour**: RGB value for active selection glow. Default: Amber `235, 165, 35`.

## Visual/Audio Requirements

- **Title screen art**: A full-screen pixel-art illustration of the Antediluvian Earth setting — cyclopean ruins silhouetted against an amber sky, with faint gemstone glows. Must work at 1024×768 and 800×600.
- **Menu music**: A single looping ambient track that evokes the ancient, mythic atmosphere (warm, droning, bronze-age instrumentation).
- **Selection sound**: A short, satisfying chime (gemstone resonance) when the player moves between options or selects one.
- **Transition effect**: A brief fade-to-black (0.3s) between menu states and when transitioning to the game scene.

## UI Requirements

- **Title screen**: Game logo (pixel-art title "Geherra Realms: Warband") centred. Below: "Press Select" or "Click to begin" text that fades in/out slowly.
- **Menu layout**: Vertically centred list of options on the left side of the screen. Each option is a shield-shaped or scarab-shaped button (per the art bible's shape language).
- **Selection indicator**: A glowing gem-facet cursor (amber) beside the currently selected option. On hover (mouse), the cursor tracks to the hovered option.
- **Save select screen**: Grid of save slots (3–6 slots), each showing: character name, level, play time, location. Empty slots show "Empty" text.
- **Typography**: Custom pixel font (body 6×8, headers 8×10) per the art bible. Text uses Parchment colour `230, 215, 185` on darker backgrounds.

## Acceptance Criteria

- **GIVEN** the game starts, **WHEN** the Main Menu scene loads, **THEN** the title screen is displayed with the game logo and "Press Select" prompt.
- **GIVEN** the player presses Select on the Title screen, **WHEN** the input is processed, **THEN** the menu appears with New Game, Load Game, and Quit options.
- **GIVEN** the player presses Up or Down, **WHEN** navigating the menu, **THEN** the selection highlight moves to the adjacent option. Wrap-around from first to last and vice versa.
- **GIVEN** New Game is highlighted, **WHEN** the player presses Select, **THEN** the game transitions to a new gameplay session.
- **GIVEN** Load Game is highlighted, **WHEN** the player presses Select, **THEN** the save selection screen appears showing available saves.
- **GIVEN** Quit is highlighted, **WHEN** the player presses Select, **THEN** the application exits.
- **GIVEN** there are no save files, **WHEN** Load Game is selected, **THEN** a "No saves found" message is shown instead of save slots.
- **GIVEN** the game runs at 800×600, **WHEN** the menu is rendered, **THEN** all elements are proportionally scaled and functional.

## Open Questions

- **Title art asset**: Will the title screen illustration be a separate full-screen asset or composed from existing environment tiles? Decision deferred — depends on art pipeline capacity.
- **Save slots count**: How many save slots for MVP? Proposed: 3 (enough for testing without UI clutter). Finalise when Save/Load System is designed.
