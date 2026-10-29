# Milestone 8C: Persistent injuries

Implemented acquisition, persistent consequences and inspection only. No treatment,
healing economy, injury timers, incapacitation or save/load was added.

## Architecture inspected and integration

Inspected CombatSystem and all its damage callers in ExecutionSystem (melee, delayed
casts, projectiles and status ticks); BattleSimulation, BattleContext, BattleUnit,
BattleUnitSystem, BattleState, HeadlessBattleRunner, WorldEncounterSystem,
CampaignBattleResolution and CampaignBattleResultApplier. Also reviewed Unit/troop
creation and catalogs, AttributeSystem, equipment/status processing, PartySystem,
PartyAiSystem and TravelActivity, VisibilitySystem, Recovery/RestActivity,
GoalSystem/GoalImportance/goal definitions, personality/ReturnHome, services, actor
inspection/StatsPanel, the architecture document and existing scenario conventions.

The one acquisition point is `CombatSystem._applyBattleDamage`. It measures the
actual HP delta after damage/protection calculation and checks survival. Both battle
modes already use this function. Status damage passes an explicit exclusion flag:
burn/poison ticks are not additional damaging hits. The opposed dice, weapon,
Strength, protection, projectile accuracy and lethality formulas are unchanged.

Campaign actors own `injuryProfile` and an `injuries` list containing only
`{id = "broken_leg", bodyPart = "left_leg"}`. The catalog resolves severity/name/effects.
Unit creation initializes an empty list. No component duplicates actor identity.
Changing party, goal, location or HP does not replace injury state.

BattleUnit deep-copies the actor list and retains its profile ID. Combat derives
injury penalties at hit resolution, rather than baking them into copied stats.
New battle injuries therefore affect the next attack immediately without applying
old injuries twice. `BattleSimulation.buildResult` deep-copies final lists alongside
the existing HP/equipment/status fields. Headless start/advance/result/cleanup and
interactive completion keep their existing ownership and lifecycle.

Both modes use CampaignBattleResolution and CampaignBattleResultApplier. The applier
validates injury IDs, anatomy compatibility, list shape and unique body parts before
any mutation. Survivors merge entries through the shared worsening rule; omitted
injury fields in older result fixtures preserve existing state. Defeated actors
receive no injury copy-back and leave party rosters as before. Existing encounter
duplicate-application protection, casualty, loot, treasury and event accounting remain.
Result access does not apply anything. Battle and campaign lists never alias.

## Probability and selection

Configuration lives in `src/data/injuries.lua`:

| Actual damage / battle max HP | Injury occurrence |
|---|---|
| 0 / 5 / 10 / 20 / 30 / 50 / 75% | 0 / 0.5 / 1 / 3 / 7 / 20 / 50% |
| Above 75% | 50% |

| Actual damage / battle max HP | Major, conditional on occurrence |
|---|---|
| 0–30 / 50 / 100% | 0 / 20 / 100% |
| Above 100% | 100% |

`Injury.interpolate` linearly interpolates and clamps probabilities. Nonpositive,
NaN or infinite damage/max HP skips acquisition safely. Fatal hits skip all injury
RNG. At 75% damage, occurrence is 50%, conditional major is 60%, overall major is
30%. The 100% major endpoint does not alter combat survival rules.

The existing `math.random` stream supplies independent occurrence and conditional
severity draws. `Injury.fromDamage(unit, damage, rng)` accepts a zero-argument RNG
for deterministic tests. Only successful occurrence consumes severity, location and
definition draws. Locations use authored ordered weights; compatible definition
candidates sort by stable ID before weighted selection. A non-worsening result
consumes no extra rerolls.

| Profile | Weighted locations |
|---|---|
| Humanoid | torso 30, left/right arm 15 each, left/right leg 15 each, head 10 |
| Quadruped | torso 30, head 10, front/rear left/right leg 15 each |
| Dragon | head 10, torso 30, left/right wing 10 each, left/right leg 15 each, tail 10 |
| Plant | trunk 40, left/right branch 15 each, roots 30 |

Troop definitions explicitly reference profiles. Humans, ogres and existing bipedal
Gaia humanoids use humanoid; wolves, bears, boars, stags, lions and the Hutzu Pony use
quadruped; Dragon uses dragon; Gaia plants including Walking Tree use plant.
Mounted humanoid troops retain their rider anatomy. Centaurs, snakes, birds,
arthropods and hybrid monsters remain without an authored profile and safely skip
acquisition. No species-name dispatch exists in combat and no humanoid fallback is
assigned to unknown anatomies. Missing/invalid profiles do not crash acquisition.
The catalog validates positive location/selection weights and coverage of both
severities for every location; troop aggregation rejects unknown profile references.

## Initial named catalog and exact penalties

All selection weights are 1 except Facial wound (0.5). Concussion and Facial wound
are alternatives for a minor humanoid head injury. Names below map to stable
snake_case IDs in the catalog; the two dragon head IDs have a dragon qualifier.

