# M5.1-B implementation and validation

Implemented on the M5.1-A condition/stat modules, retaining the existing actor stores
and battle scheduler.

- Harassed: post-resolution melee hit/miss stacks; -1 Defense per stack; existing
  Defense floor of 1; every ten ticks decay max(1, floor(stacks * .20)). Applications
  preserve the decay counter. No global cap; projectiles and AoE never apply it.
- Burning refreshes without intensity stacking or periodic counter reset. Poison
  stacks its periodic damage and supports catalog/skill `maxStacks`. Existing
  durations and intervals remain unchanged. Pulses subtract effective typed
  protection (including signed protection) from the configured amount, then use
  normal battle damage/death/morale processing without hit rolls, injuries, shield
  wear, or ordinary on-hit effects. Expired entries cannot pulse.
- `Conditions.permits(actor, action)` shares restrictions across decisions, movement,
  initiation, effect execution, and windups. Stun/paralyze block all actions;
  immobilize blocks movement only. Application immediately cancels disabled windups;
  charges are still spent only on effect delivery, and the existing GCD remains.
- Single-target healing reuses the existing healing effect resolver, caps HP, accepts
  allies/self, and falls back to an injured ally/self rather than a hostile target.
  Interactive target selection includes injured allies and self. Existing AI does
  not acquire new healer behavior; AoE healing remains on its existing path.
- `BattleSimulation:buildResult` runs settlement once, locking its supplied tactical
  outcome. It uses the same `ExecutionSystem.tickStatuses` helper as tactical ticks,
  advancing finite HP-changing conditions only. No decisions, movement, casts,
  cooldowns, or projectiles run. Escaped survivors also resolve finite conditions.
  Dead actors cannot regenerate. Battle-only conditions are then removed and
  persistent conditions/injuries retained.
- Settlement is bounded at 10,000 ticks. `settlementTicks` and
  `settlementTruncated` expose its progress/limit. Tactical `ticks` stays unchanged,
  so campaign battle time does not grow during rapid settlement. Persistent finite
  conditions exceeding the bound keep their remaining state; battle-only entries
  are removed. Permanent periodic effects do not prolong or pulse in settlement.
- Results carry per-actor `tacticalHp` and `tacticalEscaped` alongside final state.
  Campaign and loot result validators use these snapshots for outcome consistency
  while using final HP for casualties, rosters, and eliminated-party accounting.
  Legacy result records without tactical snapshots retain their previous validation.
  Settlement deaths cannot change the winner, including when the winner loses every
  survivor. Campaign world events use final casualties and the tactical outcome.

Changed files for this batch (relative to the completed M5.1-A working tree):

- src/data/statuses.lua
- src/systems/actors/conditions.lua
- src/systems/battle/battle_unit_system.lua
- src/systems/battle/combat_system.lua
- src/systems/battle/decision_system.lua
- src/systems/battle/execution_system.lua
- src/game/battle/battle_simulation.lua
- src/game/states/battle_state.lua
- src/systems/campaign/campaign_battle_result_applier.lua
- src/systems/items/loot_resolver.lua
- tests/unit/main.lua
- tests/unit/conditions_b_scenario.lua (new)

Validation: ran every `tests/unit/*_scenario.lua` independently via LOVE: 45 PASS,
10 FAIL. New M5.1-B and existing M5.1-A condition tests pass. Injury treatment,
recovery through the injury/treatment scenarios, effective stats, movement, Combat
Power, headless battle, campaign result/resolution, projectile presentation, and
regrouping pass. New focused coverage includes hit/miss harassment, accumulating
and decaying stacks, typed pulses, refresh progress, poison caps, action interruption,
immobilized fleeing actors, ally/self healing, settlement-only execution, winner
preservation, regeneration, escaped deaths, safety truncation, casualty rosters and
campaign world events. Navigation tests also pass; the combined runner stops at
the existing party-speed failure.

Pre-existing failures, reproduced against saved pre-M5.1-B source and test files:

| Scenario | Failure |
| --- | --- |
| aoe | Physical interception fixture |
| campaign_runtime | Assertion at line 92 |
| combat_regression | Javelin used main-hand damage |
| morale | Winner's fleeing soldiers delayed victory |
| party_speed | Assertion at line 9 |
| personality_return_home | Expected 12, got 5.3333 |
| projectile | Archer missing Precision |
| recovery | Ordinary goal did not resume |
| world_encounter | Clock elapsed game hours |
| world_time_sync | World-hour conversion |

Raw output: tests/m51b_test_results.txt. Baseline comparison:
tests/m51b_baseline_comparison.txt. One added AI cooldown check caused a regrouping
regression during development; it was removed and the regrouping scenario rerun PASS.
`git diff --check` passes.

Existing uncommitted M5/M5.1-A work was preserved. No M5.1-C reactive effects,
conditional expiry, new summons/spell catalogs, or world-time ticking added.
No manual visual gameplay check was performed.
