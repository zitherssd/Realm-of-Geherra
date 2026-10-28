# File organization plan

Date: 2026-10-28  
Status: completed on 2026-10-28; all 13 batches implemented and verified. The tree below is the final repository structure. Historical source paths remain in the assessment, manifest, and before/after examples for traceability.

## 1. Scope and recommendation

Keep the existing layered layout and organize gameplay modules within `src/systems/` by domain. Put map generation next to the world/map code, battle execution next to battle helpers, and quest objective records next to quest behavior. Keep authored definitions in `src/data/`, state orchestration in `src/game/`, presentation in `src/ui/`, and developer facilities in `src/debug/`.

This is a location-and-import cleanup. It does not continue A1–A3, change ownership of state, alter APIs or scheduling, change data definitions, split/merge files, or introduce loaders, facades, compatibility wrappers, or new frameworks.

The completed end state has **63 Lua file moves and 3 documentation moves**. All 59 files directly inside `src/systems/` get an explicit home; existing battle and activity folders are reused. This is the repository-wide destination map used for the incremental migration. Most paths elsewhere stay as they are. All Lua basenames remain unchanged; the only basename change is adding `.md` to `EMERGENT_GAMEPLAY`.

Implementation was authorized on 2026-10-28. The original assessment and source inventory below describe the pre-migration working tree; the manifest retains historical source paths for verification.

### Assessment basis

Inspected the current working-tree inventory, module imports, module responsibilities, entry points, campaign/battle orchestration, Concord registration, definition/action registries, test launchers, debug integration, asset paths, and relevant authoring/design documentation. No external research is needed for this repository-local assessment. No game or test execution was performed during the original assessment. Implementation checks are recorded in section 11.

The working tree already contains data-cleanup changes, including deleted `src/data/static_locations.lua` and `src/data/progression.lua`, new faction/data scenarios, and modified authoring/audit documents. This plan uses the files currently on disk, including untracked files. It does not propose restoring those deleted modules or editing those existing changes now. Reconfirm the move list against the working tree before implementation.

## 2. Assessment of the pre-migration structure

### What already works

| Area | Current organization and decision |
| --- | --- |
| Entry points | Root `main.lua` and `conf.lua` match LÖVE's launch conventions. Keep them. |
| Core | Eight files in `src/core/` provide lifecycle, input, state management, saving, event bus, IDs, schema, and seeded randomness. No reason to reshuffle them. |
| Game orchestration | `src/game/states/`, `game_initializer.lua`, `game_context.lua`, `game/battle/`, and `game/campaign/` express state/context/runtime responsibilities established by prior work. Keep that boundary. |
| ECS representation | `src/ecs/components/`, `assemblages/`, and `world.lua` make entity construction and marker registration easy to find. Keep them. Components and assemblages are game-specific, but grouping them by their Concord construction role is useful. |
| Authored content | `src/data/` separates items, dialogues, location definitions, names, NPC archetypes, population rules, troop templates, and schema types. Existing aggregates/manifests make extension points explicit. |
| UI | `src/ui/screens/` and `widgets/` are recognizable; `knowledge_text.lua` and `world_event_text.lua` are presentation helpers. No need to relocate them by the domain they describe. |
| Debug | Eight modules in `src/debug/` contain fixtures, debug maps, commands, inspection, and profiling facilities. This is an appropriate developer-tool boundary. |
| Vendors | Concord is isolated in `src/libs/concord/`; `love.app/` is a bundled third-party runtime. Preserve both internal layouts. |
| Tests | `tests/unit/` contains 38 Lua files, including the runner and scenarios. The scenario basenames identify domains and a single runner registers them. Keep this layout for now. |
| Assets | `src/assets/` is already separate from logic, with map/location imagery and sprite categories. Numeric raw-art names have a different purpose from Lua module names. |

### Where navigation breaks down

1. **The systems root is a mixed-responsibility directory.** It contains 59 direct Lua files and 68 Lua files recursively. NPC hydration, population, goals, recovery, services, map generation, inventory, loot results, campaign encounter resolution, and combat all appear at the same level. Looking for a new service or activity requires knowing historical filenames.
2. **Battle behavior is spread across several technical labels.** `combat_system.lua` is at the systems root; range/render/unit helpers are in `systems/battle/`; Concord decision/execution systems are in `ecs/systems/`; simulation/context are in `game/battle/`; the headless simulation driver is back at the systems root. Keep simulation ownership in `game/battle/`, but colocate battle rule/execution modules in `systems/battle/`. Concord usage alone does not make decision/execution generic infrastructure.
3. **World generation is filed as ordinary gameplay systems.** The painted generator, painted-map adapter, and alternative grid generator live beside dialogue and inventory. They belong in `world/generation/`. Navigation also belongs beside the map rather than beside service rules.
4. **Population runtime modules are scattered through the systems root.** Location population, NPC population, actor hydration, and initial NPC-party creation implement a coherent generation path. A `systems/population/` home makes that path visible without moving population content or changing its model.
5. **Quest representation has an isolated one-file directory.** `src/quests/objective.lua` creates nested objective records; quest behavior lives in three root-level systems. Put those four modules together. It is not an ECS component or a new standalone entity.
6. **The activity coordinator sits outside its implementations.** `world_activity_system.lua` belongs with `world_activities/{travel,roam,raid,rest}_activity.lua` and `pursuit.lua`.
7. **One action handler has an unnecessary directory to itself.** `systems/location_actions/examine_wizard_tower.lua` can sit beside the action registry and shared action handlers under `systems/locations/`. Do not split every existing action into its own file.
8. **Detailed documentation is split between root and docs.** `units.md`, `quest_procedural.md`, and extensionless `EMERGENT_GAMEPLAY` belong in the existing `docs/` directory. The project overview can remain at root.
9. **The systems suffix is not a reliable type indicator.** Many `*_system.lua` files are plain Lua function tables, while decision/execution use `Concord.system`. Preserve established basenames; directory context is enough to make this understandable. Renaming every module to enforce one suffix convention would add churn.

