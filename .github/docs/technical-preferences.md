# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: LÖVE (Love2D) 11.5
- **Language**: Lua (LuaJIT via LÖVE)
- **Rendering**: LÖVE 2D graphics API (OpenGL/OpenGL ES via LÖVE)
- **Physics**: None (disabled in conf.lua) — custom collision for tactical combat

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Windows/macOS/Linux), retro handhelds
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard & Mouse
- **Gamepad Support**: Partial (stretch goal — gamepad navigation for towns/menus)
- **Touch Support**: None
- **Platform Notes**: LÖVE has community ports for many retro handhelds. 1024x768 fixed resolution. All UI must support keyboard navigation. No hover-only interactions — retro handheld screens may not have a cursor.

## Naming Conventions

- **Classes/module tables**: PascalCase (e.g., `Game`, `TitleScene`, `PartyManager`)
- **Functions/methods**: snake_case (e.g., `change_scene`, `calculate_damage`)
- **Variables**: snake_case (e.g., `current_scene`, `party_members`)
- **Private methods/variables**: _prefixed snake_case (e.g., `_internal_update`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_PARTY_SIZE`, `TILE_SIZE`)
- **Files**: snake_case matching primary export (e.g., `scene_manager.lua`, `party_manager.lua`)
- **LÖVE callbacks**: lowercase (e.g., `love.load`, `love.update`, `love.draw`)

## Performance Budgets

- **Target Framerate**: 60 FPS (desktop), 30 FPS (retro handheld minimum target)
- **Frame Budget**: 16.6ms (desktop), 33ms (retro handhelds)
- **Draw Calls**: Minimise — batch sprite draws where possible (use SpriteBatches for repeated sprites)
- **Memory Ceiling**: 512MB (desktop), 256MB (retro handhelds) — watch texture atlas sizes

## Testing

- **Framework**: LuaUnit or bust (lightweight Lua testing — configure via /test-setup)
- **Minimum Coverage**: Core gameplay formulas (damage, movement, quest logic)
- **Required Tests**: Balance formulas, gameplay systems

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- ADR-0001 — Game Architecture and Scene Management (Accepted)

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: gameplay-programmer (LÖVE/Lua architecture and general game code)
- **Language/Code Specialist**: gameplay-programmer (Lua code review — primary covers it)
- **Shader Specialist**: N/A — LÖVE uses GLSL shaders; fall back to technical-artist if needed
- **UI Specialist**: gameplay-programmer (LÖVE's UI is code-driven — no dedicated UI editor)
- **Additional Specialists**: (none configured yet)
- **Routing Notes**: LÖVE is a framework, not a full engine — most code is pure Lua. Primary covers architecture, gameplay, and rendering. Invoke technical-artist for shader work or VFX optimisation.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.lua files) | gameplay-programmer |
| Shader files (.glsl, .frag, .vert) | technical-artist |
| UI / screen files (.lua) | gameplay-programmer |
| Level / data files (.lua) | game-designer or gameplay-programmer |
| Native extension / plugin files (.dll, .so, .dylib) | gameplay-programmer |
| General architecture review | gameplay-programmer |
