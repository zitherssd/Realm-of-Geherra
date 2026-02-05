# GEMINI.md - Project Onboarding Guide

This document provides a high-level overview of the "Realm of Geherra" (or "Feudalism") LÖVE project, intended for new developers and AI agents.

## Project Overview

This project is a 2D RPG/strategy game. Based on the file structure and content, the gameplay appears to involve managing a party of units, moving on an overworld map, interacting with locations, and engaging in tactical battles. The game is data-driven, with game entities like units, items, and locations defined in data files.

The high-level gameplay loop seems to be:
1.  Navigate the party on an overworld map (`OverworldState`).
2.  Enter locations or trigger events.
3.  Engage in battles (`BattleState`).
4.  Manage the party's units, inventory, and equipment (`PartyManagementState`, `PartyInventoryState`).

## How the Project Is Structured

The project follows a clear structure, separating the LÖVE engine code, game logic, assets, and data.

-   `main.lua`: The main entry point. It handles all LÖVE callbacks and delegates them to the `Game` object.
-   `conf.lua`: LÖVE configuration file (window size, title, etc.).
-   `lib/`: Contains external libraries. `classic.lua` is used for object-oriented programming, and `csv.lua` is for parsing CSV files.
-   `assets/`: Contains all game assets like sprites, maps, and icons.
-   `src/`: The main source code for the game.
    -   `src/game.lua`: A singleton-like object that initializes the game, loads data, and manages the main game loop by delegating to the current game state.
    -   `src/data/`: Contains game data, mostly in Lua tables and CSV files. This is where units, items, locations, etc., are defined.
    -   `src/game/`: The core game logic.
        -   `GameState.lua`: A stack-based state manager that controls the overall flow of the game.
        -   `modules/`: Singleton-like modules that manage different aspects of the game (e.g., `UnitModule`, `PartyModule`, `ItemModule`). They are responsible for creating and managing game objects.
        -   `overworld/`, `battle/`, `location/`: These directories contain the specific game states. Each state is a "scene" or "screen" in the game, like the world map, the battle screen, or a town menu.
        -   `ui/`: Contains UI components like menus, panels, and unit renderers.
        -   `util/`: Utility functions, like `AssetManager.lua`.

### Where New Code Should Go

-   **New game state (e.g., a new menu screen):** Create a new Lua file in a relevant subdirectory of `src/game/` (like `ui/states/` or a new directory) and make it compatible with the `GameState` manager (i.e., it should have `enter`, `update`, `draw` methods).
-   **New unit/item:** Add data to the files in `src/data/`.
-   **New system (e.g., magic system):** Create a new module in `src/game/modules/` to manage the system's data and logic.

## Game Loop & Flow

The game uses a stack-based state machine (`src/game/GameState.lua`) to manage the game's flow.

1.  `main.lua` is the entry point, passing LÖVE callbacks to `src/game.lua`.
2.  `Game:init()` sets up the game by initializing modules, loading data, and pushing the initial `OverworldState` onto the `GameState` stack.
3.  `Game:update()` and `Game:draw()` call the corresponding methods on the `GameState` manager.
4.  The `GameState` manager forwards these calls to whatever state is currently at the top of its stack (e.g., `OverworldState`, `BattleState`).
5.  States are responsible for their own update, draw, and input logic. They can push new states onto the stack (e.g., `OverworldState` pushing a `BattleState`) or pop themselves off to return to the previous state.

## Key Systems

The game is built around several key modules and states:

-   **State Management (`GameState.lua`):** Manages the stack of game states.
-   **Class System (`lib/classic.lua`):** A simple OOP implementation providing inheritance. Most game objects and states extend a base `Object`.
-   **Data Modules (`src/game/modules/`):**
    -   `UnitModule`: Creates and manages unit instances.
    -   `ItemModule`: Creates and manages items.
    -   `PartyModule`: Manages parties of units.
    -   `LocationsModule`: Manages game locations.
    -   `PlayerModule`: A specialized module to track the player's party and unit.
-   **Game States (`src/game/.../`):**
    -   `OverworldState`: Manages navigation on the world map.
    -   `BattleState`: Manages turn-based combat on a grid. It uses sub-systems like `BattleGrid`, `BattleUI`, and `BattleUnitAI`.
    -   `PartyManagementState`: A UI state for managing units in the player's party.

## Conventions & Style

-   **Object-Oriented:** The code uses `classic.lua` to simulate classes. Files often define a class that is then instantiated.
-   **Module Singletons:** The `modules` are treated as singletons. They are required once and then used to manage game data globally (e.g., `UnitModule.create(...)`).
-   **File Naming:** Files are named in PascalCase (e.g., `BattleState.lua`, `UnitModule.lua`).
-   **Communication:** Files communicate via `require` and by accessing the public interfaces of the singleton-like modules. There is no evidence of a global message bus; objects call methods on each other directly or via the modules.

## How to Safely Modify or Extend the Game

-   **Understand the States:** Before making changes, identify which game state is active. Most logic for a specific screen is contained within its state file.
-   **Use the Modules:** When creating new units, items, or other game objects, use the factory functions provided by the corresponding modules (e.g., `UnitModule.create(...)`). Do not create them manually.
-   **Data-Driven First:** If adding new content (like a new type of sword or a new unit), the first step should be to add it to the data files in `src/data/`. The module system is designed to load this data.
-   **What *not* to touch:** Be careful when modifying `GameState.lua` or `classic.lua`, as they are fundamental to the architecture. Also, be cautious when changing the initialization order in `game.lua`.

### Adding a New Feature (e.g., a "Quest" system)

1.  **Data:** Create a `quests.lua` file in `src/data/` to define the quests.
2.  **Module:** Create a `QuestModule.lua` in `src/game/modules/` to load and manage quest state (e.g., `QuestModule.activeQuests`).
3.  **UI:** Create a `QuestLogState.lua` in `src/game/ui/states/` to display quests to the player. This state would be pushed onto the `GameState` stack when the player opens the quest log.
4.  **Integration:** Integrate the quest system into other parts of the game. For example, `InteractionModule` could be modified to start quests, and `BattleState` could be modified to update quest objectives.

## Open Questions / TODOs

-   It's unclear if there is a proper save/load system implemented.
-   The "Feudalism" vs. "Realm of Geherra" naming suggests a possible name change or inconsistency.
-   Error handling appears to be minimal.
-   The purpose of `playmat.lua` in `lib/` is not immediately obvious from the code that has been reviewed. It might be for UI layout or scene management.