### Similar names and small directories that are justified

- `data/locations/` defines location identity, placement, actions, and rules; `data/population/locations/` defines resident/garrison profiles. They answer different authoring questions. Keep both.
- `data/npc_archetypes/` defines NPC composition; `data/units/` provides troop templates referenced through `troopType`. They are related, not interchangeable.
- `data/population/factions/`, `cultures/`, and `parties/` are independently registered content categories. Keep their shallow hierarchy and `index.lua` manifests.
- `data/types/` contains shape validators; it should not be confused with authored content or moved into runtime systems.
- `data/goal_definitions.lua` does not exist: the current `systems/goal_definitions.lua` includes construction, validation, and debug-form behavior. Move it with goal behavior, not into declarative content.
- `game/campaign/` currently has one file, `campaign_runtime.lua`. That directory records the established campaign-orchestration boundary and parallels `game/battle/`; flattening it would save little and undo a useful landmark.
- Small faction/template folders such as `data/units/neutral/`, `npcs/`, and `pelasgians/` follow the existing troop grouping and may include authoring notes. Leave them. Do not introduce more nesting beneath them.
- `entities/entity.lua` and `entities/item.lua` are the existing plain-object item representation, used by quest/loot code. Leave their relationship and paths intact; converting or redistributing that representation is outside this cleanup.

### Naming decisions

Continue lower-case `snake_case.lua`, the established `*_state.lua`, `*_screen.lua`, and `*_activity.lua` roles, and the existing `*_system.lua` basenames. Use plural domain folders where they name collections; keep the established `battle/`, `world_activities/`, and `population/` terms.

Do not normalize `index.lua` into `init.lua`: data manifests explicitly load named entries, while `ecs/components/init.lua` is the existing registration entry point. Do not rename `data/dialogue.lua`/`dialogues/`, `troops.lua`/`units/`, or `pelasgian`/`pelasgians` just for spelling symmetry. Their module paths, content keys, and asset paths have distinct existing roles. Do not rename IDs.

Existing docs mix uppercase reference/report names and lower-case descriptive filenames. Preserve those filenames; locate documents together before considering cosmetic renames. New documentation should use the convention of nearby related documents.

## 3. Final directory tree

The tree lists the complete final gameplay-system filenames. Existing large content, asset, test, and vendor subtrees are summarized; summarized entries keep their current children.

```text
/
+-- main.lua
+-- conf.lua
+-- PROJECT_DEFINITION.md
+-- generation.png                         # retain pending provenance/usage decision
+-- skills-lock.json
+-- .github/                               # existing assistant guidance/skills
+-- .vscode/                               # existing editor launch configuration
+-- docs/
|   +-- FILE_ORGANIZATION_PLAN.md
|   +-- units.md                           # moved from root
|   +-- quest_procedural.md                 # moved from root
|   +-- EMERGENT_GAMEPLAY.md                # moved; extension added
|   +-- [existing guides, reports, design notes; same names]
+-- tests/
|   +-- unit/                              # existing runner/scenario names unchanged
+-- love.app/                              # bundled runtime; unchanged
+-- src/
|   +-- assets/                            # all existing paths unchanged
|   +-- libs/
|   |   +-- concord/                       # unchanged
|   +-- core/                              # unchanged
|   +-- entities/                          # entity.lua, item.lua unchanged
|   +-- utils/                             # unchanged
|   +-- ecs/
|   |   +-- world.lua
|   |   +-- components/                    # unchanged, including init.lua
|   |   +-- assemblages/                   # unchanged
|   +-- data/                              # unchanged
|   |   +-- definition_registry.lua
|   |   +-- [existing root catalogs/configuration]
|   |   +-- dialogues/
|   |   +-- items/
|   |   +-- locations/
|   |   +-- names/
|   |   +-- npc_archetypes/
|   |   +-- population/
|   |   |   +-- catalog.lua
|   |   |   +-- settings.lua
|   |   |   +-- cultures/
|   |   |   +-- factions/
|   |   |   +-- locations/
|   |   |   +-- parties/
|   |   +-- types/
|   |   +-- units/                         # existing faction/template groups
|   +-- game/
|   |   +-- game_context.lua
|   |   +-- game_initializer.lua
|   |   +-- states/                        # unchanged
|   |   +-- campaign/
|   |   |   +-- campaign_runtime.lua
|   |   +-- battle/
|   |       +-- battle_context.lua
|   |       +-- battle_simulation.lua
|   |       +-- headless_battle_runner.lua
|   +-- systems/
|   |   +-- actors/
|   |   |   +-- ai_system.lua
|   |   |   +-- animation_system.lua
|   |   |   +-- attribute_system.lua
|   |   |   +-- movement_system.lua
|   |   |   +-- player_system.lua
|   |   |   +-- progression_system.lua
|   |   |   +-- recovery.lua
|   |   |   +-- skill_system.lua
|   |   +-- battle/
|   |   |   +-- battle_unit_system.lua
|   |   |   +-- combat_system.lua
|   |   |   +-- decision_system.lua
|   |   |   +-- execution_system.lua
|   |   |   +-- range_utils.lua
|   |   |   +-- render_system.lua
|   |   +-- battlefield/
|   |   |   +-- battlefield_interaction.lua
|   |   |   +-- battlefield_remains_system.lua
|   |   |   +-- battlefield_resource_collection.lua
|   |   +-- campaign/
|   |   |   +-- campaign_battle_resolution.lua
|   |   |   +-- campaign_battle_result_applier.lua
|   |   |   +-- encounter_system.lua
|   |   |   +-- time_system.lua
|   |   |   +-- world_encounter_system.lua
|   |   |   +-- world_events.lua
|   |   +-- goals/
|   |   |   +-- goal_definitions.lua
|   |   |   +-- goal_state.lua
|   |   |   +-- goal_system.lua
|   |   +-- items/
|   |   |   +-- equipment_system.lua
|   |   |   +-- inventory_system.lua
|   |   |   +-- loot_application.lua
|   |   |   +-- loot_generator_system.lua
|   |   |   +-- loot_resolver.lua
|   |   |   +-- loot_result.lua
|   |   |   +-- trader_system.lua
|   |   +-- knowledge/
|   |   |   +-- battle_knowledge_system.lua
|   |   |   +-- knowledge_system.lua
|   |   |   +-- travel_knowledge_system.lua
|   |   +-- locations/
|   |   |   +-- examine_wizard_tower.lua
|   |   |   +-- location_action_registry.lua
|   |   |   +-- location_actions.lua
|   |   |   +-- location_rules.lua
|   |   |   +-- location_system.lua
|   |   |   +-- recruitment_system.lua
|   |   +-- parties/
|   |   |   +-- party_ai_system.lua
|   |   |   +-- party_interaction_system.lua
|   |   |   +-- party_system.lua
|   |   |   +-- visibility_system.lua
|   |   +-- population/
|   |   |   +-- location_population_system.lua
|   |   |   +-- npc_factory.lua
|   |   |   +-- npc_party_factory.lua
|   |   |   +-- npc_population_system.lua
|   |   +-- quests/
|   |   |   +-- objective.lua
|   |   |   +-- quest_availability_system.lua
|   |   |   +-- quest_objective_system.lua
|   |   |   +-- quest_system.lua
|   |   +-- services/
|   |   |   +-- caravan_system.lua
|   |   |   +-- service_system.lua
|   |   +-- social/
|   |   |   +-- dialogue_system.lua
|   |   |   +-- faction_system.lua
|   |   |   +-- relationship_system.lua
|   |   |   +-- reputation_system.lua
|   |   +-- world_activities/
|   |   |   +-- pursuit.lua
|   |   |   +-- raid_activity.lua
|   |   |   +-- rest_activity.lua
|   |   |   +-- roam_activity.lua
|   |   |   +-- travel_activity.lua
|   |   |   +-- world_activity_system.lua
|   +-- world/
|   |   +-- camera.lua
|   |   +-- map.lua
|   |   +-- scene_loader.lua
|   |   +-- world.lua
|   |   +-- world_navigation.lua
|   |   +-- generation/
|   |       +-- map_generator.lua
|   |       +-- painted_map_loader.lua
|   |       +-- world_generation_system.lua
|   +-- ui/                                # unchanged
|   |   +-- ui_manager.lua
|   |   +-- knowledge_text.lua
|   |   +-- world_event_text.lua
|   |   +-- screens/
|   |   +-- widgets/
|   +-- debug/                             # unchanged
```

