# Battle system audit

Inspected: 2026-10-29. Scope: the current working tree, including pre-existing uncommitted changes. This is a static implementation audit, not a proposal or a runtime playtest. Statements below describe executable paths; data descriptions and comments are distinguished where they differ from those paths.

## 1. Execution model and relevant files

| File | Relevant functions and responsibility |
| --- | --- |
| [Actor assemblage](../src/ecs/assemblages/unit.lua) | `unitAssemblage`, `Unit.create`: hydrate persistent actors from troop definitions. |
| [Troop registry](../src/data/troops.lua) | Aggregates `src/data/units/*` definitions supplying stats, Size, skills and equipment. |
| [Battle assemblage](../src/ecs/assemblages/battle_unit.lua) | `battleUnitAssemblage`, `BattleUnit.create`: create transient battle entities and derive their combat values. |
| [Simulation](../src/game/battle/battle_simulation.lua) | `BattleSimulation.new`, `tick`, `getOutcome`, `buildResult`; local `addPartyUnits`, `addActorResults`. |
| [Context](../src/game/battle/battle_context.lua) | `BattleContext.new`; context closures `findNearestHostile`, `addUnit`, `removeDeadUnits`, `addProjectile`. |
| [Interactive state](../src/game/states/battle_state.lua) | `enter`, `update`, `_tick`, `checkBattleEnd`: input, tick scheduling, completion. |
| [Headless runner](../src/game/battle/headless_battle_runner.lua) | `start`, `run`, `Encounter:advance`, `cleanup`: run the same simulation without presentation or player control. |
| [Decision system](../src/systems/battle/decision_system.lua) | `update`, `_processAI`: command consumption and AI intent selection. |
| [Unit helpers](../src/systems/battle/battle_unit_system.lua) | `canAct`, `snapToWorld`: action eligibility and visual position synchronization. |
| [Execution system](../src/systems/battle/execution_system.lua) | `update`, `_executeMove`, `_initiateSkill`, `_completeCast`, `_executeSkillEffect`, `_updateProjectiles`, `_resolveAoeAtPoint`, `applyAttackResult`. |
| [Range helpers](../src/systems/battle/range_utils.lua) | `effectiveSkillRange`: skill reach in world coordinates. |
| [Combat system](../src/systems/battle/combat_system.lua) | `rollAttack`, `rollProjectileHitChance`, `calculateDamage`, `resolveAttack`, `resolveProjectileAttack`, `_applyBattleDamage`, `getEffectiveSkill`, `_getSkillModifiers`, `getTotalProtection`, `_getShieldDefense`, `_determineMissAction`, `applyBlockDurabilityLoss`. |
| [Renderer](../src/systems/battle/render_system.lua) | `update`, `draw`; local `getActorSizeScale`: interpolation, Size scaling and effects. |
| [Math helpers](../src/utils/math.lua) | `rollExploding`: random dice used for hits and damage. |
| [Injury system](../src/systems/actors/injury_system.lua) | `fromDamage`, `effects`, `stat`, `apply`: injury generation and combat penalties. |
| [Battle result applier](../src/systems/campaign/campaign_battle_result_applier.lua) | `validate`, `apply`: persist results to campaign actors and remove defeated actors. |

`BattleSimulation.new` creates a separate ECS battle world, registering DecisionSystem before ExecutionSystem. Each `tick` increments the tick counter, emits the systems' update event, then removes dead units. Actions resolve sequentially through system pools, rather than as simultaneous exchanges.

The interactive state schedules nominal 20 Hz ticks (`1/20` second), with at most five ticks per frame. It stops adding simulation time while the selected living unit can act and has no pending command. Rendering continues during this input wait. Headless encounters use the same tick logic with all units controlled by AI; their default limit is 4,000 ticks, after which surviving sides produce a timeout.

ExecutionSystem first decrements cooldowns, processes statuses and completes casts; next it consumes MOVE/SKILL intents; finally it advances projectiles. DecisionSystem has already selected intents before that execution pass. Numeric cooldowns, windups and status durations are tick counts, despite the battle assemblage's cooldown comment mentioning seconds.

