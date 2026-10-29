# M5: geometric area-of-effect combat

Implemented M5 only. No new catalog spells, persistent areas, status framework, or M6 mechanics.

## Geometry and delivery

`src/game/battle/aoe.lua` owns exact circle, angular-sector, and capsule intersection against each battle unit's existing Size-derived `collisionRadius`. Geometry uses battlefield X/Y, includes tangent/partial contact, and ignores height, obstructions, and grids. Cone intersection uses containment, the radial arc, and closest points on both radial segments; it does not approximate a cone with a triangle. A line's width is its full diameter, including rounded endpoint caps. Negative dimensions clamp to zero; cone angles clamp to 0–2π. A directionless raw shape uses +X; a cast aimed at its own origin uses the caster's facing.

Skills specify an `aoe` table. Dimensions are world units; angles are radians. Existing skill `range` remains in its existing scaled units (42 world units per range unit). Example definitions, usable with the current skill lifecycle:

```lua
aoe = {shape="circle", radius=33.6, eligibility="all"}
aoe = {shape="cone", length=150, angle=math.pi/3, eligibility="all"}
aoe = {shape="line", length=200, width=24, eligibility="enemies"}
-- Optional directional origin; otherwise the caster is the origin:
aoe = {shape="line", origin={x=300,y=200}, length=200, width=24}
```

Circle centers follow the selected battlefield point or live target at resolution. Cone/line directions run from their origin to that point/target; dimensions do not scale with aim distance. Windups retain existing point-versus-target behavior. All shapes use the existing interactive point-target UI, execution, range validation/fallback, cooldowns, and charges. Representative cone and line definitions exist only in tests.

Target selection snapshots and deduplicates all living, unescaped intersecting actors before resolving any effect. `all` (the default), `allies`, and `enemies` filter shape intersections by existing team equality. The caster has no special immunity. Each selected actor receives the skill's damage, healing, and configured on-hit statuses once; routing, source death, or changes in a later actor's position do not rerun selection. Existing damage calculation, protection, injuries, HP, defeat, and independent M3 casualty/rout events remain authoritative. No attack, Precision, projectile-defense, or shield-defense roll occurs for an area victim. Normal damage variance still rolls d6s. Healing caps at max HP and does not revive a lethal damage recipient.

## Fireball migration

Fireball now declares a circle of radius 33.6, retaining its previous radius calibration, damage, burn, and timing. Physical projectile flight, aim error, swept contact, vertical trajectory, and launch behavior are unchanged.

`resolveProjectileContact` separates physical contact defense from payload delivery. `skill.projectile.defenseMode` accepts `"opposed"` (the default) or `"none"`. Fireball explicitly uses `"none"`: unit or ground contact immediately resolves its area at the actual projectile X/Y, without any projectile- or shield-defense roll. The contacted actor has no separate direct-damage component, so it receives explosion damage only once and only if eligible. Each area victim connects without defense rolls. Range, bounds, and lifetime termination create neither damage nor an explosion visual.

Other projectiles retain the opposed M4 formula. A block stops the projectile; an evade leaves only its harmless visual continuation. An opposed area projectile can still be configured explicitly; defended contacts suppress its payload. The focused correction tests cover shielded/unshielded fireball contacts, friendly interception, self-damage, protection/statuses, ground explosions, expiration, and default/explicit opposed arrow and javelin defense.

## Files

- `src/game/battle/aoe.lua`: reusable geometry, shape placement, and snapshot eligibility.
- `src/data/skills.lua`: geometric fireball definition.
- `src/systems/battle/combat_system.lua`: split physical contact and guaranteed area effects, retaining existing damage formulas.
- `src/systems/battle/execution_system.lua`: area execution and projectile payload migration.
- `src/systems/battle/range_utils.lua`: range handling for all geometric skills.
- `src/game/states/battle_state.lua`: point targeting for geometric skills.
- `tests/unit/aoe_scenario.lua`: deterministic M5 and focused compatibility checks.
- `tests/unit/main.lua`: registers M5 in the normal suite.
- `tests/m5_baseline_results.txt`, `tests/m5_test_results.txt`: isolated scenario baseline and final results.
- This document: design, assumptions, limitations, and verification.