No new folder requires an `init.lua`. Direct module imports continue to work through the existing root-relative package path. Remove `src/quests/`, `src/ecs/systems/`, and `src/systems/location_actions/` only after their listed files have been moved and the directories are empty. Existing local empty directories `audio/`, `production/`, and `$TEMP/` are not part of the proposed source tree and are left alone.

## 4. Why these groups improve navigation

| Destination | Navigation benefit and boundary |
| --- | --- |
| `systems/actors/` | Actor attributes, skills, progression, health/recovery, player favor, and basic actor helpers have one home. The small AI/animation/movement helpers remain intact; no attempt is made to fold them into party or battle behavior. |
| `systems/battle/` | Damage rules, intent decision/execution, action gating, range, and battle rendering become one visible mechanic group. Simulation lifetime remains in `game/battle/`. Keep the renderer here because that is its existing domain home; no separate rendering framework. |
| `systems/battlefield/` | Persistent aftermath, collection, and player interaction are adjacent. This distinguishes campaign-map remains from live battle simulation. |
| `systems/campaign/` | Campaign time, history, encounter lifecycles, and application of battle consequences are easy to follow. `game/campaign/campaign_runtime.lua` continues scheduling these modules; this directory does not become another runtime. |
| `systems/goals/` | Goal definitions, goal records, and evaluation sit together. New goal authors can find both definition and evaluator without mistaking executable registry code for static data. |
| `systems/items/` | Inventory, equipment, merchant stock, and loot planning/application stay together as item/resource behavior. Keep all existing files and APIs; do not merge loot stages. |
| `systems/knowledge/` | Memory/knowledge operations and their battle/travel acquisition hooks share a home. Historical event storage remains in the campaign group; UI text remains in UI. |
| `systems/locations/` | Location membership/policy, actions, action registration, and recruitment are discoverable together. Population generation and services keep their own responsibilities rather than being filed here merely because they can occur at a settlement. |
| `systems/parties/` | Party membership/resources, world movement, party contact, and spotting belong together. Visibility evaluates parties and locations, but its shared world-map observer logic fits here better than under battle or UI. |
| `systems/population/` | The site-to-location-to-resident/party construction path is visible as a group. The NPC factory also serves other callers; moving it does not restrict when it can be used. |
| `systems/quests/` | Templates' runtime handling, offer availability, objective progress, and nested objective construction share a home. Quest templates remain in `data/quests.lua`. |
| `systems/services/` | Service commissioning and caravan service execution are adjacent. Two related modules justify one folder; do not add a folder per service type. |
| `systems/social/` | Dialogue flags, NPC relations, faction standing, and reputation are related social operations. Keep their separate state stores and APIs; proximity is not unification. |
| `systems/world_activities/` | The coordinator and all current activity implementations share the existing shallow directory. No new `activities/implementations/` layer. |
| `world/generation/` | Painted and grid generation plus the painted-map adapter have an obvious home alongside map/navigation code. The two generators keep their different implementations and callers. |
| `game/battle/` | The headless driver is next to the simulation it advances, making the shared visible/headless simulation relationship easy to find. |
| `docs/` | Detailed project notes become discoverable in one directory without adding documentation taxonomy or renaming existing guides. |

