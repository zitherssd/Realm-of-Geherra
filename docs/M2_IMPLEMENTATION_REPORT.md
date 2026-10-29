# M2 implementation and refinement

M2 only. Existing unrelated working-tree edits are preserved; no M3 mechanics added.

## Current functionality

- Capacity sums living eligible actors' `attributes.command`: 0 gives 0 squads, 1–2 gives 1, 3–4 gives 2. Eligibility reuses player/companion troop definition types and the important-NPC `npc` component; ordinary troops do not contribute even with Command. No new progression/eligibility fields.
- Capacity increases never create squads. Existing squads remain; N explicitly creates one up to capacity. Excess squads consolidate into the first retained squad when capacity falls. Removing a squad similarly retains its actors. Zero configured squads use a temporary battle group; at zero capacity this provides no configuration rights. Actor rosters remain authoritative.
- World-map P pushes Party Deployment on the existing state stack. P/Escape pops it back to the world. Campaign time pauses through normal state-stack behavior. No battle world is created by this editor.
- N creates, Delete removes, Tab selects, L/B changes formation, and dragging positions member circles. Click a roster actor to move it to the selected squad; scroll the roster for larger parties. The commander marker remains fixed near the forward/right edge. Bounds and inter-squad collision circles are validated before placement changes.
- One shared layout implementation serves the campaign editor and BattleSimulation. NPCs use the same generator mirrored across the battlefield. Invalid layouts are repacked; line formations that cannot fit after roster consolidation fall back to box. Preferences live on campaign parties and survive battles. Runtime squads remain plain battle-local records referencing Concord units.
- Battles start immediately using saved deployment; the pre-battle phase and Enter confirmation are removed. Player groups default Hold, NPC groups Charge, including headless battles.
- Existing M2 commands retain instant execution, 5-tick recovery and individual 60-tick cooldowns, with execution-boundary guards. Hold keeps X-only commander following and stable proximity slot reassignment; Charge drops formation objectives. Offensive ranged options remain preferred through cooldown until supplies are exhausted.
- AI MOVE intents enable local avoidance for both Hold and Charge. The M1 solver reports the actual blocking unit after yielding/displacement fails. After three consecutive movement actions with less than one collision substep (2 world units) of progress toward the destination, a battle-local bypass records that blocker, one fixed side, and a Size-based action budget capped at 16. Goal changes, arrival, and meaningful direct progress reset the stuck count; cooldown calls do not count. Side selection checks flank clearance and swept step validity. Tangential steps with an outward component may temporarily move away from the goal. The unit resumes direct movement when its goal segment clears the blocker or the blocker dies. Target changes reset the stuck counter but preserve an active bypass when that same blocker remains in the new route. Exhausted attempts wait/retry direct movement rather than starting endless detours. Manual movement retains direct control.
- The 24-unit movement budget, battle_speed cooldown formula, injury adjustments, visual interpolation, allied yielding, enemy blocking and large-unit displacement are unchanged. No hit/damage formulas, projectile physics, morale, fleeing or later-milestone mechanics changed.

## Files changed for this refinement

- `src/game/battle/squads.lua`: Command capacity, creation/removal/transfers, consolidation/fallback, shared layout and placement validation.
- `src/ecs/assemblages/party.lua`: starts with no automatically configured squads.
- `src/game/battle/battle_simulation.lua`: consumes shared layouts directly.
- `src/game/states/party_deployment_state.lua` (new): campaign deployment editor.
- `src/core/state_manager.lua`: registers the deployment state.
- `src/game/states/world_state.lua`: P entry and control hint.
- `src/game/states/battle_state.lua`: removes pre-battle deployment UI and gate.
- `src/systems/battle/decision_system.lua`: enables local avoidance on AI movement intents.
- `src/systems/battle/execution_system.lua`: bounded local direction probes within existing movement execution.
- `tests/unit/m2_refinement_scenario.lua` (new): focused refinement checks.
- `tests/unit/squads_scenario.lua`: explicit capacity/configuration fixture.
- `tests/unit/battle_simulation_scenario.lua`: immediate battle startup fixture.
- `tests/unit/main.lua`: registers refinement scenario.
- This report.

## Validation

Run a scenario with `& 'C:\Program Files\LOVE\lovec.exe' tests/unit <scenario_name>`.

PASS — 13 relevant scenarios run individually:

- m2_refinement_scenario
- squads_scenario
- battle_movement_scenario
- battle_simulation_scenario
- headless_battle_scenario
- combat_regression_scenario
- campaign_battle_resolution_scenario
- campaign_battle_result_scenario
- raid_encounter_scenario
- data_definitions_scenario
- injury_scenario
- inline_party_scenario
- campaign_architecture_milestone_1_scenario

The refinement scenario covers Command 0–4, additive companion/NPC contributions, troop exclusion, no automatic squad creation, capacity loss and consolidation to zero, temporary fallback, API and roster-click transfers, explicit removal, bounds rejection, world-map P entry/close, drawing, campaign preference persistence, immediate shared battle placement, NPC fallback Charge, collision-safe avoidance around a large enemy, bounded packed-frontline attempts, <=24-unit movement and unchanged cooldown ranges at battle_speed 10 and 20. Original M2 and M1 scenarios retain geometry, formation, command recovery/cooldown, headless and displacement checks.

