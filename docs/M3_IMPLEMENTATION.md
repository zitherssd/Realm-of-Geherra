# M3 — Combat power, morale, fleeing, routing and battle outcomes

Implemented 29 October 2026 against `d9e8bfa`. The supplied M3 request takes precedence over the older design/plan: each casualty and fleeing transition gets its own squad opportunity, party checks use morale without casualty-percentage penalties, and flight is checked per decreasing event rather than threshold crossing.

## Behavior and assumptions

- Flight balance: witnessing a same-squad unit begin fleeing has base morale change **-2**, multiplied by `max(0, 1 - distance/180)`: -2 at zero distance, -1 at 90 units, and zero at or beyond 180 units, before existing relative Size, Morale resistance and threat multipliers. Other allied squads cause **zero** flight penalty. Distance uses individual actor positions. Enemy-flight gains remain +5 within the existing witness radius; death effects retain their existing radius and full strength. Individual probability, squad/party rout checks, escape and outcomes are unchanged. Fleeing still reduces fighting power, so later negative events can carry greater threat.

- `src/game/combat_power.lua` exposes `CombatPower.unit(actor)` and `CombatPower.party(partyOrRoster)` without a battle simulation or Concord world. Parties can supply `actors` or `members`. Campaign actors receive equipment stats/granted skills; battle wrappers already contain them. Injury modifiers use the existing effective-stat helper. HP is current HP, not maximum HP; Size has no separate factor. Forces with no available damaging attacks contribute zero.
- Offensive power uses the two highest distinct listed attack damages, with a 0.25 alternative weight. An attack identity is its type, damage type and base damage; duplicate supply variants count once. Equipment overrides use the existing combat skill resolver. Melee, ranged and damaging spells count; non-damaging abilities do not. Runtime charges of zero exclude the attack; campaign actors without runtime charge state assume fresh supplies. Cooldowns, range, AoE and tactical effects add no power. Representative protection is the arithmetic mean of slashing, piercing and blunt protection; elemental protections are excluded.
- Threat is `max(1, EnemyPower/FriendlyPower)` with no upper cap. Each hit snapshots both fighting forces before HP is removed, and fleeing snapshots them before the actor leaves the fighting force. Defeat witnesses retain the hit's pre-casualty snapshot; later events recalculate HP, available attacks and remaining fighters. Personal damage, allied defeat losses and distance-scaled same-squad flight losses receive the multiplier; positive gains and direct ability morale effects do not. Both zero-power sides use 1; zero friendly power against positive enemy power saturates a negative event to morale zero without division by zero. No initial strength comparison changes morale or triggers routs.
- Permanent actors default to `stats.morale = 10`. Battle wrappers start at 100; legacy actors without the stat use 10. Morale, routing and flight never write back to campaign actors.
- `src/game/battle/morale.lua` centralizes balancing, probability functions and the FIFO event queue. Actual post-protection HP loss feeds personal morale, including damaging status ticks. Each hit is squared separately; overkill is limited to actual HP lost. Dead victims do not perform flight rolls.
- Witnesses use individual positions, an inclusive 180-unit radius, existing runtime squad membership and relative actor Size. Leaders deploy separately from troop squads under M2, so their witnesses receive the other-allied-squad modifier.
- Every actor can emit at most one defeat and one flight transition. Each queue drain is bounded by its initial event count plus twice the actor count. Cascades append events instead of recursing. Events follow insertion order and observers follow the battle roster order.
- `BattleSimulation.new(a, b, controlled, {moraleRng = function() ... end})` and the headless runner's `moraleRng` option accept a zero-argument RNG returning a value in [0, 1). This controls morale checks only; existing combat, movement variance and injury RNG are unchanged. Zero-probability checks do not consume randomness.
- Squad averages exclude dead, fleeing, escaped and player-exempt members. Empty eligible squads become routed without a roll. Party averages use the same eligibility. Party checks are deduplicated by side and originating event across its cascade, including squad rout, leader defeat and widespread flight triggers. Separate casualties remain separate roots.
- Widespread flight means at least two NPCs and at least half the living NPC roster begin fleeing in one originating event's cascade. This is a trigger definition, not an additional morale or probability penalty. When no NPC fighters remain eligible, the party is effectively routed, permitting a surviving player to escape.
- Flight cancels pending casts and intents immediately. It cannot rally, even if later morale gains occur. Flight overrides squad commands and uses existing discrete moves, cooldowns, collisions, sliding and obstacle avoidance. Previously launched projectiles still resolve.
- Battle morale has no behavioral effect before an individual or collective fleeing transition, including at morale zero. Normal combat AI, movement, Charge, Hold, On Me, attacks and casting continue unchanged. Once fleeing, the existing escape behavior overrides combat and orders.
- Player markers are exempt even in headless simulations. Interactive control selects the marked player when present, preserving the existing leader fallback for unmarked legacy parties; an NPC leader beside a marked player receives ordinary morale rules. The player keeps normal controls after party rout and can escape only by physically reaching their original side's horizontal boundary. Contact means the actor circle touches that boundary. Before rout, boundary contact does nothing.
- Fleeing NPCs remain targetable and vulnerable. Escaped actors are removed from the active roster and ECS, retained in a separate battle-local survivor list, and cannot receive further damage. Result actors carry `state` (`active`, `fleeing`, `escaped`, `defeated`) and `escaped`, retaining the existing HP-based `defeated` flag.
- Pending flight delays terminal battle results. A trapped fleeing NPC gets at most 600 ticks (30 seconds at 20 Hz) from its flight transition, then is classified as an escaped survivor through bounded withdrawal. Its HP is never reduced by this policy. The wrapper records `escapeResolution = "bounded"` rather than pretending it reached the edge. This fallback also works while a player continues fighting; it never automatically escapes the player.
- At the headless combat tick limit, a pending side-loss resolution gets up to 600 additional ticks for escape. A battle with active fighters on both sides can still time out, preserving living/fleeing actors.
- Mutual withdrawal is a draw with survivors. Victory can leave living escaped actors in the losing party. Result validation accepts these cases while retaining identity, HP, equipment, injury and duplicate-application safeguards. Legacy results without new fields remain supported.
- Loot elimination/plunder decisions still count all living actors, including escaped actors. Surviving losing parties retain their actors, identities, HP, statuses, injuries and equipment through the existing campaign applier. Shared resolution applies the existing encounter cooldown duration to both parties. Interactive survivors use the existing battle-end screen and return to the world; dead-player defeat retains the previous menu behavior.
- Completed results carry validated `routedPartyIds`. The shared campaign resolution records the existing authoritative `battle_ended` event exactly once, including loser, routed parties, casualty actor IDs, escaped actor IDs and participant `routed`/`destroyed` flags, alongside existing location, campaign time, winner/outcome and elimination IDs. Only genuinely empty parties emit `party_killed`. Existing participant-only knowledge acquisition remains unchanged; no global disclosure, rumors or investigations were added. The older favor reward estimate and campaign AI/AcquirePower goals remain unchanged.