These are navigation groups, not new dependency rules. Existing cross-domain calls remain legal and preserve their current order.

## 5. Exact move and rename manifest

Each row is one completed move; the first column preserves its historical source path. No wildcard moves, file splits, merges, deletions of content, or Lua basename changes are implied. Every file absent from this manifest keeps its location. Existing callers may still need import-string updates.

| Historical source path | Current path (completed) |
| --- | --- |
| `EMERGENT_GAMEPLAY` | `docs/EMERGENT_GAMEPLAY.md` |
| `quest_procedural.md` | `docs/quest_procedural.md` |
| `src/ecs/systems/decision_system.lua` | `src/systems/battle/decision_system.lua` |
| `src/ecs/systems/execution_system.lua` | `src/systems/battle/execution_system.lua` |
| `src/quests/objective.lua` | `src/systems/quests/objective.lua` |
| `src/systems/ai_system.lua` | `src/systems/actors/ai_system.lua` |
| `src/systems/animation_system.lua` | `src/systems/actors/animation_system.lua` |
| `src/systems/attribute_system.lua` | `src/systems/actors/attribute_system.lua` |
| `src/systems/battle_knowledge_system.lua` | `src/systems/knowledge/battle_knowledge_system.lua` |
| `src/systems/battlefield_interaction.lua` | `src/systems/battlefield/battlefield_interaction.lua` |
| `src/systems/battlefield_remains_system.lua` | `src/systems/battlefield/battlefield_remains_system.lua` |
| `src/systems/battlefield_resource_collection.lua` | `src/systems/battlefield/battlefield_resource_collection.lua` |
| `src/systems/campaign_battle_resolution.lua` | `src/systems/campaign/campaign_battle_resolution.lua` |
| `src/systems/campaign_battle_result_applier.lua` | `src/systems/campaign/campaign_battle_result_applier.lua` |
| `src/systems/caravan_system.lua` | `src/systems/services/caravan_system.lua` |
| `src/systems/combat_system.lua` | `src/systems/battle/combat_system.lua` |
| `src/systems/dialogue_system.lua` | `src/systems/social/dialogue_system.lua` |
| `src/systems/encounter_system.lua` | `src/systems/campaign/encounter_system.lua` |
| `src/systems/equipment_system.lua` | `src/systems/items/equipment_system.lua` |
| `src/systems/faction_system.lua` | `src/systems/social/faction_system.lua` |
| `src/systems/goal_definitions.lua` | `src/systems/goals/goal_definitions.lua` |
| `src/systems/goal_state.lua` | `src/systems/goals/goal_state.lua` |
| `src/systems/goal_system.lua` | `src/systems/goals/goal_system.lua` |
| `src/systems/headless_battle_runner.lua` | `src/game/battle/headless_battle_runner.lua` |
| `src/systems/inventory_system.lua` | `src/systems/items/inventory_system.lua` |
| `src/systems/knowledge_system.lua` | `src/systems/knowledge/knowledge_system.lua` |
| `src/systems/location_action_registry.lua` | `src/systems/locations/location_action_registry.lua` |
| `src/systems/location_actions.lua` | `src/systems/locations/location_actions.lua` |
| `src/systems/location_actions/examine_wizard_tower.lua` | `src/systems/locations/examine_wizard_tower.lua` |
| `src/systems/location_population_system.lua` | `src/systems/population/location_population_system.lua` |
| `src/systems/location_rules.lua` | `src/systems/locations/location_rules.lua` |
| `src/systems/location_system.lua` | `src/systems/locations/location_system.lua` |
| `src/systems/loot_application.lua` | `src/systems/items/loot_application.lua` |
| `src/systems/loot_generator_system.lua` | `src/systems/items/loot_generator_system.lua` |
| `src/systems/loot_resolver.lua` | `src/systems/items/loot_resolver.lua` |
| `src/systems/loot_result.lua` | `src/systems/items/loot_result.lua` |
| `src/systems/map_generator.lua` | `src/world/generation/map_generator.lua` |
| `src/systems/movement_system.lua` | `src/systems/actors/movement_system.lua` |
| `src/systems/npc_factory.lua` | `src/systems/population/npc_factory.lua` |
| `src/systems/npc_party_factory.lua` | `src/systems/population/npc_party_factory.lua` |
| `src/systems/npc_population_system.lua` | `src/systems/population/npc_population_system.lua` |
| `src/systems/painted_map_loader.lua` | `src/world/generation/painted_map_loader.lua` |
| `src/systems/party_ai_system.lua` | `src/systems/parties/party_ai_system.lua` |
| `src/systems/party_interaction_system.lua` | `src/systems/parties/party_interaction_system.lua` |
| `src/systems/party_system.lua` | `src/systems/parties/party_system.lua` |
| `src/systems/player_system.lua` | `src/systems/actors/player_system.lua` |
| `src/systems/progression_system.lua` | `src/systems/actors/progression_system.lua` |
| `src/systems/quest_availability_system.lua` | `src/systems/quests/quest_availability_system.lua` |
| `src/systems/quest_objective_system.lua` | `src/systems/quests/quest_objective_system.lua` |
| `src/systems/quest_system.lua` | `src/systems/quests/quest_system.lua` |
| `src/systems/recovery.lua` | `src/systems/actors/recovery.lua` |
| `src/systems/recruitment_system.lua` | `src/systems/locations/recruitment_system.lua` |
| `src/systems/relationship_system.lua` | `src/systems/social/relationship_system.lua` |
| `src/systems/reputation_system.lua` | `src/systems/social/reputation_system.lua` |
| `src/systems/service_system.lua` | `src/systems/services/service_system.lua` |
| `src/systems/skill_system.lua` | `src/systems/actors/skill_system.lua` |
| `src/systems/time_system.lua` | `src/systems/campaign/time_system.lua` |
| `src/systems/trader_system.lua` | `src/systems/items/trader_system.lua` |
| `src/systems/travel_knowledge_system.lua` | `src/systems/knowledge/travel_knowledge_system.lua` |
| `src/systems/visibility_system.lua` | `src/systems/parties/visibility_system.lua` |
| `src/systems/world_activity_system.lua` | `src/systems/world_activities/world_activity_system.lua` |
| `src/systems/world_encounter_system.lua` | `src/systems/campaign/world_encounter_system.lua` |
| `src/systems/world_events.lua` | `src/systems/campaign/world_events.lua` |
| `src/systems/world_generation_system.lua` | `src/world/generation/world_generation_system.lua` |
| `src/systems/world_navigation.lua` | `src/world/world_navigation.lua` |
| `units.md` | `docs/units.md` |

