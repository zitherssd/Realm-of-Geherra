# Realms of Geherra — Combat System Design v2

**Date:** 29 October 2026  
**Status:** Agreed design directions and explicit open balancing/engineering decisions. This document describes **target behavior**, not code already implemented.  
**References:** `BATTLE_SYSTEM_AUDIT.md` (actual implementation snapshot); `COMBAT_SYSTEM_DESIGN_V1.md` (prior proposal); `image(9).png` (user deployment sketch).

## 1. Vision and invariants

- Continuous non-grid battle on a long horizontal rectangle. Opposing sides generally deploy at left/right and advance toward the center.
- RPG stat rolls govern melee combat; simulated geometry governs movement, projectile interception and areas. Avoid a full 3D physics simulation.
- Both interactive and headless encounters use the same underlying `BattleSimulation` and outcome rules. Player input and renderer remain presentation/control layers.
- Build a small set of reusable behaviors: **delivery → geometric interaction → resolution → effects**. Don't create an elaborate general-purpose ability engine merely to satisfy this plan.
- Keep campaign actors/parties authoritative; battle entities and transient morale, formations, commands and projectiles exist only during battle.
- Do not incidentally change the established melee or damage arithmetic while adding geometry or ranged systems. The implementation audit identifies existing differences from some earlier design discussions.

## 2. Actor characteristics

| Property | Agreed target | Notes |
|---|---|---|
| `size` | Actor top-level value, nominal scale 1–10; human 3, horse 4, ogre 5 | Already exists; used for radius and projectile geometry |
| `stats.precision` | Persistent attribute, base 10 | Influences aiming error and shield contest |
| `stats.morale` | Persistent attribute, base 10 | Resistance to negative morale shocks |
| `battleMorale` | Transient, 0–100, starting at 100 provisionally | Hesitation/flight/rout mechanics |
| `stats.strength`, `attack`, `defense` | Keep existing mechanics | Ordinary Defense does not dodge projectiles |
| `heightMultiplier` | Creature/anatomy parameter; default humanoid about 4 | Can be assigned at template/actor level; no per-weapon archetype required |

### Physical geometry

- **Ground footprint:** circle with `radius = 6 × size` as initial scale (thus human Size 3 → radius 18, the existing default). Radius formula is a **provisional calibration constant**.
- **Vertical hit volume:** upright cylinder (same ground circle, height above the ground). `height = radius × heightMultiplier`.
- Example provisional proportions: human multiplier 4, wolf 2, bear 2.5, horse 3, ogre humanoid 4. The precise values are not yet approved as catalog data.
- **No varied ground shapes** in v2: circles for all creatures, even long-bodied ones; no body-part hit locations.
- Positioning uses the ground footprint; projectiles test footprint **and** vertical overlap. Render scaling and physical geometry should be conceptually distinct.

## 3. Ordinary movement and collisions

- Similar-sized enemies obstruct ordinary movement. Walking does not routinely cause injury or permit crossing an occupied enemy line.
- Allies cooperate: bounded local adjustment, temporary squeezing and recovery; the player can move through a packed friendly line with nearby soldiers yielding slightly.
- Size matters: sufficiently larger creatures can push through much smaller allies **and enemies** during normal walking. This is primarily positional and ordinarily deals no damage.
- Large creatures must not be trapped behind much smaller allies. Tiny creatures should not shove giants out of the way.
- No rampant pushing chains, indefinite overlap, uncontrolled jitter or tunneling. Use collision-aware movement, short local sliding/yielding, and bounded displacement. Avoid advanced crowd simulation unless playtests reveal a need.
- The size difference required for passive enemy displacement, mass/resistance calculation, and solver constants are **not yet finalized**. They are tunable implementation details, not a license to change agreed behavior.
- Packed formations resist displacement more than isolated fighters, using proximity/physical support if possible rather than a magical formation-type defense bonus.

## 4. Unified attack organization