| Anatomy/category | Minor condition and effect | Major condition and effect |
|---|---|---|
| Humanoid chest | Bruised ribs: Defense -1 | Severe chest injury: Defense -3 |
| Humanoid arm | Wounded arm: Attack -1 | Crushed hand: Attack -3 |
| Humanoid leg | Sprained ankle: movement ×0.85 | Broken leg: movement ×0.6 |
| Humanoid head | Concussion: sight ×0.85; or Facial wound: Attack -1 | Damaged eye: Attack -2, sight ×0.65 |
| Quadruped torso | Torso wound: Defense -1 | Severe torso wound: Defense -3 |
| Quadruped leg | Injured paw: movement ×0.85 | Fractured leg: movement ×0.6 |
| Quadruped head | Bruised jaw: Attack -1 | Damaged jaw: Attack -3, sight ×0.8 |
| Dragon head | Bruised head: sight ×0.85 | Damaged eye: Attack -2, sight ×0.65 |
| Dragon torso | Cracked scales: Defense -1 | Deep chest wound: Defense -3 |
| Dragon wing | Strained wing: movement ×0.9 | Torn wing: movement ×0.7, Defense -1 |
| Dragon leg/claw | Injured claw: Attack -1 | Fractured claw: Attack -3, movement ×0.85 |
| Dragon tail | Injured tail: Defense -1 | Fractured tail: Defense -3 |
| Plant trunk | Split bark: Defense -1 | Cracked trunk: Defense -3 |
| Plant branch | Splintered limb: Attack -1 | Shattered limb: Attack -3 |
| Plant roots | Strained roots: movement ×0.85 | Damaged roots: movement ×0.6 |

One persistent condition per exact body part: empty accepts; minor → major replaces;
major → minor and equal severity retain the old condition. Left/right limbs are
independent. Attack/Defense penalties add; movement/sight multipliers multiply.
Combined multipliers have a 0.2 floor; effective Attack/Defense and speed/sight have
a zero floor. Baseline troop and actor stats are never mutated.

World movement uses the existing mean of member speed stats, with injuries applied
to each member before the mean, followed by party/terrain modifiers. The current
base formula remains `worldSpeed * averageSpeed / 16`; this milestone does not fix
the older test's expectation of `/10`. Manual movement, Travel, Roam, Raid and idle
movement already share this calculation. Sight modifies each observer before
PartySystem sums the best five; VisibilitySystem consumes that same party sight.

Following the requested extension, `movementSpeedMultiplier` also applies to derived
`battle_speed`. ExecutionSystem uses it in the existing movement/global cooldown
formula, and StatsPanel displays the adjusted B. SPEED. A broken leg reduces 10 to 6:
with zero variance, movement cooldown increases from 12 to 20 ticks. New battle
injuries affect subsequent movement without changing stored stats or skill timings.
The injury scenario checks the actual cooldown, combined penalties and unchanged
baseline/campaign state.

## Recovery and inspection

Minor injuries contribute 8 importance points per body part; major injuries 25,
capped at 100 per actor. Leaders take the greater of personal and mean living-member
injury urgency, add it to existing HP recovery urgency, then clamp to 100. Non-leaders
use their own condition. Eliminated/dead members contribute nothing.

`Importance.recoveryHealth` preserves the former HP-only calculation; combined
`Importance.recovery` remains the public motivation calculator. When HP can improve,
existing rest, settlement travel and healing purchases continue normally. When only
injuries remain, RestAndRecover stays attached, unsatisfied and positively scored,
but is blocked with `injury_treatment_unavailable`. It cannot start RestActivity,
travel for nonexistent care or buy treatment. Existing eligibility/fallback releases
dominance to feasible goals. HP damage makes it eligible again. RestActivity completes
when living group HP is restored, regardless of injuries. Instant service healing
checks this condition before starting another rest attempt. Recovery never removes
injuries, including at full HP.

The existing Inventory StatsPanel shows effective Attack/Defense/speed/sight and
wrapped, scrollable injury lines. F1 actor inspection and party actor rosters show
name, catalog severity, human-readable location and individual penalties. Uninjured
actors show `Injuries: none`. Existing F2/F3 views remain intact. Panel rendering and
scrolling were exercised at widths 350 and 540; the rendered panel was visually
inspected. There is no treatment UI.

## Files

Added:

- `src/data/injuries.lua`
- `src/systems/actors/injury_system.lua`
- `tests/unit/injury_scenario.lua`
- `docs/MILESTONE_8C_REPORT.md`

Modified:

- `src/data/troops.lua`
- `src/data/units/{neutral/neutral_units,npcs/npc_units,pelasgians/pelasgian_units}.lua`
- `src/data/units/gaia/{gaia_animals,gaia_giants,gaia_minotaurs,gaia_nymphs,gaia_plants,gaia_satyrs,gaia_trolls}.lua`
- `src/ecs/assemblages/{unit,battle_unit}.lua`
- `src/game/battle/battle_simulation.lua`
- `src/systems/battle/{combat_system,execution_system}.lua`
- `src/systems/campaign/campaign_battle_result_applier.lua`
- `src/systems/parties/party_system.lua`
- `src/systems/goals/{goal_importance,goal_system}.lua`
- `src/systems/world_activities/rest_activity.lua`
- `src/ui/widgets/stats_panel.lua`
- `src/debug/inspector.lua`
- `tests/unit/main.lua`
- `docs/CAMPAIGN_ARCHITECTURE.md`