## 2. Actor stats and battle derivation

`unitAssemblage` defaults persistent stats to health 100, attack 10, defense 10, world speed 10 and battle speed 10. Strength has no default in that table; damage calculation treats missing strength as zero. Troop definitions overwrite supplied stat keys. Actors start with current/max HP from health, Size 3, empty injuries, zero innate protections and basic `attack`; template skills replace that default list. Templates also set available equipment slots and equipped items (randomly choosing an entry when a slot contains a list).

`battleUnitAssemblage` keeps the actor reference and ID, but copies injuries, equipment, durability and status effects. It copies actor stats into battle stats, then **adds every equipped item's `stats` values**. Learned skills are copied, and equipped items add their `grantsSkill` entries. A sorted `skillList` drives the player UI. Limited skills receive their base definition's `maxCharges` at battle creation.

Battle `maxHp` is derived battle `stats.health`, defaulting to 100. Current HP uses `actor.hp` when present, otherwise battle max HP. Equipment-derived maximum HP does not automatically refill current HP. Damage reduces battle `hp`, not `stats.health`.

| Value | Implemented battle use |
| --- | --- |
| `attack` | Melee/AoE opposed hit roll; fallback 10; adjusted by injuries. |
| `defense` | Melee/AoE opposed defense roll; fallback 0 in the combat helper; adjusted by injuries. |
| `strength` | Adds `floor(strength / 2)` to damage, including projectiles and damaging spells. |
| `health` | Starting battle maximum HP. |
| `battle_speed` | Movement cooldown divisor, fallback 10; injury movement multipliers apply. Does not scale skill windup/cooldown. |
| `speed` | World-map stat; battle movement reads `battle_speed`. |
| `protections` | Flat reduction for the attack's damage type. |

The battle assembles a cached protection table by adding actor innate protections and protections from every equipped item. Initialized types are slashing, piercing, blunt, fire, ice, shock and poison. `calculateDamage` uses this cache when the requested key exists (including zero); otherwise `getTotalProtection` sums innate/equipment values directly. There is no percentage resistance or damage-type matchup calculation in this path.

Injuries do not rewrite base stats. `Injury.stat` adds injury attack/defense penalties and clamps at zero; movement multipliers multiply and have a combined minimum of 0.2. These derived values are read for opposed hit rolls and movement timing.

## 3. Size

Actor Size is the actor's top-level `size`, not a member of `stats`. `unitAssemblage` sets template Size and derives default profile and sight as Size × 10 (templates can override profile/sight). Those perception values are not consulted by battle target selection.

The battle assemblage does not copy Size to the battle entity. `rollProjectileHitChance` checks defender `size`, then `defender.actor.size`, then defaults to 3. Standard battle entities therefore use the referenced actor's Size.

Projectile accuracy starts at 70% for Size 3. Each point above 3 adds 5 percentage points; each point below 3 subtracts 15 percentage points. The result is clamped to 5–95%.

| Target Size | Single-target projectile hit chance |
| --- | --- |
| 1 | 40% |
| 2 | 55% |
| 3 | 70% |
| 4 | 75% |
| 5 | 80% |
| 6 | 85% |
| 7 | 90% |
| 8 or greater | 95% |

`getActorSizeScale` renders at `max(0.1, 1 + (Size - 3) × 0.1)`, followed by global visual scale 1.3. Size does not change the assembled collision radius (18), move step (24), movement cooldown, melee hit formula, protection, strength or skill range. It changes visual scale and single-target projectile accuracy through the paths above.

## 4. Positioning and movement

Battle positions are continuous two-dimensional world coordinates. Bounds are 1260 × 546. `addPartyUnits` places party A at X 180 and party B at X 1080. Each group fills five rows starting at Y 120 with 78-unit vertical spacing; subsequent columns advance 72 units toward the opposing side. Initial placement is based on roster order, not Size or an actor's formation/squad fields.

