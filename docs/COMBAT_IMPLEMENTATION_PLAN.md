# Realms of Geherra — Combat Redesign Implementation Plan

**Date:** 29 October 2026  
**Source of truth:** `COMBAT_SYSTEM_DESIGN_V2.md` for intended mechanics and `BATTLE_SYSTEM_AUDIT.md` for actual code at audit time.  
**Implementation status:** planning only; no game code was inspected or modified in this deliverable.

## Delivery principles

1. One small milestone at a time; avoid broad refactors and unrelated bug fixes.
2. Every milestone uses the existing `BattleSimulation` in both headless and interactive battles.
3. Deterministic or seeded battle scenarios should demonstrate mechanics; report test commands and outcomes.
4. Preserve campaign data structures except where a milestone explicitly calls for an extension.
5. Where the design is still provisional, centralize constants and make them easy to tweak. Do not present sample values as approved balance.
6. Do not introduce class/role abstractions when skill/weapon capabilities already express behavior.
7. Maintain a readable before/after summary, relevant touched paths and known limitations after each milestone.

## Dependency map

`M1 geometry/movement` → `M2 squads/formations` → `M3 morale/flight`  
`M1 geometry` → `M4 precision/projectiles` → `M5 AoE`  
`M1 movement` → `M6 charges/displacement`  
`M2–M6` → `M7 AI, tests, balance`

M3 and M4 can potentially run independently after M2/M1 respectively, but should not be merged into one agent task.

## M1 — Physical geometry, Size and collision-aware movement

**Goal:** Replace fixed-radius and fragile soft-push behavior with consistent Size-based circles and reliable movement interactions; prepare height metadata without launching a projectile overhaul.

**Audit touchpoints:** `src/ecs/assemblages/unit.lua`, `src/ecs/assemblages/battle_unit.lua`, `src/systems/battle/execution_system.lua`, `src/systems/battle/range_utils.lua`, `src/game/battle/battle_context.lua` and tests. Verify all real call sites in current tree.

**Scope:**
- Derive battle radius from top-level actor Size using provisional `6 × size`, default Size 3 → 18.
- Store battle height using radius and explicit/default anatomy multiplier, but do not rewrite projectile paths yet. Define a single source of truth for geometry.
- Improve separation and movement: enemy blocking, limited ally squeezing/yielding, passive passage by sufficiently larger actors; no walking contact damage.
- Prevent out-of-bounds movement, severe overlaps, self-pushing, repeated jitter, and collisions missed during normal movement. Keep movement responsive at existing tick rate.
- Preserve all currently working melee/range behavior except intended changes caused by radii.

**Tests / acceptance:** human=18; 5-size ogre=30; mixed sizes respect bounds; allies pass cooperatively; similar enemy blockers stop passage; significantly larger actor can get through smaller allies/enemies without automatic damage; dense crowd stabilizes; headless battle can run; interactive player can pass friendly line. Check non-render mode and battle teardown.

**Not in M1:** Squad config/UI, new skills, rewritten projectiles, Precision/Morale stats, arbitrary shove/charge ability, shield formula changes, unrelated melee/dice corrections.

**Risk / design choice:** Passive displacement must remain modest; if large actors bulldoze whole armies just by walking, constrain magnitude and choose thresholds in one documented config. Avoid a broad collision library if small focused helpers suffice.

## M2 — Saved squad setup, deployment and orders

**Goal:** Battle-only squads, saved party assignment/formation/deployment, schematic UI closely matching provided reference image, Hold and Charge.

**Likely touchpoints:** party save/party system (discover), `battle_simulation.lua`, `battle_state.lua`, `decision_system.lua`, `execution_system.lua`, battle formation/layout helper, UI module, tests.

**Scope:** one initial squad; saved members/config on party; deployment UI with enemy right and forward player marker; line/box tight slots based on radius; party-side mirrored transforms; Follow tracks leader X only; Hold fights nearby; Charge abandons formation; re-form with re-assigned slots; player commands each squad.

**Tests:** UI placement boundary rules; enemy right orientation; marker near front; leader Y movement does not drag troops; X movement does; attacks under Hold; Charge movement; shift from Charge back to Hold reassigns nearby slots and handles casualties; no ghost squads in campaign or headless.

**Open design constraints:** reliable companion/party leader identification; saved configuration schema versioning; battle setup for NPC sides without interactive UI.

## M3 — Morale, fleeing, routing and campaign results

**Goal:** transient individual morale and multi-level routs with persistent survivors.

**Likely touchpoints:** stat defaults, combat damage/status event emission, battle context/simulation, decision/execution movement, headless results, `campaign_battle_result_applier.lua`, interactive battle completion and raid/loot integration tests.

**Scope:** stats.morale=10; battleMorale 0–100; proximity- and squad-weighted morale gain/loss; hesitation; irreversible flee; physical exit; squad and party rout threshold-cross checks; batched AoE/death morale events; `escaped` distinct from `defeated`; proper campaign survivors and outcomes.