## Changed files

| File | Change |
|---|---|
| `src/ecs/assemblages/unit.lua` | Permanent morale default |
| `src/ecs/assemblages/battle_unit.lua` | Transient morale, flight, escape and player exemption |
| `src/game/combat_power.lua` | Reusable unit/party power with effective stats and distinct available attacks |
| `src/game/battle/morale.lua` | Threat snapshots, balancing, event queue, individual/squad/party checks and escape resolution |
| `src/game/battle/battle_context.lua` | Context association, defeat emission and escaped roster |
| `src/game/battle/battle_simulation.lua` | Party/edge setup, marked-player control, morale processing, outcomes, routing and survivor results |
| `src/game/battle/headless_battle_runner.lua` | Supplied morale RNG and pending escape window |
| `src/game/battle/squads.lua` | Exclude fleeing/escaped members from formation slots |
| `src/game/states/battle_state.lua` | Surviving player defeat returns through battle results |
| `src/systems/battle/battle_unit_system.lua` | Escaped units cannot act |
| `src/systems/battle/combat_system.lua` | Actual HP loss emits morale with pre-hit power; escaped units cannot take damage |
| `src/systems/battle/decision_system.lua` | Flight override; normal combat AI is independent of morale |
| `src/systems/battle/execution_system.lua` | Drain damage events, cancel flight casts, exclude escaped targets/colliders |
| `src/systems/campaign/campaign_battle_resolution.lua` | Outcome event details and existing cooldown for surviving participants |
| `src/systems/campaign/campaign_battle_result_applier.lua` | Validate routed IDs, escaped survivors and mutual withdrawal |
| `src/systems/items/loot_resolver.lua` | Support withdrawal draws while retaining living-party loot semantics |
| `tests/unit/morale_scenario.lua` | Focused M3 and interactive/headless/campaign integration checks |
| `tests/unit/combat_power_scenario.lua` | Campaign/battle power parity, attack options, threat scaling and snapshots |
| `tests/unit/battlefield_remains_scenario.lua` | Lethal first-hit fixture for elimination and corpse cleanup |
| `tests/unit/raid_encounter_scenario.lua` | Lethal attack fixture for raid elimination and loot cleanup |
| `tests/unit/main.lua` | Register M3 scenarios |
| `docs/M3_IMPLEMENTATION.md` | Assumptions, change inventory and validation report |