## 6. Where new features belong

All paths in this table describe the implemented final structure.

| New feature | First place to look | Other existing extension points when needed |
| --- | --- | --- |
| Goal | `systems/goals/goal_definitions.lua` for registration/construction, `goal_system.lua` for selection/completion behavior; `goal_state.lua` for record operations | Archetype goals/capabilities in `data/npc_archetypes/`; `ecs/components/npc_goals.lua` only if representation actually changes; `npc_goals_scenario.lua` and relevant service/recovery scenarios |
| World activity | Add `<name>_activity.lua` beside travel/raid/rest/roam in `systems/world_activities/`; register it in the existing `ACTIVITY_TYPES` table in `world_activity_system.lua` | Shared pursuit helper, goal requests, and existing scenario runner; do not create another activity registry |
| Service | Extend `systems/services/service_system.lua`; caravan-specific execution stays in `caravan_system.lua` | Existing capability/goal definitions, relevant location policy, `ui/screens/service_viewer.lua`, and `services_scenario.lua`/`caravan_scenario.lua`. There is no generic service-definition folder or requirement for a new module per service |
| NPC archetype | `data/npc_archetypes/<id>.lua`, then its `index.lua` manifest | Troop template in `data/units/` through `data/troops.lua`; profiles/culture roles under `data/population/`; hydration in `systems/population/npc_factory.lua`; names and dialogue in their existing data groups |
| Location kind | `data/locations/<id>.lua`, then `data/locations/index.lua` | Resident/garrison profile in `data/population/locations/` and its index; placement/population in `systems/population/`; rules/actions in `systems/locations/`. Authored site overrides belong in the existing options/fixture flow, not a resurrected static-location catalog |
| Quest | `data/quests.lua` for templates and `data/npc_quest_pools.lua` for offers | Runtime in `systems/quests/`, dialogue in `data/dialogues/`, quest log presentation in `ui/screens/quest_log_screen.lua` |
| Combat mechanic | `systems/battle/combat_system.lua` and the existing decision/execution helpers as appropriate | `data/skills.lua`, `data/statuses.lua`, equipment data, battle assemblage, simulation, and combat scenarios. Campaign consequences go in `systems/campaign/`, remains in `systems/battlefield/` |
| Inventory, item, or loot behavior | `systems/items/`; authored equipment/items in `data/items/` through `data/items.lua` | Inventory/shop screens and existing loot resolution scenarios |
| Map generation/navigation | `world/generation/` or `world/world_navigation.lua`; settings in `data/world_generation.lua` | Existing loader selection in `game/game_initializer.lua`; deterministic debug map stays in `debug/campaign_map.lua` |
| UI or developer tool | Player presentation in `ui/screens/` or `widgets/`; inspection/fixtures/commands in `debug/` | Keep `ui/screens/debug_overlay.lua` as the presentation of debug tools, using `debug/` for commands/state |

A feature does not automatically need edits in every listed location. Follow the existing extension points that its behavior actually uses.

## 7. Migration impact and constraints

### Lua imports and module identity

For each moved Lua file, derive the exact old/new module names by removing `.lua` and replacing `/` with `.`. For example:

```lua
-- Before
require("src.systems.goal_system")
require("src.ecs.systems.execution_system")
require("src.systems.painted_map_loader")

-- After
require("src.systems.goals.goal_system")
require("src.systems.battle.execution_system")
require("src.world.generation.painted_map_loader")
```

Update the complete old name wherever used, including runtime code, inline/lazy imports, data validators, scenario imports, stored module strings, and code samples. Do not globally substitute a prefix such as `src.systems.location_actions`: its old child module has a different destination from the old parent module. Use exact longest-name matches and the manifest.

Important caller surfaces include `main.lua`, `src/game/game_initializer.lua`, `src/game/campaign/campaign_runtime.lua`, `src/game/battle/battle_simulation.lua`, game states, other systems, assemblages, `src/world/map.lua`, UI screens/widgets, debug tools, `src/data/population/catalog.lua`, and `tests/unit/*.lua`. The file move and all its caller updates belong in the same commit, even where callers themselves are not moving.

No changes to `package.path`, `love.conf`, or the project launch directory are needed. Do not add old-path aliases or forwarding files: two module names can create duplicate module instances/state and make completion of the move hard to verify. Restart the LÖVE process after each batch rather than relying on cached modules.

### Registration and dynamically stored paths