**Tests:** own squad death larger morale loss; enemy deaths yield gains; group rout triggers single meaningful shock; no repeated per-tick checks; flee cannot rally; fleeing actors still vulnerable; escaped actor remains with party; both headless and interactive path handle alive defeated parties; avoid raid re-engagement loop.

**Open balancing:** event magnitudes, checks and thresholds, escape boundaries, final outcome when last fighter has started fleeing but is still present.

## M4 — Precision, projectiles and shields

**Goal:** Height-aware physical missile travel and ranged impact through Precision and shields.

**Likely touchpoints:** unit stat defaults, skill/projectile catalog/overrides, `execution_system.lua`, `combat_system.lua`, geometry helpers and test scenarios.

**Scope:** precision base 10; numeric speed/arc plus derived launch height; lateral/range aim deviation; swept 2D+height hits against moving units; team-neutral contact; keep flying past aim coordinate until ground/hit/block/bounds; no dodge roll if unshielded; shield contest Precision/8+2eD8 > 2eD8+2×shield item Defense, tie blocks; block damages shield durability; projectile stops on block or hit.

**Tests:** fast projectile cannot tunnel; moving target gets no homing hit; high arc clears front unit; straight fireball cannot pass through first low obstacle; friendly fire; shield tie/block/durability; normal unshielded collision always hits; aim position does not despawn missile above ground.

**Open balancing:** spread distribution, speed, arc height scaling, strike height, endpoint handling for spell projectiles. Do not make per-item `arrow`/`javelin` physics classes.

## M5 — Reusable instantaneous area abilities

**Goal:** Circle/cone/line effect geometry and coherent skill delivery without hit rolls inside area.

**Likely touchpoints:** skill definitions/overrides, `execution_system.lua`, `combat_system.lua`, area geometry helpers, AI targeting, tests.

**Scope:** instantaneous area evaluation and unit circle intersection; uniform effects; team-neutral destructive effects and filtered beneficial effects; fireball explosion on impact; dragon-breath cone; once-per-target effect; existing protection/status/injury/morale event integration.

**Tests:** cone edge intersects giant/human correctly; no repeated hit per large target; allies receive destructive effect; healing only applies to configured beneficiaries; animation doesn't duplicate damage; identical headless/interactive damage outcomes for same seeded setup.

**Deferred:** sustained hazards and periodic AoE tick damage.

## M6 — Explicit charge and knockback abilities

**Goal:** Reusable forced displacement and creature breakthroughs distinct from squad Charge order.

**Likely touchpoints:** skill definitions, `execution_system.lua`, geometry/movement solver from M1, combat and effects helpers, AI ability selection, tests.

**Scope:** moving attack with contacts along swept path; overpower against Strength, Size and local support; multiple contacts with gradually reduced force; knockback obeys boundaries/other bodies; no independent physics engine; use shared displacement for future skills.

**Tests:** tauren breaks through several weak soldiers; stops against sufficiently supported rank; large walking creature still only nudges (no automatic damage); displaced actors remain in bounds; no duplicate multi-hit damage in one charge unless skill expressly allows it.

**Open balancing:** force and momentum formulas, support definition, damage formula, interrupt/on-hit morale effects.

## M7 — AI improvements, regression and balance

**Goal:** Make units sensibly operate the new mechanics without imposing hard-coded permanent combat-role labels.

**Likely touchpoints:** `decision_system.lua`, skill/equipment queries, tests and combat scenarios; renderer/UI polish as needed.

**Scope:** choose primary engagement distance from currently usable ranged options; cooldown ≠ exhausted; ammo depleted → melee; spells on cooldown → wait/reposition, not instant melee; safe-shot approximations; sensible AoE and charge use; avoid pathfinding obsession for blocked second-rank infantry; improve tests and tune constants.

**Tests:** archer under squad Charge fires before ammo depletion and then can melee; javelin user throws before closing; caster doesn't melee on a short cooldown; Hold fires/attacks without pursuing; friendly-fire-aware target choice; runs across player and NPC headless battles.

## Cross-cutting regression gates

- Baseline existing scenario suites: battle simulation, headless battle and injury cases from the audit. Discover the repository's current commands; do not invent a test runner.
- Battle context isolation and cleanup; deterministic RNG where feasible; time/cooldown correctness.
- Campaign result correctness: injuries, HP, equipment, statuses, escaped members, casualties, empty party removal.
- Loot/plunder and raid encounter lifecycle remain consistent when a losing party survives; no instantaneous re-engagement exploits.
- Debug overlays or reproducible scenario scripts for geometry/projectiles are valuable, but should remain opt-in.

## Implementation governance

For each milestone ask the coding agent to: inspect relevant paths → implement only scope → add tests → run relevant tests → report touched files, behavior, assumptions, PASS/FAIL, and deferred issues. Fix failures attributable to the milestone. Do **not** silently rewrite unrelated combat mechanics to make new tests pass.