## Existing limitations retained

- The battle executor does not consume the catalog's numeric `cost` field and has no mana resource mechanism. M5 preserves that behavior; existing ammunition/spell charges still use `maxCharges`/`charges`.
- Single-target `heal` has a catalog healing field but no healing execution path. M5 supports this field for area healing without changing unrelated single-target spell behavior. AI still skips healing skills; player point targeting can deliver ally-only area healing.
- Existing status application supports `onHitStatuses` (IDs or per-status configurations), overwrites an existing status of the same ID, and retains its existing duration/tick behavior. Burn/poison ticks remain actor statuses, not periodic areas. `stun`/`paralyze` gate actions. `freeze` is applied and expires, but its described slowdown is not implemented.
- Supported effect combinations are the existing flat `baseDamage`, `damageType`, `healing`, and `onHitStatuses` fields. No arbitrary effect list or new status types were introduced.
- Friendly/hostile relations follow existing team equality. Existing M4 AI launch-obstruction avoidance remains; it is not explosion immunity.
- Projected directional origins are explicit battlefield positions, not moving attachment objects.

## Verification

Initial M5 isolated run (before the configurable-defense correction): **44/53 PASS**, compared with **43/52 PASS** before implementation. The added `aoe_scenario` passes; no new scenario failures were observed. Existing passing regressions include movement, friendly sliding, squads, On Me regrouping, M2 refinement, Combat Power, battle simulation, headless battles, injuries/treatment, loot, campaign battle results/resolution, battlefield remains/interactions, world event logging, and projectile presentation.

Configurable-defense correction: **8/10 relevant scenarios PASS** (`aoe`, projectile presentation, battle simulation, headless battle, campaign battle result, campaign battle resolution, injury, Combat Power). `projectile_scenario` still stops at the pre-existing archer Precision assertion (now line 290); `combat_regression_scenario` still stops at its pre-existing javelin damage assertion on line 57. Focused arrow/javelin physical-defense checks run independently in `aoe_scenario`. `git diff --check` passes. The original result logs below remain historical M5 results.

The nine failing scenarios stop at the same assertions before and after M5:

| Scenario | Existing failure |
| --- | --- |
| `campaign_runtime_scenario` | line 92 assertion |
| `combat_regression_scenario` | line 57: javelin/main-hand damage expectation |
| `morale_scenario` | line 413: fleeing winners delaying victory; its earlier AoE casualty check passes |
| `party_speed_scenario` | line 9 assertion |
| `personality_return_home_scenario` | line 26 comparison, called at line 101 |
| `projectile_scenario` | line 288: archer Precision expectation, before its flight/defense cases |
| `recovery_scenario` | line 165: ordinary goal resume |
| `world_encounter_scenario` | clock conversion assertion, called at line 79 |
| `world_time_sync_scenario` | line 201: world-hour conversion |

The default aggregate runner reports **navigation PASS**, then **FAIL** at the existing party-speed assertion. Scenarios were therefore also executed individually so that early failures did not hide the remaining regression results. Focused M5 tests independently exercise the touched melee/projectile behavior and casualty opportunities. `git diff --check` passes.

See the result logs for exact commands, outcomes, and baseline comparison. The new M5 scenario covers geometry boundaries and degeneracy, Size-derived radii, overlapping/deduplicated actors, all eligibility modes, self/friendly damage, ally healing, multiple statuses, protection, absence of accuracy/defense rolls for area victims, fixed target sets, windup/cooldown/charges, all three delivery shapes, explicit origins/facing, physical interception, actual impact position, ground impacts, expiration, defended projectiles, single-target/melee compatibility, independent casualty rout opportunities, and 180-tick rendering-versus-headless simulation parity.

No manual interactive playthrough was performed. Existing scenario failures remain outside M5 scope; no M5.1/status refactor was started.