Separate the following concerns without overengineering:

1. **Delivery:** direct melee, moving projectile, point-to-point arc, instant area, charge/moving body.
2. **Geometry:** melee reach, height-aware swept missile path, line/circle/cone exposure, body/body contacts.
3. **Resolution:** existing melee opposed roll; physical ranged intersection plus optional shield contest; AoE guaranteed effect on intersection; charge overpower/resistance.
4. **Effects:** damage using current damage-type protections, status, healing, morale shock, displacement, explosion.

### Melee compatibility

The audit reports live melee as injury-adjusted Attack + **two** `rollExploding(8)` against injury-adjusted Defense + offhand shield bonus + **two** `rollExploding(8)`; ties miss. The helper permits just **one** extra die on a maximum roll. Furthermore, offhand shield Defense currently appears both in derived battle stats and as an extra term. These are existing implementation facts, **not new intended changes**. Fixing a shield double-counting bug or changing dice behavior must be done as a separately approved, tested change.

## 5. Precision, trajectory and projectiles

### Locked principles

- Every physical projectile has time of flight. It does **not** track the intended target after release. Targets can move into/out of its path.
- Precision influences initial aiming deviation. Ballistic shots may deviate laterally **and** in intended landing distance. No fixed per-item type enum such as `arrow` vs `javelin` is needed for the flight solver.
- Flight is described by numeric parameters such as **speed** and **arc** (`arc = 0` means straight, e.g. a fireball). Arrow-like examples use faster, shallower arcs; javelin-like examples use slower, higher arcs.
- Initial launch height should normally be **derived from the launching actor's height** / launch point, with an optional skill override only when needed. Aiming at a creature can derive target impact height; it is not an individual head/chest simulation.
- A projectile advances until **ground impact, successful unit hit, shield interception, or leaving the battlefield** (with a robust safety bound). It must **not disappear just because it reached the originally aimed position while still airborne**.
- Check all swept segments per tick to prevent high-speed objects skipping targets; order encounters by distance/time along flight, including moving units as practical.
- Test both horizontal circle and vertical cylinder coverage. A shallow arrow or high-arcing javelin can pass over front ranks and reach rear targets. A straight low fireball is more likely to strike the first obstruction.
- The projectile is indifferent to faction: may strike unintended enemies **or allies**. AI may estimate friendly-fire risk before launching.
- No secondary miss roll for **unshielded** units: a geometric projectile-body intersection is a hit and uses normal damage/protection.
- **Shield-bearing** targets get an opposed block contest. Their ordinary Defense stat does not contribute; Size matters through physical geometry, not another roll modifier.
- Normal arrows/javelins **stop on hit or block**; on a non-blocking shield failure they hit and stop. The older design possibility of a 'miss-through' is superseded by the no-secondary-hit-roll decision. A projectile passing over a cylinder is a geometric miss and continues.
- Special future piercing missiles might pass through targets, but are not implemented as part of the initial work.

### Locked shield check

`attackerTotal = precision / 8 + 2eD8`  
`blockTotal = 2eD8 + 2 × shieldDefense`  
If `attackerTotal > blockTotal`, projectile beats the shield and hits; otherwise shield **blocks**, consumes appropriate durability and stops the projectile. Keep Precision fractional and **ties block**. The existing dice helper's actual behavior must be recognized in tests. Shield Defense is read once from the shield item; do not accidentally add combined actor Defense or count the shield twice.

**Not locked:** dispersion distribution/scale, per-skill arc magnitudes, projectile speed calibration, physical launch-fraction, stationary/leading aim, how `arc` is parameterized (absolute height vs normalized strength), and shield directionality (initially omnidirectional is an acceptable abstraction).

### Trajectory engineering note