PASS — navigation checks and `git diff --check`.

FAIL — the full sequential runner still stops at `party_speed_scenario.lua:9` (expected speed 80), the same failure observed before this refinement. Unrelated speed/time/recovery code was not changed. The other historical full-suite failures listed in the previous turn were not re-audited in this refinement.

## Remaining limitations / manual checks

- Manual checks remain for drag feel, visual layout at different resolutions, and crowded combat balance. The referenced original mockup is unavailable.
- Mixed Size formations retain automatic spacing based on the largest member radius, allowing stable slot reassignment without undersized slots. There is no spacing control.
- Avoidance is deliberately local. Units may wait when a small detour cannot resolve a blockage; it is not global pathfinding. The Size-based bypass budget (at most 16 movement actions) is provisional gameplay calibration.
- Preferences persist between battles on campaign objects. The repository's disk save/load functions remain stubs, so across-process persistence is not implemented or verified.
- Parties that physically cannot fit the deployment area still raise an explicit capacity error. No reserves or battle waves were added.

## Latest obstacle-only refinement

Root cause: the former target-relative direction probes rejected any step that increased target distance by more than 2 world units. They did not identify the blocker or retain a route around its footprint; the short retry budget then left the unit stuck. Near a large creature, an initial outward step can be necessary even with an open route. Increasing retries alone would not fix the direction filter.

Changed files for this refinement only:
- `src/systems/battle/execution_system.lua`: collision solver returns its blocker; swept-circle/clearance probes and persistent, bounded blocker-relative bypass replace the old target-relative avoidance.
- `tests/unit/battle_movement_scenario.lua`: actual Size 5 ogre and Size 8 dragon regression at center/top/bottom positions, plus an allied dragon pinned against the lower boundary. Verifies a necessary move away, stable side/blocker identity, destination arrival, direct-mode resumption, unchanged dragon position/HP, collision separation (including existing allied compression), <=24-unit steps and no movement during cooldown.
- This report.

The added regression failed before the fix and passes afterward. Latest individual results: PASS battle_movement_scenario, m2_refinement_scenario, squads_scenario, battle_simulation_scenario, headless_battle_scenario, combat_regression_scenario, injury_scenario. PASS git diff --check. No failures in these relevant checks; the full campaign suite was not rerun for this obstacle-only change.

Hold/Charge targeting remains in DecisionSystem and was not changed. Their movement intents share the fix. Existing M1 yielding and displacement run before bypass initialization and remain intact. No unrelated systems or later milestones changed. Manual crowded-battle playtesting remains; local bypass deliberately stops when a short clear route cannot be found.

## Stuck-only bypass trigger refinement

Root cause: bypass previously began on the first collision and skipped direct movement while active. A short backline obstruction therefore committed the soldier to a detour even though waiting for normal allied movement would have sufficed.

The existing movement function now counts consecutive actions with negligible destination progress and enters the existing bypass only on the third failure. Successful direct progress, a changed goal, and arrival reset the count. The early cooldown return is unchanged, so time spent cooling down does not count. Active bypass retains its side and existing bounded budget until the goal segment clears the blocker; it does not reset on each tangent step. No new navigation system, collision solver changes, squad command changes or combat changes.

Files changed for this refinement: `src/systems/battle/execution_system.lua`, `tests/unit/battle_movement_scenario.lua`, and this report. Regression additions cover unobstructed backline lanes, one/two-action temporary obstruction with no detour, cooldown calls not incrementing failures, direct-success and changed-goal resets, third-failure activation, and waiting behind a supported allied frontline. The previous ogre/dragon bypass cases remain intact.

PASS: battle_movement_scenario, m2_refinement_scenario, squads_scenario, battle_simulation_scenario, headless_battle_scenario, combat_regression_scenario, injury_scenario, git diff --check. The full campaign suite and manual crowded-battle playtesting were not rerun. The three-attempt delay and 2-unit progress threshold are fixed local calibration values; units intentionally wait where a bounded detour cannot find a clear route.

## Target-death / retargeting correction

A reported soldier began rounding an ogre, then walked back into it after its target died. The previous goal-change reset cleared both the stuck counter and the active bypass on every new destination, including small movements of the same target. This discarded the side/budget even when the obstacle was unchanged.

Changed only the movement reset in `src/systems/battle/execution_system.lua`: changing destinations still resets pre-bypass failure counting, but the active bypass is evaluated against the new goal using the existing blocker/segment check. If the same blocker remains in the route, the existing side and remaining budget persist. If the route is clear, direct movement resumes. Target changes do not replenish bypass budgets; manual movement and arrival still clear avoidance state.

Added a regression in `tests/unit/battle_movement_scenario.lua` using DecisionSystem: a soldier rounds an allied Size 5 ogre pinned at the lower boundary, its enemy target dies, and AI selects another enemy behind that ogre. The test verifies that the route object, side and decreasing budget survive retargeting; subsequent target movement cannot restart/replenish the bypass; relocating the target to a clear route resumes direct movement. This regression failed before the correction and passes afterward.

PASS: movement, squads, M2 refinement, battle simulation, headless battle, combat regression, injury scenarios, and diff checks. No full campaign rerun or manual playtest for this correction. Changed files: execution_system.lua, battle_movement_scenario.lua and this report.