## Automated results

Command for an individual scenario (PowerShell):

```powershell
& 'C:\Program Files\LOVE\lovec.exe' tests/unit morale_scenario
```

All 50 `*_scenario.lua` files were run separately using the existing runner. Final results after fixture corrections and reruns: **43 PASS, 7 FAIL**. Every remaining failure was rerun against an isolated archive of clean HEAD `d9e8bfa` and reproduced at the same assertion; baseline test files and relevant implementation blobs were verified against HEAD. **No unresolved new regression failures.** The normal combined runner stops at the pre-existing party-speed failure; navigation tests pass before that failure.

The initial run exposed two elimination fixtures (`battlefield_remains` and `raid_encounter`) whose weak targets now fled instead of dying. Their attackers now use lethal first hits so these scenarios continue testing actual elimination, corpses and loot conservation. Both reruns PASS. Dedicated M3 tests separately require losing parties with escaped survivors to retain membership and never emit `party_killed`.

M3 checks PASS: campaign/battle power parity; equipment and injury stats; melee/ranged/spell options and distinct alternatives; exhausted supplies/non-damaging abilities; current HP and empty/non-combat forces; uncapped linear threat, extreme disparity and zero-power handling; pre-casualty/pre-flight snapshots and subsequent power recalculation; no pre-combat rout; permanent and transient defaults; actual HP loss after protection; quadratic per-hit loss; resistance floor; relative Size including same-sized giants; proximity boundary and own/other squad losses; positive caps; cubic probability; independent casualty/squad checks including multiple kills in one AoE; average exclusions; bounded and duplicate-free cascades; leader and widespread-flight party triggers; player immunity/control/escape gate including an NPC leader beside the player; attack/cast suppression; normal advancing, attacks, casting and regrouping at morale 100, 49 and 0 before flight; flight movement and vulnerability; death before escape; trapped-flight bound; morale reset; mutual withdrawal; headless escape at combat timeout; headless/interactive outcome parity; NPC survivor retention, loot and cooldown; interactive surviving defeat; result validation and duplicate application; routed-survivor event details with no false `party_killed` or duplicate history.

Relevant existing PASS scenarios: `battle_movement`, `friendly_sliding`, `squads`, `on_me_regroup`, `m2_refinement`, `battle_simulation`, `headless_battle`, `injury`, `injury_treatment`, `campaign_battle_result`, `campaign_battle_resolution`, `raid_encounter`, `loot_resolver`, `battlefield_remains`, `battlefield_interaction`, `battle_knowledge` (all names have the `_scenario` suffix). Both M3 scenarios and the remaining 25 individual scenarios also pass.