Logical `x/y` drive range, targeting, movement and impact checks. Separate `visualX/visualY` start snapped to logical position and interpolate in `RenderSystem.update` with factor `10 × dt`, snapping when both coordinate differences are below one unit. Sprite lunge, shake, arc, camera zoom and rendering order do not alter logical attack geometry.

`_executeMove` moves directly toward the requested point by `min(moveStep, distance)` (default 24), normalizing direction so diagonals have the same step length. It updates velocity, movement target/state and horizontal facing. Player movement uses WASD/arrows to request an adjacent step. AI repeatedly moves toward the nearest hostile when it cannot choose a usable skill. There is no terrain pathfinding, obstacle routing, formation movement or line-of-sight query in this battle path.

Local `clampUnitToBounds` keeps unit centers inside bounds with their collision radius as an edge margin. Local `resolveSoftPush` checks all other living units, regardless of team. For overlapping circles, it pushes the other unit by 35% of overlap and the mover backward by 25%, then clamps both. Near-coincident centers get a random two-unit push of the other unit. This is a single soft separation pass per move, not a hard occupancy restriction; overlap can remain.

After movement, both global and move cooldown receive `120 × (1 + variance) / effectiveBattleSpeed` ticks, with variance from approximately -0.1 to +0.1. At speed 10 this is about 10.8–13.2 ticks, with action readiness determined by subsequent unit decrements. `moveCooldown` is tracked/decremented, but global cooldown is the actual movement/action gate. The divisor is not given a positive minimum after `Injury.stat`.

Facing is 1 for left and -1 for right. Player-team units initially face right. Facing changes with movement/target direction but does not contribute a flank, rear or directional defense modifier.

## 5. Targeting, range and action eligibility

`BattleUnitSystem.canAct` requires HP above zero, global cooldown at or below zero, and no active table-form status whose catalog entry sets `canAct = false`. Stun and paralyze satisfy that last condition.

`context.findNearestHostile` treats any different team as hostile and chooses the smallest squared center distance among living units. It returns the unit and squared distance, optionally constrained by a center-based maximum range with 0.01 squared-distance tolerance. Equal-distance ties retain the first encountered unit. It does not inspect campaign diplomacy, sight or visibility.

`RangeUtils.effectiveSkillRange` computes `(skill.range or 1.5) × 42 + attackerRadius + targetRadius`. Targeted AoE instead returns only `(skill.range or 1.5) × 42`. With default radii, basic attack range 0.3 gives 48.6 world units center-to-center; spear's override 0.6 gives 61.2. The assembled `attackRange = 8` field is not consulted by this range helper or attack execution.

AI considers known skills against its nearest hostile. It checks skill cooldown, charges if limited, and effective range. It ranks eligible skills by `damageMultiplier or 0`, keeping the first strictly better candidate from `pairs` iteration. Current skill definitions do not set `damageMultiplier`, so this does not rank their actual base damage. With no eligible skill it moves toward the hostile; it does not kite or seek an alternate target to exploit another skill's reach.

The selected player unit receives commands instead of AI intents. Tab cycles sorted skills; Space selects the nearest living hostile within effective range for ordinary attacks. Targeted AoE enters point selection, initially at the nearest enemy (or player position); arrows/WASD move the point by 28, Enter/Space confirms and Escape cancels. Points are clamped to battlefield bounds.

At effect execution, an ordinary target must still be alive and in effective range (0.01 tolerance); otherwise execution falls back to the nearest hostile within range computed without the target radius. An explicitly supplied ordinary target is not independently checked for hostile team in this validation. Targeted AoE uses the selected point, or a living target's position if no point; an out-of-range point falls back to a hostile within its center-based range. No valid destination means no effect, cooldown or charge consumption.

Eligibility is enforced differently across paths: AI checks per-skill cooldown and charges, but player command production and `_initiateSkill`/`_executeSkillEffect` do not independently reject cooldown or depleted charges. Player action gating checks global cooldown. Neither execution nor command production deducts skill `cost`, and the executor does not validate skill ownership for an externally supplied intent.