| Mechanism | Required treatment |
| --- | --- |
| `location_action_registry.lua` | Update stored module strings as well as imports: `src.systems.location_actions` becomes `src.systems.locations.location_actions`; `src.systems.location_actions.examine_wizard_tower` becomes `src.systems.locations.examine_wizard_tower`. Keep action IDs and method names unchanged. Exercise `validateHandlers()`, which `GameInitializer.beginNewGame()` already calls. |
| `world_activity_system.lua` | Move the coordinator and update callers. Implementation modules retain their existing paths, so its current `ACTIVITY_TYPES` imports and activity IDs do not need a redesign. |
| `battle_simulation.lua` | Update decision/execution module imports; keep `world:addSystems(DecisionSystem, ExecutionSystem)` and execution order unchanged. Actual Concord registration remains explicit. |
| `ecs/components/init.lua` | No component paths move. Keep all marker registration and component names, including `battleUnit`, unchanged. |
| `core/state_manager.lua` | State files and registered state names remain unchanged. Only a moved module imported by state code requires an update. |
| `data/definition_registry.lua`, data manifests and aggregates | Their directories and names remain unchanged. Existing `require(prefix .. name)` resolution stays valid. `data/population/catalog.lua` must update its imports of goal definitions and the location-action registry. Do not replace explicit manifests with filesystem discovery. |
| Tests using `package.loaded` | Inspect any module-name strings when updating scenarios. Current reload assertions in `data_definitions_scenario.lua` target unchanged data catalogs; do not rewrite those keys simply because other imports change. |

### Tests and fixtures

Keep the test directory, filenames, scenario API, and explicit registration in `tests/unit/main.lua`. Its root derivation strips `/tests/unit`, and single-scenario selection accepts flat names ending in `_scenario`; moving tests into domain folders would require runner changes for little present benefit. The `unit` label includes wider scenario/integration checks; leave the historical name.

Update scenario imports, fixture module references, and any path assertions only where they name moved files. Fixtures retain entity IDs, seeds, archetypes, timestamps, and expected behavior. Debug fixtures in `src/debug/` remain at their existing paths.

The current `run_tests.bat`, `run_all_tests.sh`, `_runner_setup.lua`, and `navigation_tests_runner.lua` are alternate launcher/setup files with hard-coded paths or setup assumptions. Leave their implementation alone in this cleanup; do not use launcher modernization as a reason to move the suite. The current `tests/unit/main.lua` is a LÖVE test-project entry point; invoke the **directory** from the repository root:

```powershell
love tests/unit
love tests/unit npc_goals_scenario
love .
love . --debug-campaign
```

Use the existing installed LÖVE executable's full path if `love` is not on PATH. These are proposed migration checks, not claims that they passed during this assessment.

### Assets, saves, and packaging

- No asset paths move. Preserve all `src/assets/...` strings, sprite names, raw-art numeric identifiers, and the map generator's `src/assets/map/generated/<seed>/` export paths. Moving generator source does not move its output.
- No save-format, component-name, entity-ID, action-ID, archetype-ID, faction-ID, event-name, or `love.conf` identity changes are planned. Keep the current serialization behavior; do not rename content keys to match directories.
- Keep `src/assets/sprites/rawunits/` (343 files) and current unit sprite groupings despite their size. They hold related art, not unrelated code responsibilities. Separating authoring art from runtime art requires provenance/loading/package evidence beyond this organization pass.
- Keep `generation.png`: its use/provenance is not established sufficiently to choose a new home. Do not assume it is disposable output.
- Keep vendored Concord and the `love.app/` bundle intact. No custom release file-list configuration was identified in the inspected project files; verify any external packaging scripts include new source paths when migration is implemented.
- `audio/`, `production/`, and `$TEMP/` currently contain no files in the inspected workspace. Do not populate, rename, or delete them as part of this plan. Leave tracked `.DS_Store` and ignore-rule housekeeping to a separate cleanup.

### Documentation and editor guidance

When implementing each batch, update affected live code links, path examples, and module-path comments. Known documents with affected paths include:

- `docs/POPULATION_AUTHORING.md`, `DEBUG_CAMPAIGN.md`, `DEBUG_MODE.md`, and `FACTION_CONTRACT.md`;
- `docs/CAMPAIGN_ARCHITECTURE.md`, `BATTLE_RESOLUTION_A2.md`, `WORKFLOW_CYCLES_A3.md`, `campaign-battle-results.md`, and `map-generator.md` where their references use moved modules;
- `docs/ARCHITECTURAL_ASSESSMENT.md`, `DATA_MODEL_AUDIT.md`, and milestone reports where clickable source links would otherwise break;
- moved `docs/quest_procedural.md` and any other root-relative examples in the three moved notes.

Search all text, including slash-form paths without a leading `src/` and absolute `D:/Projects/Realm-of-Geherra/...` links; the list above is a review checklist, not a substitute for searching. Preserve historical findings and archived source snapshots, including those in `DATA_DEFINITION_CONCEPTS.md`. Update links meant to navigate to current code; retain intentionally historical paths in quoted snapshots and identify them as historical.

Check incoming links to the three moved notes and rebase any relative links inside them for the extra `docs/` path segment. Keep the project overview at root. Add a short navigation pointer to this plan from the existing overview during the documentation migration, then update that pointer if this proposal is superseded.

`.github/copilot-instructions.md` currently names the layered layout and root design docs. Update that guidance to name the domain folders and consolidated docs when the moves land; do not relocate assistant skills. `.vscode/launch.json` launches the workspace root and uses it as its script root, so it needs no path change.

## 8. Approved migration sequence (all batches completed)

Before implementation, preserve the existing data-cleanup work in the user's chosen working state. Do not reset, stash, or commit unrelated changes automatically. Capture a baseline of `love tests/unit`, normal startup, and the debug campaign on the same content revision. If a baseline check fails, record that result and compare subsequent checks against it; do not roll behavior fixes into a path move.