A convenient *candidate* for a path over horizontal progress `t` is `z(t) = z0 + (zTarget-z0)t + 4 × arcHeight × t × (1-t)`. But the projectile must **continue past the intended x/y point** with a physically/visually coherent continuation until ground or valid termination. This exact equation is an engineering option, **not a fixed specification**. Any implementation must handle continuation and consistent speed/duration rather than teleporting at an endpoint.

## 6. Area abilities and magic

- Geometries: **circle, cone, line**. Self-centered circle is a circle centered on caster.
- Circle-vs-area intersection counts: if any part of a creature's physical ground circle overlaps the area, it is affected.
- **Uniform** effect throughout the area, no distance falloff.
- **No regular hit roll** for an AoE: intersection applies the effect, subject to existing damage protections and explicitly configured effect rules.
- Destructive area attacks can affect allies; beneficial effects filter to eligible targets.
- **Fireball:** straight projectile may collide with an obstruction and create an instant circle explosion (also resolve a ground/endpoint detonation when designed/configured). **Dragon breath:** immediate cone, optional windup, one application per creature. **Lightning:** line example.
- Animation duration need not equal damage duration. **Sustained/repeated-pulse AoE is deferred** until a concrete use case exists.
- Area effects can apply status, morale shocks, forced movement, damage or healing as appropriate. Explicit center/line/cone geometry must work independently of future spell catalog names.

## 7. Squads and their saved configuration

- Squad concept is **battle-only**; no persistent world-map squad entities. But a campaign **party saves squad member assignments**, formation choice and relative deployment offsets.
- Player commands each squad directly, no officer requirement. Initial allotment: **one squad**; progression to more squads is a future question.
- Saved assignments survive Charge and battles. Actors who escape retain squad membership; deceased actors are removed/ignored. New recruits can be assigned to squads; invalid references should be validated/cleaned.
- NPCs can use the same battle representation and commands with a suitable party reference actor; no extra NPC campaign hierarchy required.

## 8. Deployment UI — reference sketch is authoritative

**Reference:** `image(9).png`. A square map of **the player's side** of the long horizontal battlefield, in natural battlefield orientation. For the player starting left, **enemy direction is to the RIGHT**, not upward. Use a conspicuous arrow/label on the right and optional 'rear deployment space' on the left.

- Fixed player marker **toward the forward/right part of the square**, **not at center**. Allow a little room to place a forward line **in front of the leader**, but **most available deployment area is behind (left of) the leader**.
- Schematic colored circles for squad members, with labels (e.g. infantry line closer to enemy, archers behind); avoid pretending this is a grid or making users place each soldier individually.
- Drag squad formations as a unit; choose line or box. Automatically pack them tightly based on Size radii plus tiny stabilizing gap. **No spacing control.**
- Validate squad footprint boundaries and inter-squad overlap; fit or gently adjust when party composition changes.
- Units face **enemy side** as their formation orientation, regardless of player sprite facing or retreating.
- When parties start from opposing sides, world-to-local horizontal offsets may be mirrored; UI should remain intuitive with forward toward enemy.

## 9. Following and charging

### Follow / Hold / On Me

- A single command concept: hold or re-form the squad's shape while following only **the leader's horizontal X displacement**. Leader moving in Y **does not pull formations vertically**. Preserve each squad's deployed vertical anchor independently.
- Squad anchor: conceptual `anchorX = leaderX + savedSideAdjustedOffsetX`, `anchorY = savedDeploymentY`. This is a desired location, not teleportation.
- **Units attack enemies within usable range under Follow/Hold**, including melee, reach weapons, ranged weapons and spells. Follow does not mean cease fire.
- Do not pursue faraway enemies beyond reasonable formation tolerance. When obstructed, hold ground, fight or wait instead of planning an elaborate route through the opposing line.
- Formation slots are **not bound permanently to actors**. Upon returning from Charge, regenerate valid slots for surviving non-fleeing members, assign based on convenient current positions, then stabilize assignments to avoid swapping jitter. As casualties occur the line shrinks / box adjusts.

