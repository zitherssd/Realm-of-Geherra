# Input System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Foundation — enables all pillars

## Overview

The Input System is the pipeline between the player's input devices (keyboard, mouse, gamepad) and the active game scene. It wraps LÖVE's native input callbacks (`love.keypressed`, `love.mousepressed`, `love.keyreleased`, `love.mousereleased`) into a uniform interface that any scene can consume. As per ADR-0001's Scene Manager pattern, all input events flow: LÖVE callbacks → `Game` dispatcher → `current_scene` handler. The system also provides input state queries (key held, mouse position) for systems that need per-frame polling rather than event-driven input. Supports two resolutions: 1024×768 (primary) and 800×600 (compatible).

## Player Fantasy

The Input System is infrastructure — the player does not engage with it directly. They feel its absence (unresponsive controls, input lag) but not its presence. The goal is zero perceptual overhead: every press feels instant, every click lands exactly where intended. This system exists so that no other system needs to think about *how* input arrives — only *what* to do with it.

## Detailed Design

### Core Rules

1. **Event-driven callbacks**: LÖVE fires `love.keypressed`, `love.keyreleased`, `love.mousepressed`, `love.mousereleased`, `love.wheelmoved` when input events occur. The `Game` object forwards these to the current scene's corresponding method if it exists.

2. **Per-frame polling**: Systems that need held-key state (e.g., continuous movement) call `Input.is_down(action_name)` or `Input.is_mouse_down(button)` each frame. The Input system internally uses `love.keyboard.isDown(scancode)` and `love.mouse.isDown(button)` for real-time state.

3. **Action mapping**: A data file `data/input_map.lua` maps semantic action names to physical keys/scancodes. Example:
   ```lua
   return {
       move_up = {"w", "up"},
       move_down = {"s", "down"},
       move_left = {"a", "left"},
       move_right = {"d", "right"},
       interact = {"e", "space"},
       pause = {"escape", "p"},
       select = {"return", "lctrl"},
       cancel = {"escape", "backspace"},
   }
   ```
   Each action maps to an array of alternative keys. If any mapped key is pressed, the action is active.

4. **Mouse coordinate scaling**: Mouse positions are received in screen-space pixels. The system provides `Input:get_mouse_position()` returning coordinates scaled to the logical resolution (1024×768 or 800×600). When running at a non-standard resolution, LÖVE's automatic scaling is applied.

5. **Gamepad support (partial)**: Gamepad axes and buttons are mapped to the same action names via a separate mapping table. Joystick module is enabled for gamepad input despite physics/touch/video being disabled.

### States and Transitions

The Input System has no internal states — it is stateless between frames. Input state is ephemeral: events fire and are consumed, per-frame polling returns the current hardware state. The only persistent data is the action mapping table.

### Interactions with Other Systems

| System | Data Out | Data In |
|--------|----------|---------|
| All scenes/scene managers | Key press/release events, mouse events | Scene registers which callbacks it implements |
| World Map Navigation | `move_up/down/left/right` polled each frame | Action names mapped to movement vectors |
| Combat System | Mouse click position, key presses for abilities | Action triggers mapped to combat commands |
| Dialogue System | Select, cancel events | Dialogue options advance or cancel |
| Menu System | All navigation input | Menu items respond to select/cancel |

## Formulas

Not applicable. The Input System is event-driven and state-query based — it has no mathematical formulas. All input processing is conditional logic (if key pressed → dispatch event) and direct hardware state queries via LÖVE APIs.

## Edge Cases

