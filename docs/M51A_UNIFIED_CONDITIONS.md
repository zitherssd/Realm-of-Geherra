# M5.1-A unified conditions foundation

`systems/actors/conditions.lua` retains `statusEffects[id]` and the stable
`injuries` list. Apply/get/remove accept an injury body part; injury application
still delegates severity and body compatibility to InjurySystem. Treatment removes
through the same interface. Injuries remain persistent and recovery controlled;
HP recovery and treatment timing are unchanged.

Status definitions inherit catalog fields before skill overrides. Numeric durations,
ID lists, true, and existing table aliases remain supported. Entries carry lifetime,
duration, remaining, durationUnit, sourceSkillId, stacks, and periodic tickCounter.
Policies: refresh (default, reset duration, preserve counter and stack count), stack
(increment up to maxStacks, refresh duration and preserve counter), replace (reset).
`effects` uses additive stat keys and multiplicative `*Multiplier` keys; protection
keys are `protection_fire`, `protection_slashing`, etc. No new periodic behavior:
stack counts affect modifiers, not the existing periodic damage amount.

Lifetimes: battle-only (default), persistent (copied to campaign), permanent (copied
and not decremented). Persistent durations advance in battle ticks only. Campaign
time does not tick conditions. Injury metadata reports injury-recovery units.
Battle result snapshots retain complete copied status state; campaign application
filters expired and battle-only statuses. Legacy statuses lacking a lifetime default
to battle-only. This intentionally stops burns/stuns leaking between battles.

`effective_stats.lua` combines equipment and conditions. Existing battle wrappers
already bake equipment into stats/protections, so accessors add equipment only for
campaign actors. Injury modifiers are calculated once from the original injury
list. Defense is at least 1; signed damage protection remains supported. Melee
Defense includes equipment shield Defense once; projectile defense retains its
existing special shield formula. Combat damage, Combat Power, aiming, movement
cooldowns, and stats panel use shared values.

Changed implementation files:
- src/systems/actors/conditions.lua (new)
- src/systems/actors/effective_stats.lua (new)
- src/systems/actors/injury_system.lua
- src/systems/actors/injury_treatment.lua
- src/systems/battle/battle_unit_system.lua
- src/systems/battle/combat_system.lua
- src/systems/battle/execution_system.lua
- src/systems/campaign/campaign_battle_result_applier.lua
- src/game/battle/projectiles.lua
- src/game/combat_power.lua
- src/ui/widgets/stats_panel.lua

Tests: new conditions_scenario.lua; registered in tests/unit/main.lua. Updated
battle_simulation_scenario.lua and campaign_battle_resolution_scenario.lua to
expect battle-only status removal. Raw output: tests/m51a_test_results.txt.

11/14 targeted scenarios PASS. FAIL: combat_regression (javelin damage), projectile
(missing archer Precision), aoe (physical interception). First two match recorded
M5 baseline failures. AoE also fails with prior status execution, combat accessors,
and projectile aiming restored temporarily; see tests/m51a_aoe_baseline.txt. No
unrelated fixes applied. Existing uncommitted M5 changes retained.

No M5.1-B/C mechanics, campaign ticking, new spells, or settlement implemented.