### Charge (squad order, distinct from a charge *ability*)

- Abandon formation entirely as a movement objective; units act independently and aggressively seek engagements.
- Archers continue shooting while ammo remains; javelin throwers use available throws before melee; similarly casters prefer usable ranged offensive abilities. Exhausted ranged options permit melee fallback.
- Temporary cooldown must **not** be mistaken for exhausted ranged options. A caster with spells on cooldown should not automatically sprint into melee.
- Packed second ranks need not all path toward the front: those with reach attack, flank units may spill around, some remain behind and exploit local openings. No requirement that every fighter always reach the foremost rank.

### Combat role tendency

**No mandatory `melee/ranged/skirmisher/caster` actor role field.** Derive primary engagement behavior from currently known/equipped offensive skills, ammunition/charges, range and cooldown. Additional cautious/fragile caster preference is **unresolved**; consider a small tactical preference only after observing actual failures. No separate general-purpose role framework in the initial milestones.

## 10. Morale, flight and battle result

- Permanent `stats.morale` baseline 10; battle-local morale 0–100, initially 100 (provisional start).
- Morale shifts with significant battle events: self takes serious damage; allies die/flee; enemies die/flee; leader defeat; fear/terror skills.
- **Own-squad ally deaths and flights affect a fighter more** than casualties in another squad. Nearby events generally matter more than distant ones. Enemy deaths and enemy flight produce morale gains.
- Low morale causes reluctance to advance while still allowing defensive combat. Individual morale reaching a low threshold triggers irreversible **fleeing** for this battle. No rallying.
- Fleeing units visibly run toward escape boundary, may be hit/killed before escaping, and do not obey Hold/Charge. Escaped actors remain with their party in campaign.
- **Squad rout** can trigger all current squad fighters to flee simultaneously; **party rout** can trigger all remaining combat-capable party fighters to flee. These are more than display-only labels.
- Rout checks are **event-driven on downward threshold crossings**, not rolled every tick. Batch multi-kill/AoE events to avoid multiple checks for the same blast. Avoid multiplying shocks by counting every simultaneously routed unit as a separate full-strength fleeing event.
- Squad rout probability depends primarily on member morale and permanent resilience; party rout depends on morale **and fraction of original fighting force already lost/fleeing**. No separate tactical-desperation estimator yet.
- **Open balancing:** hesitation/flight thresholds (illustrative 40/20), squad crossing thresholds (illustrative 60/40/25), chance curves, event values, distance attenuation, party thresholds. These are NOT locked final numbers.
- Fight ends when a side has no combat-capable non-fleeing fighters; outcome must account for fleeing-but-not-yet-escaped units and safe resolution at the end. Persist statuses, HP/injuries/equipment as existing result path requires.
- Results distinguish `survived`, `escaped`, `defeated` actors. Escaped actors not removed; defeated HP 0 actors remain casualties. Surviving defeated party may retreat on campaign map and avoid immediate re-engagement; location/retreat rules still need design and tests.
- Reconcile NPC-vs-NPC result applier, player BattleState outcomes, loot/plunder and raid lifecycle so survival is neither accidentally treated as victory nor erased.

## 11. Size, charges, displacement

- **Normal** big-creature movement may nudge aside much smaller allies/enemies without damage.
- **Charge as an ability** is explicit travel along an attack direction/path, contacting **multiple** units when it has power to break through, displacing/interrupting and optionally damaging them.
- Each encountered unit adds resistance; dense neighboring bodies can contribute support, stopping a charge sooner than isolated enemies.
- Use a shared **forced-displacement** mechanism for knockback, shield bash, tauren charges, monster slams and similar skills. Maintain collision/bounds and avoid endless pushing cycles.
- Factors: Size, Strength, charge force/momentum, local support. No approved numeric formula yet. Do not equate ability Charge with squad command Charge.

## 12. Implementation boundary and current code audit