## Validation

Commands run from the repository root in PowerShell:

```powershell
& 'C:\Program Files\Love\lovec.exe' tests/unit
& 'C:\Program Files\Love\lovec.exe' tests/unit injury_scenario
foreach ($file in Get-ChildItem tests/unit/*_scenario.lua) {
    & 'C:\Program Files\Love\lovec.exe' tests/unit $file.BaseName
    Write-Output "$($file.BaseName): $LASTEXITCODE"
}
git diff --check
```

- Full default entry point: **FAIL before and after**, after navigation passes,
  at the preexisting `party_speed_scenario.lua:9` assertion. It stops on first failure.
- Every scenario executed independently: **34 PASS, 6 FAIL** after implementation;
  baseline was **33 PASS, the same 6 FAIL**. No existing assertions weakened.
- Injury scenario: **PASS**. Direct curve/boundary checks; finite input safety;
  independent conditional rolls and exact draw counts; all profile locations and
  severities; weighted definition alternatives; validation; same-part replacement;
  no reroll on unchanged condition; opposed combat penalties; actual movement and
  visibility; rest HP persistence; no duplicate modifiers; isolated simulations;
  headless timeout/results/cleanup; result validation before mutation/idempotency;
  fatal/later fatal casualty handling; melee/projectile acquisition; interactive
  player/companion copy-back; WorldEncounter result/reservation cleanup; living-member
  recovery importance, blocked untreatable rest, fallback and panel rendering.
- Existing combat, battle simulation, headless runner, result application/resolution,
  raids, caravans, services/healing, population, dynamic importance, navigation,
  debug campaign/mode and activity scenarios: **PASS**.
- `git diff --check`: **PASS**.

Preexisting failures reproduced before implementation and unchanged afterward:

| Scenario | Failing assertion |
|---|---|
| party_speed | line 9: expected baseline party speed 80 |
| campaign_runtime | line 92: timing assertion |
| personality_return_home | line 26: `5.3333333333333 ~= 12` |
| recovery | line 165: ordinary goal did not resume |
| world_encounter | line 48: clock did not return elapsed game hours |
| world_time_sync | line 201: world-hour to world-second conversion is incorrect |

## Manual playtest

1. Run `& 'C:\Program Files\Love\love.exe' .`, start a campaign, and enter a battle
   against a normal humanoid party. Injuries are intentionally rare; surviving large
   hits have the best chance. Repeat battles if necessary.
2. After battle, open Inventory for the player. Scroll the Stats panel to inspect
   injury name/severity/location/penalties. Use F1 to inspect any party's actor roster
   and surviving NPCs. Check uninjured actors display `Injuries: none`.
3. Rest/wait until full HP and travel again. Injuries and their penalties must remain;
   reduced speed and sight still apply. A later battle must retain the condition and
   derive its modifiers once.
4. Inspect an injured important NPC with RestAndRecover in F1. While HP is low, normal
   recovery remains actionable. At full HP its score stays positive, with reason
   `injury_treatment_unavailable`; other feasible goals can run.
5. Observe NPC-versus-NPC encounters to completion. Surviving actors retain injuries;
   casualties leave their rosters and encounter reservations clear. Inspect F2/F3 for
   existing encounter/activity/navigation behavior.

For reproducible acquisition without depending on rare rolls, run `injury_scenario`;
it drives real damage and both result paths with controlled occurrence/severity RNG.
No full live campaign playthrough was performed.

## Limits, decisions and 8D extension points

Chosen balancing details beyond the specified curves: effects/weights above; 8/25
injury urgency with leader mean; 20% movement/sight floor; exact severity ties retain
the old injury; status ticks excluded; unsupported hybrid anatomy left unprofiled.
Current claw/hand injuries occupy their parent leg/arm slot, keeping the specified
one-condition-per-body-part rule. Wing injuries affect world movement; no new flight
mechanics exist. Fatal actors keep the existing ECS lifetime/HP-zero policy; this
milestone only preserves the existing roster removal semantics.

Adding injury RNG changes later draws on the shared combat RNG stream; formulas are
unchanged, but old seeded battle traces need not be identical. Baseline failures above
remain. Broader visual campaign interactions and long-run balance remain manual work.

8D can add explicit injury removal through actor-owned ID/location entries, reopen
the blocked recovery eligibility when real treatment is actionable, and use existing
service/activity boundaries for payment and commitments. It must not mutate troop
baselines or teach ordinary Recovery to delete injuries. No treatment hooks, stock,
markets, herb resources, timers, automatic removal or speculative economy API is
implemented in 8C.
