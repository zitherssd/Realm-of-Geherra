# M4 — Precision and physical projectiles

Implemented 2026-10-29. Existing uncommitted M3 work was retained.

## Changed files (M4 scope)

| File | Change |
| --- | --- |
| `src/ecs/assemblages/unit.lua` | Permanent Precision default of 10; existing template stat overrides apply. |
| `src/ecs/assemblages/battle_unit.lua` | Precision fallback for older/custom actors; existing equipment bonuses apply. |
| `src/game/battle/projectiles.lua` | Shared aim sampling, numeric projectile defaults, XYZ flight, swept cylinder collision, physical range, termination, and approximate AI path exposure. |
| `src/data/skills.lua` | Data-driven arrow skill with a shallow arc; existing javelins retain their higher arcs and spells retain straight trajectories. |
| `src/game/battle/battle_simulation.lua` | Optional `options.projectileRng` passed to launch sampling for deterministic runs. |
| `src/systems/battle/combat_system.lua` | Replace Size-based percentage hit roll with strict Precision/exploding-d8 projectile defense; usable shield checks and existing durability handling. Melee formulas retained. |
| `src/systems/battle/execution_system.lua` | Integrate flight into existing tick loop and projectile collection; resolve actual earliest impacts, friendly damage, statuses, and existing fireball splash at impact. |
| `src/systems/battle/decision_system.lua` | Prefer less exposed reachable enemies within existing skill priorities; veto obvious nearby friendly obstruction while accepting melee exposure. |
| `src/systems/battle/render_system.lua` | Project battlefield Y minus physical Z; remove duplicate decorative arc; render arrows and elevated fire trails. Screen-shake randomness uses LÖVE's separate visual RNG. |
| `src/ui/widgets/stats_panel.lua` | Display Precision. |
| `tests/unit/projectile_scenario.lua` | Deterministic M4 geometry, aim, defense, damage, targeting, termination and rendering parity checks. |
| `tests/unit/injury_scenario.lua` | Stub projectile defense independently of injury RNG instead of expecting the removed percentage-roll call. |
| `tests/unit/main.lua` | Register M4 scenario. |

Other modified/untracked M3 files shown by `git status` predate this task.

## Model and assumptions

- All aiming/flight defaults and AI exposure thresholds are centralized in `projectiles.lua`. Lateral and depth coefficients are independent. Each launch samples exactly two independent continuous uniform deviations. Neither aim nor defense reads battle morale, Size accuracy bonuses, or melee Defense.
- Speed is battlefield pixels per simulation tick, arc/radius/range are pixels, and lifetime is ticks. Per-skill `projectile.speed`, `arc`, `radius`, `maxRange`, and `maxLifetime` override defaults. No projectile-type flight branches exist.
- Launch Z is 90% of shooter height; aim Z is 80% of target height (or launch Z for an empty point). The parabola continues beyond progress 1 until ground or another termination. Straight shots continue too; their linear Z slope, if any, also continues.
- Motion uses at most 8-pixel horizontal sweep segments. Each segment tests horizontal circle entry/exit against vertical cylinder entry/exit, then chooses the earliest intersection before ground/range/bounds. This is a deterministic numerical approximation of the parabola; physical range accumulates 3D segment lengths. Projectile radius expands the collision cylinder.
- Units occupy their current discrete tick positions when flight updates after movement. This follows the existing movement model; no interpolation or future movement prediction is used for collisions.
- Shooter exclusion lasts only for the initial travel through its launch footprint; the shooter can subsequently enter its own flight path. Dead and escaped units do not block projectiles. Team never filters physical collision.
- Every geometric unit contact gets the specified defense roll. Shielded defense successes count as blocks and consume existing durability once; other defenses are evades. A successful hit stops the projectile. A successful defense ends gameplay interaction but lets a harmless visual continue along the existing trajectory until ground/range/bounds/lifetime expiry. Successful impacts use existing damage, injury, morale and status paths.
- Fireballs retain their existing splash radius and on-hit burn. A successful direct contact or ground impact triggers splash at the physical impact point; the direct unit is excluded from splash to prevent double damage. Splash can affect either side and uses projectile defense. A defended projectile continues as a harmless visual without further collisions, damaging splash, explosion or hit-contact circle. Range/bounds/lifetime expiry does not inflict splash. This retains the existing special effect without adding an M5 AoE model.
- AI uses expected centerline height, near-shooter obstruction, and nearby allied exposure as a soft target cost. Weapon priority, charges, cooldowns, ranged-before-melee, formations and player command execution retain their existing paths. Player fire does not consult this heuristic.
- Arrow is available as a skill definition; no new bow equipment or automatic unit loadout changes were added.

## Validation

Command: `& 'C:\Program Files\LOVE\lovec.exe' tests/unit projectile_scenario`

**PASS**: Precision defaults/overrides; independent once-per-shot deviations; distance/Precision scaling and morale independence; fast swept impacts; moving targets entering/leaving paths; cylinder radius/height; high arcs over allies; short/long ground positions; continuation beyond aim into other units; initial shooter grace; earliest contact independent of roster order; friendly damage; strict defense ties and unshielded four-die rolls; shield wear/break and broken-shield exclusion; hit/defense/ground/range/bounds/lifetime termination; no duplicate direct damage; fireball splash/statuses; AI obstruction/safer targeting/accepted melee/player override; 180 seeded ticks producing identical positions, HP and projectiles with drawing enabled versus without presentation.

Ran every scenario registered in `tests/unit/main.lua` independently, so an early failure did not hide later checks: **44 PASS, 7 FAIL**. Navigation tests also passed in the aggregate run. `git diff --check` passed.

Passing regressions include injury and treatment, equipment/inventory, M1 movement/sliding, M2 squads/commands/regrouping, M3 morale/Combat Power, interactive battle simulation, headless battles, campaign battle results/resolution, raids, casualties/remains, and loot.

The seven failures are **pre-existing**:

| Scenario | Failure |
| --- | --- |
| `party_speed_scenario` | Line 9 assertion. |
| `combat_regression_scenario` | Line 72 spear expected-HP assertion. This stops later checks within that scenario. |
| `personality_return_home_scenario` | Line 26, `5.3333333333333 ~= 12`. |
| `recovery_scenario` | Line 165, ordinary goal did not resume. |
| `world_encounter_scenario` | Line 48, clock did not return elapsed game hours. |
| `world_time_sync_scenario` | Line 201, world-hour/world-second conversion. |
| `campaign_runtime_scenario` | Line 92 assertion. |

The aggregate suite already failed at `party_speed_scenario:9` before editing. To classify later failures, each was also reproduced in a temporary module overlay restoring the pre-M4 combat/projectile/AI code while retaining the existing M3 guards and damage callbacks. The original injury fixture passed in that overlay; its RNG assumption was updated for M4 and now passes with the new code.

Full outputs: [current scenario results](../tests/m4_test_results.txt), [baseline comparison](../tests/m4_baseline_results.txt).

No new failures remain in the independent scenario run. No manual balance playthrough or large ranged-army performance benchmark was performed. Numerical arc subdivision and the intentionally approximate AI heuristic remain the balancing limitations; no M5 work or additional squad commands were added.