Audit-named touchpoints (verify in current tree before editing):
- `src/ecs/assemblages/unit.lua` — persistent actor stats and size.
- `src/ecs/assemblages/battle_unit.lua` — transient battle stats, collision radii, assembly.
- `src/game/battle/battle_simulation.lua`, `battle_context.lua` — common battle logic.
- `src/systems/battle/execution_system.lua` — movement, skills, projectile stepping, AoE.
- `src/systems/battle/decision_system.lua` — AI and commands.
- `src/systems/battle/range_utils.lua` — reach based on radii.
- `src/systems/battle/combat_system.lua` — melee, projectile rolls, damage and shields.
- `src/systems/battle/render_system.lua` — drawn scale independent of physical geometry.
- `src/game/states/battle_state.lua` — interactive control/UI.
- `src/game/battle/headless_battle_runner.lua` — headless simulation.
- `src/systems/campaign/campaign_battle_result_applier.lua` — persist casualty/escape outcomes.
- Existing battle/injury/headless tests under `tests/unit/`.

**Audit cautions:** battle fixed-radius collision + single soft-push pass; `effectiveSkillRange` adds attacker and defender radii; target selection is center-distance nearest-hostile; some skill execution validations are inconsistent; player/headless use same simulation but different control/result UX; offhand shield bonus doubled in melee; exploding dice helper is capped to one extra die. Test these as *current behavior* and handle unrelated fixes separately.

## 13. Core acceptance scenarios

1. Human Size 3 still has radius 18; a larger ogre uses a larger physical radius, unchanged when rendering is disabled.
2. Crowded friendly infantry yield locally for player/ogre without endlessly overlapping or crowd oscillation.
3. Similar-sized enemy ranks block ordinary walking; giant can gradually displace much smaller enemies without damage.
4. Ordinary melee reach still accounts for physical radii; attacker does not strike past a target just because collision geometry changed.
5. In deployment UI, right = forward, player marker near right, most room to left; infantry may be ahead and archers behind.
6. The player's vertical movement does not move Follow formation; horizontal movement does. Facing stays toward enemy.
7. Follow units fight enemies within reach; Charge units abandon formation, but exhausted/ammo/cooldown behavior is sensible.
8. After Charge → Hold, surviving soldiers reform into nearest available positions, not their old personal slots.
9. High-arc thrown projectile passes over first rank and can hit second; straight fireball hits an intervening unit.
10. Moving unit changes whether/when a projectile intersects; projectile does not home or vanish in the air at old target position.
11. Unshielded geometric hit deals damage; shield contest uses exactly `Precision/8 + 2eD8` vs `2eD8 + 2×shieldDefense`, tie blocks.
12. Allies may intercept an arrow/javelin/fireball; AoE circle/cone/line applies once per eligible intersected unit with uniform effect.
13. A large creature's breath hits humans in cone even if only their collision circles overlap its edge; morale shock applies once.
14. Individual fleeing, squad rout, party rout, and escaped survivors all work in interactive and headless combat.
15. A tauren charging through multiple weak units stops against enough collective resistance; movement/knockback stays within bounds.

## 14. Explicitly open / deferred

- Distribution and numeric calibration of aim errors; lead targeting; relative height sampling; projectile speeds, launch fraction, arc magnitude/continuation and straight projectile endpoint detonation.
- Exact passive Size displacement threshold and solver details; forced movement/charge resistance and support calculations.
- Morale shock numbers, thresholds, probabilities, party retreat position/cooldown semantics and battle termination while units flee.
- Caster preference when permanently out of spells versus temporarily on cooldown; acceptable friendly-fire risk heuristic.
- Additional squad unlock system, sustained AoE, body-part hits, full ballistic physics, shields with directional coverage, special piercing missiles.

**Decision rule:** preserve settled qualitative behavior, use isolated configurable defaults for open numeric values, and validate with deterministic scenario tests and gameplay before calling them final.