- **If no key is mapped to an action**: the action returns `false` for `is_down()` and no events fire. No crash — the action simply does nothing.
- **If two mapped keys are pressed simultaneously**: both are checked independently. If both map to the same action, the action fires once per frame (polling) or once per event (event-driven).
- **If a key is held down**: `love.keypressed` fires once on initial press, then OS repeat handles subsequent presses (via `isrepeat` flag). Systems should use polling for continuous actions (movement), not keypressed events.
- **If the window loses focus**: LÖVE clears all key states. Re-query `love.keyboard.isDown()` on focus gain to sync state.
- **If mouse is at negative coordinates**: Clamp mouse position to `[0, 0]` — `[width, height]`.
- **If gamepad is disconnected mid-play**: Actions mapped only to gamepad return `false`. Keyboard/mouse continue working.
- **At 800×600 resolution**: Mouse coordinate scaling works identically to 1024×768. Logical coordinates map 1:1 with physical pixels at both resolutions.

## Dependencies

The Input System has **zero dependencies** on other game systems — it is a Foundation-layer system. It depends only on LÖVE's built-in input modules (`love.keyboard`, `love.mouse`, `love.joystick`), which are part of the engine, not game systems.

**Depended on by (32 systems):** Every other system in the project depends on the Input System. The primary consumers are:
- World Map Navigation (polled movement input)
- Tactical Combat (mouse clicks, action keys)
- Dialogue System (select, cancel events)
- All Menu/UI systems (navigation, selection)
- Scene Manager (receives forwarded callbacks via ADR-0001 pattern)

## Tuning Knobs

- **Action key mappings** (`data/input_map.lua`): The entire action→key mapping table is data-driven. No code changes needed to rebind keys.
- **Mouse sensitivity**: Scalar multiplier in `data/input_map.lua`. Range: 0.5–2.0. Default: 1.0.
- **Gamepad deadzone**: Per-axis deadzone threshold. Range: 0.0–0.5. Default: 0.2.

## Visual/Audio Requirements

- **No visual requirements.** The Input System has no visible representation.
- **Audio feedback is not handled by the Input System.** Input-triggered sounds (menu clicks, UI beeps) belong to the consuming system's own audio requirements.

## UI Requirements

- **No direct UI.** The Input System does not render UI. However, a future settings screen may surface key rebinding — that UI belongs to a Settings/Options system, not the Input System GDD.
- **Cursor visibility** is managed by the active scene (hide cursor during combat, show during menus). The Input System provides `Input:set_cursor_visible(bool)` and `Input:get_cursor_position()` but ownership of cursor state sits with the scene.

## Acceptance Criteria

- **GIVEN** the player presses the W key, **WHEN** `Input.is_down("move_up")` is called, **THEN** it returns `true`.
- **GIVEN** the player presses the Escape key, **WHEN** the scene's `keypressed` callback fires, **THEN** the event contains `key = "escape"`.
- **GIVEN** the player clicks the left mouse button at pixel (x, y), **WHEN** `Input:get_mouse_position()` is called, **THEN** it returns `(x, y)` scaled to the current logical resolution.
- **GIVEN** a key is held down for 1 second, **WHEN** `Input.is_down("move_up")` is polled 60 times, **THEN** it returns `true` every frame.
- **GIVEN** the window loses focus, **WHEN** focus is regained, **THEN** no phantom held-key state remains.
- **GIVEN** the action map defines `jump = {"space", "up"}`, **WHEN** the player presses either spacebar or up arrow, **THEN** `Input.is_down("jump")` returns `true`.
- **GIVEN** the game runs at 800×600 resolution, **WHEN** the player clicks at any point, **THEN** coordinates returned by `Input:get_mouse_position()` are within `[0, 0]` to `[800, 600]`.
- **GIVEN** the gamepad is connected, **WHEN** `Input.is_down("move_right")` is called with the D-pad right pressed, **THEN** it returns `true`.

## Open Questions

- **Input rebinding UI**: Where does the key rebinding screen live? In a future Settings system, or as part of the Input System's scope? Decision deferred — not needed for MVP.
- **Gamepad support depth**: MVP has partial gamepad (navigation only). Full gamepad support (combat controls, radial menus) is deferred — decide when gamepad scope is defined.
