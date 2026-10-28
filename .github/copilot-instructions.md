# Geherra-Realms — Project Guidelines

LÖVE (Love2D) 11.x Lua RPG. See `PROJECT_DEFINITION.md` for the overall vision and `docs/` (`art-bible.md`, `map-generator.md`) for specifics.

## Build & Test
- Primary verification is in-game: run `love .` from the repo root.
- Unit tests live in `tests/unit/` — run them only when a change touches that logic.
- Do NOT create throwaway validation scripts (`_smoke_*`, `verify_*`, `_probe*`) in the repo. Verify with `love .`, or use a temp file outside the repo. If you must create scratch files, delete them before finishing — never leave `verify_*.lua`/`*.txt` at root.

## Code Style
- Follow the existing pattern of the file you touch (state/screen/UI). Match its structure and helpers.
- Input: use `Input.isKeyDown(key)` (see `core/input.lua` + `game/states/world_state.lua`). States manage their own repeat/cooldown maps (e.g. `interactionCooldowns`) — do NOT add new `justPressed`/`wasPressed`-style APIs.

## Architecture
- Layered: `core/` (game loop, state manager, input, save), `systems/` (logic), `data/` (declarative content), `entities/`, `ui/`, `game/states/`.
- Gameplay logic is grouped under `src/systems/{actors,battle,battlefield,campaign,goals,items,knowledge,locations,parties,population,quests,services,social,world_activities}/`. Use direct imports from these domain folders; simulation orchestration remains in `src/game/campaign/` and `src/game/battle/`.
- Map generation lives in `src/world/generation/`; navigation is `src/world/world_navigation.lua`. Assets and generated-map output paths stay under `src/assets/`.
- See `docs/FILE_ORGANIZATION_PLAN.md` for the completed move manifest and feature-location guide. Detailed notes are `docs/units.md`, `docs/quest_procedural.md`, and `docs/EMERGENT_GAMEPLAY.md`.
- Add NPCs/shops/quests via existing systems and the skills in `.github/skills/` (router, trader-npcs, dialogue-systems, etc.) rather than new ad-hoc wiring.

## Conventions
- EDIT existing files in place. Never delete + recreate a file to change it.
- Keep changes scoped to the request. No refactors of unrelated working code.
- Ask clarifying questions during planning/design BEFORE implementing.
- Do not wire test/debug scaffolding into `main.lua` or core files.
- Design terminology in docs is canonical (follow the user's naming; check `docs/` and `PROJECT_DEFINITION.md` before coining terms).