For every batch: move only the listed group, update all exact imports/stored paths and live documentation references, check that no executable references to the old module names remain, then run focused checks. Keep exports, initialization order, validation, and function bodies unchanged. Land a separate reviewable commit per batch; the order below does not require merging unrelated feature work.

| Batch | Mechanical scope | Existing checks most relevant |
| --- | --- | --- |
| 1 | Move the three root notes into existing `docs/`; add `.md` to `EMERGENT_GAMEPLAY`; fix note links/navigation guidance | Review links and names; no runtime check needed for notes alone |
| 2 | Move quest systems and `src/quests/objective.lua` into `systems/quests/` | `data_definitions_scenario`, normal dialogue/quest offer and quest log |
| 3 | Move the three goal modules into `systems/goals/`; coordinator into existing `world_activities/` | `npc_goals_scenario`, `world_activity_scenario`, `travel_activity_scenario`, `roam_activity_scenario` |
| 4 | Move location rules/actions/registration/recruitment and the single tower handler into `systems/locations/` | `location_types_scenario`, `data_definitions_scenario`, `faction_identity_scenario`; new-game handler validation and tower/recruitment actions |
| 5 | Move the four population modules into `systems/population/` | `population_scenario`, `retinue_scenario`, `inline_party_scenario`, `debug_campaign_scenario` |
| 6 | Move the three generator/loader modules into `world/generation/`; navigation into `world/` | Existing navigation tests through full runner; normal generation and debug campaign; preserve generator selection |
| 7 | Move party/visibility modules into `systems/parties/` | `raid_visibility_scenario`, `travel_activity_scenario`, `raid_encounter_scenario` |
| 8 | Move actor helpers into `systems/actors/`, then the two service modules into `systems/services/` in a separate commit | `recovery_scenario`, `services_scenario`, `caravan_scenario`; actor/inventory presentation smoke check |
| 9 | Move inventory/equipment/loot/trader modules into `systems/items/`; then battlefield modules into `systems/battlefield/` in a separate commit | `loot_resolver_scenario`, `battlefield_remains_scenario`, `battlefield_interaction_scenario`; inventory/shop smoke check |
| 10 | Move battle combat/decision/execution modules into existing `systems/battle/`; headless driver into existing `game/battle/` | `combat_regression_scenario`, `battle_simulation_scenario`, `headless_battle_scenario`; visible battle smoke check |
| 11 | Move the six campaign modules into `systems/campaign/`; keep campaign runtime in place | `campaign_runtime_scenario`, `world_time_sync_scenario`, `world_encounter_scenario`, `campaign_battle_result_scenario`, `campaign_battle_resolution_scenario`, `world_events_scenario` |
| 12 | Move knowledge hooks into `systems/knowledge/`; social modules into `systems/social/` in a separate commit | `knowledge_scenario`, `battle_knowledge_scenario`, `travel_knowledge_scenario`, `debug_mode_scenario`; dialogue smoke check |
| 13 | Remove only emptied source directories; reconcile final tree, authoring guidance, and plan path examples | Full `love tests/unit`, `love .`, `love . --debug-campaign`; confirm staged changes are only moves and path/documentation edits |

Keep the final end-state tree visible while batches are in progress, but mark which groups have migrated; do not describe proposed paths as already existing.

No new gameplay tests are required solely to prove that files moved. Existing scenarios and startup flows exercise registration and imports. Do not bulk-`require` every file in plain Lua: battle rendering creates LÖVE graphics resources at load time, and some modules register components or subscribe to lifecycle behavior.

Completion criteria:

1. Every manifest source has moved to exactly one destination; no duplicate compatibility modules remain.
2. Existing three battle helpers and five activity implementations retain their paths.
3. Old executable module references are absent, including action registry strings. Historical quoted paths may remain explicitly identified.
4. Existing scenario/startup behavior matches baseline; module registration order and data keys remain unchanged.
5. The feature-location table describes the actual tree, and live source links resolve.

## 9. Files and directories to keep in place

Everything absent from the manifest stays in place, specifically:

- Root `main.lua`, `conf.lua`, `PROJECT_DEFINITION.md`, `generation.png`, and `skills-lock.json`.
- All `src/core/`, `utils/`, `entities/`, `libs/`, and `assets/` files.
- All `src/data/` files and current index/aggregate locations, including the working-tree data cleanup and archived-concept document.
- `src/ecs/world.lua`, all components and assemblages, their registration entry point, and all component identifiers.
- Existing `src/game/` files, including states, initializer/context, campaign runtime, and battle simulation/context; only their moved dependencies' import paths change.
- Existing `src/systems/battle/{battle_unit_system,range_utils,render_system}.lua` and `src/systems/world_activities/{pursuit,raid_activity,rest_activity,roam_activity,travel_activity}.lua`.
- `src/world/{camera,map,scene_loader,world}.lua`. The older world container and scene loader have no matching active import found in the inspected source/tests; that is not enough reason to remove or relocate them in a file-organization task.
- All `src/ui/` and `src/debug/`, including the debug overlay screen, knowledge/event text helpers, and fixed debug campaign map.
- All test files, runners, fixture locations, and scenario names.
- Existing `docs/` files and names; their live links/examples may need updates during migration.
- `.github/`, `.vscode/`, `love.app/`, and current local empty directories. Guidance may need wording updates; their locations do not.

## 10. Deliberate limits

No architecture audit, gameplay fixes, data-model revisions, save migrations, dependency changes, dead-code purge, file-size cleanup, asset reorganization, or test-runner rewrite is included. Keeping existing suffixes, some small content folders, and the campaign runtime's single-file directory costs less than renaming or flattening them.