## 6. Skill execution, melee and ranged attacks

Definitions are in [skills.lua](../src/data/skills.lua); equipment comes from [items.lua](../src/data/items.lua), including [melee weapons](../src/data/items/melee_weapons.lua), [ranged weapons](../src/data/items/ranged_weapons.lua) and [armor](../src/data/items/armor.lua).

`getEffectiveSkill` shallow-copies the registry definition and overwrites fields from the equipped item granting that skill. Modifier search prefers mainHand, then rangedWeapon, then other equipped slots. Overrides replace values rather than add them; nested tables such as on-hit statuses are replaced. Example: iron sword changes attack base damage from 3 to 8, spear changes attack damage type to piercing and range to 0.6, quarterstaff changes range and windup.

`_initiateSkill` starts a cast if effective windup is positive, setting global cooldown to windup. Each execution tick decrements cast remaining time; completion calls `_executeSkillEffect` and clears the cast. Death cancels a cast; completion does not recheck stun/paralyze. With zero windup the effect executes immediately. When a destination is valid, execution sets the skill cooldown and global cooldown to `skill.cooldown or 20`, and subtracts one charge for limited skills.

Dispatch depends on `projectile` and targeted AoE flags, rather than a general handler for every `type`:

- Ordinary effects without projectiles call `resolveAttack` on a single target.
- Targeted AoE without a projectile calls `_resolveAoeAtPoint` immediately.
- Projectile skills store attacker reference, skill ID/effective skill data and a fixed destination, then advance toward that destination each tick by projectile speed (default 10 world units/tick). Creation and the first advance can occur in the same tick.
- Targeted AoE projectiles resolve AoE when they arrive. Other projectiles choose a single impact target and use `resolveProjectileAttack`.

Single-target projectiles first use the original target if still alive and hostile, **without checking its distance from the fixed impact point**. If that target is unavailable, they choose the nearest living hostile within `26 + target collision radius` of the impact point. With no candidate, the projectile disappears without damage. There is no interception, collision along the flight path, homing update, cover or distance penalty. Projectile arc is a rendering property.

AoE checks all living opposing-team units around its point, using radius `max(24, (skill.aoe or 1) × 42 × 0.8)` plus each target's collision radius. Fireball's default AoE radius is 33.6, or 51.6 center distance for an ordinary target. Each target gets an independent `resolveAttack` opposed roll, even when the AoE arrived by projectile. There is no friendly damage or radial damage falloff in this loop.

Defined skills include attack, bite, dagger, shield bash, fireball, heal, two javelin variants, sling stone, frostbolt and lightning. Javelin variants initialize two and one charges respectively. `heal.healing = 50` exists in data, but there is no healing dispatch: without a projectile or targeted AoE it follows ordinary hostile attack execution. Similarly, cost fields and skill levels are not used in hit/damage arithmetic.

## 7. Hit calculations and defensive outcomes

### Opposed rolls (melee and AoE)

`rollAttack` computes:

- Attack total = injury-adjusted attack + two independent `rollExploding(8)` results.
- Defense total = injury-adjusted defense + offHand shield defense + two independent `rollExploding(8)` results.
- Margin = attack total minus defense total. Only a strictly positive margin hits; ties miss.

The skill argument contributes no accuracy modifier. Size, range within legal reach, facing, skill level and strength do not change this roll.

`_getShieldDefense` reads `stats.defense` from an offHand item whose type is armor. That same item's defense was already added to derived battle `stats.defense` during assembly. Thus a standard equipped shield's defense participates both in the assembled defense stat and in this extra shield term.

On a miss, `_determineMissAction` returns block only if shield defense is positive and removing the **extra** shield term would have made the margin positive; otherwise it returns evade. Block loses one shield durability through `applyBlockDurabilityLoss`; a shield reaching zero is unequipped and its durability entry removed. The helper also removes matching entries from an inventory if supplied, but standard battle units do not copy actor inventory. Cached battle stats, protections, skills and skillList are not rebuilt when a shield breaks. Ordinary successful weapon attacks do not consume weapon durability in these combat paths.