| Pre-existing FAIL | Assertion |
|---|---|
| `party_speed_scenario.lua:9` | Party speed assertion |
| `combat_regression_scenario.lua:72` | Spear did not hit beyond base reach |
| `campaign_runtime_scenario.lua:92` | Runtime assertion |
| `personality_return_home_scenario.lua:26` | `5.3333333333333 ~= 12` |
| `recovery_scenario.lua:165` | Ordinary goal did not resume |
| `world_encounter_scenario.lua:48` | Clock did not return elapsed game hours |
| `world_time_sync_scenario.lua:201` | World-hour to world-second conversion |

After final test/validation refinements, `combat_power_scenario`, `morale_scenario`, `battle_simulation_scenario`, `campaign_battle_resolution_scenario`, and `m2_refinement_scenario` were rerun and PASS. `git diff --check` PASS.

Correction: removed the morale-based advance gate, its unused threshold constant and the tests expecting suppressed advances. The regression now checks normal advancing, attacks, casting and regrouping at morale 100, 49 and 0 without a fleeing transition, and retains the existing flight override checks. Relevant rerun: **11 PASS, 0 FAIL** (`morale`, `combat_power`, `battle_movement`, `friendly_sliding`, `squads`, `on_me_regroup`, `m2_refinement`, `battle_simulation`, `headless_battle`, `campaign_battle_resolution`, `campaign_battle_result`, each with `_scenario` suffix). `git diff --check` PASS. The full suite was not rerun for this minimal correction; the earlier full-suite results above remain historical. Morale formulas/probabilities, Combat Power, routing, escape, outcomes and world event logging were not changed.

Allied-flight penalty correction: **9 PASS, 0 FAIL** (`morale`, `combat_power`, `squads`, `on_me_regroup`, `battle_movement`, `battle_simulation`, `headless_battle`, `campaign_battle_resolution`, `campaign_battle_result`, each with `_scenario` suffix). Regression checks include unchanged morale for same/other-squad witnesses, no individual flight propagation at zero morale with zero friendly combat power, retained enemy-flight gains and increased threat on later damage after a fighter flees. `git diff --check` PASS. Full suite and manual playtesting were not rerun for this correction.

The zero-penalty validation above describes the previous balance revision. Current distance-falloff validation: **9 PASS, 0 FAIL** using the same nine scenarios. Tests cover same-squad flight at distances 0, 90, 180 and 181, existing resistance, no other-squad penalty, unchanged enemy gains and unchanged death/damage effects. `git diff --check` PASS. Full suite and manual playtesting were not rerun.

Latest flight balance validation (-2 same-squad penalty with linear distance falloff, 0 other-squad penalty): **9 PASS, 0 FAIL**, using the same targeted scenarios listed above. Distance regression checks cover 0, 90, 180 and 181 units and Morale resistance. `git diff --check` PASS. Full suite and manual playtesting were not rerun.

## Manual verification steps (not performed)

1. Start a battle with companions/troops. Issue Hold and Charge while units take heavy damage and witness nearby losses. Verify fleeing units head to their own deployment edge, ignore commands, and stop casting; confident units keep their existing behavior.
2. Attack fleeing enemies before they reach the edge; verify they can die. Allow others to escape and verify they disappear from targeting, survive on the campaign map and preserve their equipment/HP.
3. Touch the player's own edge before party rout: the player stays in battle. After party rout, continue fighting, then walk back to the same edge: defeat results appear and Continue returns to the world with the player alive.
4. Crowd/block an NPC's retreat: after at most 600 ticks it withdraws alive. Keep a player active to verify the fallback never removes the player.
5. Return to the campaign after rout and verify both surviving parties remain, immediate raid contact is blocked by cooldown, and a subsequent battle starts with fresh morale.

No Precision, projectile/AoE redesign, charge ability, knockback, new tactical framework or unrelated regression fixes were added. Balance and crowded retreat feel still need interactive playtesting.