The main migration risk is a missed import or stored module string, particularly the location-action registry and callers spread across data validation, debug tools, UI, and tests. Small complete batches, fresh-process checks, and exact-path searches address that risk without introducing compatibility scaffolding.


## 11. Implementation record

Completed on 2026-10-28 in the documented batch order. All **63 Lua files and 3 documentation files** reached their exact manifest destinations. Created **13 directories** (12 system-domain folders and `src/world/generation/`); removed only the three emptied directories `src/quests/`, `src/ecs/systems/`, and `src/systems/location_actions/`. The two existing system-domain folders, all existing battle/activity helpers, assets, generated-map destinations, vendors, data locations, test locations, and editor launch configuration stayed in place.

### Batch verification

Every source-move batch checked destination existence, source absence, and obsolete executable module references before running its checks in fresh LÖVE processes. There were no relocation-related scenario failures.

| Batch | Moves | Result and checks |
| --- | ---: | --- |
| 1 | 3 docs | Complete; note paths, incoming links, navigation references reviewed |
| 2 | 4 Lua | Complete; `data_definitions_scenario` passed |
| 3 | 4 Lua | Complete; `npc_goals_scenario`, `world_activity_scenario`, `travel_activity_scenario`, `roam_activity_scenario` passed |
| 4 | 6 Lua | Complete; `location_types_scenario`, `data_definitions_scenario`, `faction_identity_scenario` passed, including handler validation, tower action and recruitment |
| 5 | 4 Lua | Complete; `population_scenario`, `retinue_scenario`, `inline_party_scenario`, `debug_campaign_scenario` passed |
| 6 | 4 Lua | Complete; full 34-scenario suite and navigation tests passed |
| 7 | 4 Lua | Complete; `raid_visibility_scenario`, `travel_activity_scenario`, `raid_encounter_scenario` passed |
| 8 | 10 Lua | Complete; actor modules followed by service modules; `recovery_scenario`, `services_scenario`, `caravan_scenario` passed |
| 9 | 10 Lua | Complete; item modules followed by battlefield modules; `loot_resolver_scenario`, `battlefield_remains_scenario`, `battlefield_interaction_scenario` passed |
| 10 | 4 Lua | Complete; `combat_regression_scenario`, `battle_simulation_scenario`, `headless_battle_scenario` passed |
| 11 | 6 Lua | Complete; `campaign_runtime_scenario`, `world_time_sync_scenario`, `world_encounter_scenario`, `campaign_battle_result_scenario`, `campaign_battle_resolution_scenario`, `world_events_scenario` passed |
| 12 | 7 Lua | Complete; knowledge modules followed by social modules; `knowledge_scenario`, `battle_knowledge_scenario`, `travel_knowledge_scenario`, `debug_mode_scenario` passed |
| 13 | 0 | Complete; empty-directory removal, final structure/guidance/link reconciliation and full validation |

### Baseline and final checks

- The original working-tree inventory matched all 66 manifest sources and all 59 direct system-root Lua files. An external byte snapshot preserved the starting contents, including uncommitted and untracked work.
- `love tests/unit` passed before migration, after batch 6, and after all source moves: **all 34 scenarios and navigation tests passed**. There were also 34 focused scenario invocations across the batches.
- Normal startup (menu → New Game → painted generation → population → world) and debug startup (`--debug-campaign` → debug generation → population → world) passed against both preserved pre-migration sources and migrated sources. An external temporary LÖVE harness invoked the real `main.lua` callbacks and exercised world update/draw; no test scaffolding was added to repository code. Final UI smoke checks exercised inventory, quest log, shop, dialogue/quest-offer refresh, and visible battle update/draw.
- Location `validateHandlers()` passed during new-game setup and explicitly. Existing location scenarios exercised tower and recruitment dispatch. Battle simulation scenarios verified Concord decision/execution registration; explicit `addSystems(DecisionSystem, ExecutionSystem)` ordering is unchanged, as are component names and registration.
- Every Lua file was compared with its pre-migration contents after applying only exact manifest path substitutions. Function bodies, gameplay data, APIs and simulation ordering are preserved. Asset/vendor bytes, `conf.lua`, archived `DATA_DEFINITION_CONCEPTS.md`, and the pre-existing Git index were also verified unchanged. Generator output strings still use `src/assets/map/generated/<seed>/`.
- All manifest destinations exist, all sources are absent, no compatibility copies remain, and no obsolete executable imports or stored action-handler module strings remain. All 386 local links in current `docs/`, the project overview, and Copilot guidance resolve, including source links with relative paths and absolute Windows paths. Historical source names in this plan and archived concepts remain intentionally historical.
- `git diff --check` passed. Existing line-ending notices from Git are informational, not whitespace failures.

### Pre-existing issue outside migration scope

A broader final literal-import scan found two existing references to the missing `src.utils.json` module in `src/utils/serializer.lua` (serialization and deserialization). Both references and the missing module predate this migration; no repository callers of the serializer were found. The serializer remains byte-identical to baseline. This unrelated issue does not affect the passing scenario/startup checks and was not repaired. All other literal `src.*` imports resolve.

### Deviations and working-tree handling

There are **no deviations from the file-move manifest or final directory structure**, and no unresolved migration issues. Batch commits described in the original plan were not created: the migration remains uncommitted and unstaged alongside the user's pre-existing changes, with the original index preserved. No reset, stash, unrelated fix, compatibility wrapper, dependency, or new repository validation script was introduced.

Final Git state on branch `qwen-local`: 100 modified, 68 deleted and 73 untracked files with `--untracked-files=all`; nothing staged. These counts include existing user changes and show moved files as deleted sources/untracked destinations until staged. The 68 deleted paths comprise 66 migration sources and the two pre-existing data deletions.