### Single-target projectile rolls

`resolveProjectileAttack` rolls `math.random(100)` and hits when the result is at or below the Size-derived percentage from section 3. It does not use attacker attack, defender defense or shield defense. Misses always return evade and do not consume shield block durability. On hit it uses the same damage calculation as melee.

### Actual die helper behavior

Despite the name/comments, `Math.rollExploding` only adds **one** extra die when the first roll equals the die maximum. Its loop condition compares the accumulated sum with that maximum; after adding any positive second roll, the sum exceeds it and the loop stops. Thus a d8 result spans 1–7 or 9–16 (not 8), and a d6 spans 1–5 or 7–12 (not 6). The hit and damage formulas above use that implemented helper, not an unlimited explosion chain.

## 8. Damage, statuses, injuries and persistence

`calculateDamage` refreshes the effective skill by ID and computes an integer:

`damage = floor(max(0, baseDamage + floor(strength / 2) + attack d6 - protection[damageType] - armor d6))`

Both d6 terms use the helper described above. Missing base damage and strength are zero; missing damage type defaults to blunt. Protection comes from the cached battle table or fallback sum. Attack/defense stats and hit margin do not increase damage. `damageMultiplier` is not applied. There is no critical hit, penetration, minimum-one damage or Size-based damage term.

`_applyBattleDamage` clamps HP at zero and reports defeat. For direct hits it passes actual HP lost to `Injury.fromDamage`. Only positive, nonfatal loss with a valid injury profile can generate an injury. The probability curves and weighted body-part/severity definitions live in [injuries.lua](../src/data/injuries.lua). One entry per body part is retained; a stronger injury can replace a weaker one. Injury effects can affect subsequent actions in the same battle.

`applyAttackResult` applies on-hit statuses whenever `result.hit` is true, including zero-damage hits. Local `applyOnHitStatuses` accepts list or map forms, reads list entries from [statuses.lua](../src/data/statuses.lua), and replaces the existing runtime entry for that ID (refreshing duration/tick counter rather than stacking instances).

Implemented catalog behavior:

| Status | Duration in ticks | Executed effect |
| --- | --- | --- |
| Burn | 120 | 1 direct HP damage every 20 ticks. |
| Poison | 90 | 2 direct HP damage every 20 ticks. |
| Stun | 30 | Blocks new actions through `canAct`. |
| Paralyze | 40 | Blocks new actions through `canAct`. |
| Freeze | 45 | Runtime duration and visual effect; no movement/action slowdown is applied by these systems despite its description. |

Status updates increment a tick counter, apply due damage, then decrement remaining duration and remove expired entries. Damage-over-time bypasses hit rolls/protection and calls `_applyBattleDamage` with the status flag, so it does not create injuries. Active casts continue decrementing during disabling statuses.

`context.removeDeadUnits` moves zero-HP battle units into casualties, removes them from live lookup/list and destroys their ECS entities after the tick. `getOutcome` declares victory when only one side has survivors, or draw when neither does. `buildResult` combines live units and casualties to record final HP, maximum HP, statuses, injuries, equipment and durability by actor ID.

`CampaignBattleResultApplier.apply` validates the completed encounter/result, writes HP/max HP/statuses, removes defeated actors from party rosters, and applies survivor injuries/equipment/durability. Empty parties are removed from the map when supplied. Encounter bookkeeping prevents applying the same result twice. Transient positions, cooldowns, casts, projectiles and remaining skill charges are not written back as actor results.

## 9. Inspection boundary

This document records static observations of the current battle implementation. Existing scenario files relevant to these paths include [battle simulation](../tests/unit/battle_simulation_scenario.lua), [headless battle](../tests/unit/headless_battle_scenario.lua), and [injury scenarios](../tests/unit/injury_scenario.lua). They were consulted as supporting references; no test suite or interactive playtest was run for this documentation-only task. No code, fixtures, configuration or exports were changed. No proposed mechanics or remediation plan is included.
