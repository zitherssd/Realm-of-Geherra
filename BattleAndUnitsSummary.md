# Battle System & Unit Architecture Summary

This document provides an overview of the files located in `src/game/battle/` and the inferred structure of Units within the Realm of Geherra project.

## 1. Battle System Overview

The battle system is a grid-based, real-time with pause (RTWP) tactical combat engine. It operates on a tick-based loop (20 ticks/second). Units move between grid cells, execute actions with windup/cooldown timers, and interact via physics-like flocking within individual cells.

### Core Components (`src/game/battle/`)

#### **BattleState.lua**
*   **Role**: The main controller/state for the battle scene.
*   **Key Responsibilities**:
    *   **Initialization**: Sets up the grid, deploys parties (Player on left, Enemy on right), and initializes subsystems (AI, Input).
    *   **Game Loop**: Manages the `update` loop, processing ticks for all units.
    *   **Turn Flow**: Handles pausing for player input when the player unit is ready.
    *   **Lifecycle**: Cleans up dead units and checks for victory conditions.

#### **BattleGrid.lua**
*   **Role**: Data structure representing the battlefield.
*   **Key Responsibilities**:
    *   Maintains a 2D array of `cells`.
    *   **Cell Data**: Each cell tracks its coordinates, list of units contained, and total size vs max size (capacity).
    *   **Utilities**: Provides helper functions for distance calculation (`getDistance`), coordinate conversion (pixel to grid), and validity checks.

#### **BattleGridActions.lua**
*   **Role**: The "Physics Engine" and Action Executor for the grid.
*   **Key Responsibilities**:
    *   **Movement**: Moves units between cells (`moveUnitToCell`), handling capacity checks and movement cooldowns based on unit speed.
    *   **Pathfinding**: Implements A* pathfinding (`getPath`) to navigate around obstacles or enemy-blocked cells.
    *   **Action Execution**: Validates if an action can be performed (`tryUseAction`). If a target is out of range, it automatically issues a move command towards the target.

#### **BattleUnitAI.lua**
*   **Role**: The "Brain" for NPC units.
*   **Key Responsibilities**:
    *   **Tick Logic**: Decrements cooldowns and executes pending actions.
    *   **Decision Making**: If a unit is idle, it selects an action from its available list.
    *   **Targeting (`updateTarget`)**:
        1.  Validates current target.
        2.  Scans immediate 8 neighbors for high-priority targets (preference for units directly in front).
        3.  Fallbacks to the closest enemy on the map if no neighbors are found.

#### **BattlePlayerInput.lua**
*   **Role**: Input handler for the player-controlled unit.
*   **Key Responsibilities**:
    *   Maps keyboard inputs (WASD) to `BattleGridActions` movement commands.
    *   Maps `Space` to executing the currently selected action.
    *   Prevents input if the player unit is on cooldown.

#### **BattleAnimations.lua**
*   **Role**: Visuals and sub-cell physics.
*   **Key Responsibilities**:
    *   **Flocking**: Implements a relaxation/repulsion algorithm (`updateUnitPositionsInCell`) to spread units out visually within a single grid cell so they don't overlap perfectly.
    *   **Tweens**: Handles smooth movement interpolation between cells.
    *   **FX**: Manages visual effects like lunging, flashing (on hit), and shaking (on block/miss).

#### **BattleRenderer.lua**
*   **Role**: Rendering pipeline.
*   **Key Responsibilities**:
    *   Sorts units by Y-coordinate to ensure correct depth/overlap drawing.
    *   Delegates actual drawing to the unit's own `draw` method.

#### **BattleUI.lua**
*   **Role**: User Interface overlay.
*   **Key Responsibilities**:
    *   **World Space**: Renders floating damage numbers.
    *   **Screen Space**: Renders the player's action bar (showing windup/cooldown progress) and victory/defeat messages.

#### **BattleCamera.lua**
*   **Role**: Camera management.
*   **Key Responsibilities**:
    *   Smoothly follows the player unit.
    *   Clamps the view to the battlefield boundaries.

---

## 2. Unit Architecture

The `Unit` class is defined in `src/game/modules/UnitModule.lua`. It represents an RPG entity with stats, equipment, and actions. When entering combat, this object is used as the core data structure, and transient battle state is attached to it.

### Core Unit Object (`src/game/modules/UnitModule.lua`)
The `Unit` class inherits from `Object` (classic.lua) and is instantiated via `UnitModule.create`.

#### **RPG Stats & Data**
*   **Identity**: `id`, `name`, `template`, `unit_type`.
*   **Attributes**: `health`/`max_health`, `speed`, `morale`.
*   **Combat Stats**: `attack`, `defense`, `strength`, `protection`.
*   **Configuration**: `scale`, `size`, `controllable` (player vs AI), `commander` (boolean).
*   **Equipment**:
    *   `equipmentSlots`: List of slots (e.g., "main_hand", "chest").
    *   `equipment`: Key-value map for quick item lookup.
    *   Methods: `equip(item)`, `unequip(slotType)`.
*   **Actions**:
    *   `actions`: List of available battle actions (innate + item-granted).
    *   `getActions()`: Returns all actions, adding a default "Unarmed Attack" if main hand is empty.

#### **Visual & State Fields**
*   **Sprite**: `sprite` (loaded from AssetManager).
*   **State Machine**: `state` (e.g., "idle"), `state_timer`.
*   **Drawing**: `battle_x`, `battle_y`, `facing_right` (used in `draw`).
*   **FX**: `visuals` table (`flash_color`, `shake_intensity`, etc.).

### Battle Runtime State
When a Unit is added to the `BattleState`, additional properties are likely injected or managed externally (by `BattleGrid`, `BattleUnitAI`, etc.) to track its immediate tactical situation.

*   **Grid Position**: `currentCell`, `subcell_x`, `subcell_y`.
*   **Team**: `battle_party` (1 or 2).
*   **Cooldowns**: `action_cooldown` (ticks until next move/act).
*   **Targeting**: `battle_target` (current enemy focus).

### Key Methods
*   **`draw()`**: Handles sprite rendering, scaling, facing flips, hit flashes, and shake effects. Also draws a small HP bar for controllable units.
*   **`pickTarget(battle)`**: AI logic to select an enemy. Scans all enemies, preferring nearest ones with fewer attackers (target spreading).
*   **`getActions()`**: Resolves available actions, ensuring an unarmed attack is available if no weapon is equipped.