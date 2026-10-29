# Milestone 8D: Injury treatment

Implemented 2026-10-29. The existing uncommitted 8C/8C.5 work was preserved.

## Behavior

- Existing `heal` capability treats compatible persistent injuries for every anatomy.
- Each attempt consumes exactly one Healing Herb at start, takes 12 elapsed world
  hours, and succeeds on a random roll below 0.5. Failure/cancellation never refunds.
- Success removes the selected injury ID and body part only. Effective Attack,
  Defense, speed and sight immediately use the existing injury stat calculations.
  Treatment never restores HP; normal HP healing never cures injuries.
- Automatic care randomly selects an eligible living patient within the healer's
  own party, then a compatible injury. Independent healers only treat themselves.
- Shared inventory is preferred, with personal inventory as fallback. Other parties,
  other actors' personal supplies, settlements and convoy cargo are never borrowed.
- Concurrent healers can treat distinct patients, including across parties. Shared
  ownership checks prevent duplicate patients, multiple patients per healer and
  repeated resource consumption from duplicate start calls.
- Treatment continues while traveling and survives primary goal switches. No new
  goal or WorldActivity is created, and travel destinations remain under existing AI.
- Encounters pause progress. Death, campaign removal, separation, lost capability
  and an absent/replaced injury cancel the attempt and release availability.
- Existing HP-service fees, rewards and healing amounts are unchanged. Treating
  healers cannot provide those services or accept incompatible service assignments;
  existing obligations prevent new automatic care.

Healing Herbs (`healing_herbs`) are stackable ordinary consumables with weight 0.1,
value 5, no durability and no special instance fields. Existing elder stock includes
ten herbs using TraderSystem's normal inventory and restocking conventions.

## Architecture inspected

Reviewed the 8C and 8C.5 reports and CAMPAIGN_ARCHITECTURE, InjurySystem and injury
profiles/definitions, Unit/BattleUnit actor storage, capabilities and NPC archetypes,
ServiceSystem's direct/commission HP healing and availability, GoalSystem and
importance, WorldActivity lifecycle and Rest/Travel/Roam, TimeSystem and WorldState/
CampaignRuntime scheduling, party roster/leadership APIs, InventorySystem and trader
stock, battle simulation/interactive/headless runners, campaign results, world
encounters/reservations, recovery and the existing inspector/scenario facilities.

The shared module is `src/systems/actors/injury_treatment.lua`:

```lua
local Treatment = require("src.systems.actors.injury_treatment")
local attempt, reason = Treatment.start(healer, patient, injuryEntry, inventoryOwner)
Treatment.advance(attempt, elapsedWorldHours, campaignWorld, reservations, rng)
Treatment.cancel(attempt, campaignWorld, "cancelled")
```

`world.injuryTreatments[healerId]` is authoritative. Records are plain data with
stable campaign actor IDs and an exact injury ID/body part; no actor/battle-unit
references or global current-treatment singleton are stored. Patient reservations
are derived from these records. Terminal states are copied to living/present
participants' `lastTreatment` fields for inspection, and active records are removed.

The shared operations validate identity, capability, injury, combat, resources and
ownership. Requesters own physical access and resource policy. The automatic caller
records its originating party and enforces continued roster access. The process
contains no payment, reward, commission-completion or RestAndRecover requirement,
so a future commission caller can use it without duplicating treatment resolution.
No future commissions are implemented here.

Both party removal functions revalidate active treatment immediately. Campaign
result application also revalidates after casualty/injury changes; direct campaign
entity removal is cleaned at the next world update, even with zero elapsed time.
Interactive battle entry/exit now owns participant `activeEncounterId` reservations.
Headless NPC encounters retain their existing reservations and result lifecycle.

## Clock investigation and timing decisions

The actual clock uses a 15-real-second game day: scale-one `TimeSystem.update(dt)`
returns `dt * 1.6` world-hours. It retains fractional hours while updating the displayed
clock in minute increments. `worldHoursToSeconds` divides by 1.6 to return the existing
compressed simulation seconds. It does not return literal 3600-seconds-per-hour units.
Several old scenario expectations still assume 1.5 hours per real second.

Treatment receives the hours returned by TimeSystem directly, passed from WorldState
as the final CampaignRuntime.update argument. It does not use render-frame seconds,
the displayed hour difference, or the misleading conversion helper. No preexisting
clock defect prevents this path, so no clock configuration/conversion/refactor or
unrelated regression assertions were changed.

Automatic updates advance all simultaneous treatments to the nearest completion
boundary before selecting subsequent work. For example, 25 hours with repeated
failure and three herbs produces two completed failures and a third attempt at 1/12
hours. Two healers with one patient cannot perform four sequential attempts during
24 hours. Exact completion resolves once; another attempt starts on the next update
when no elapsed time remains. A 1e-9-hour tolerance handles floating-point boundary
rounding without creating extra near-zero-time attempts.

Pre-encounter reservations are captured before world encounters advance. Treatment
uses the same snapshot as HP recovery, so a battle completing during that update does
not grant its combat hours as treatment time. Large combat-completion updates retain
the existing conservative rule: the whole reserved update is excluded, then treatment
resumes on the next update. There is no new battle substep/time scheduler.

## Recovery and debugging

8C injury importance values and ordinary HP recovery rules remain unchanged. When
only persistent injuries remain, RestAndRecover reports pending/in-progress/unavailable
care through the existing blocked-goal/fallback mechanism. It never starts an ineffective
RestActivity, searches for healers, invents supplies or interrupts travel to wait for
background treatment. Actual care is independent of the selected primary goal.

F1 actor inspection and party roster lines expose shared/personal herb counts,
current healer and patient names/IDs, selected injury ID/body part, elapsed and required
world hours, combat pause and last outcome. Removed roster members remain inspectable
without dereferencing an absent world. No additional treatment interface was added.

## Files changed for 8D

Some files also contain the preserved earlier milestones' uncommitted changes.

- `src/systems/actors/injury_treatment.lua` (new)
- `src/data/items/consumables.lua`
- `src/data/units/npcs/npc_units.lua`
- `src/game/campaign/campaign_runtime.lua`
- `src/game/states/world_state.lua`
- `src/game/states/battle_state.lua`
- `src/systems/services/service_system.lua`
- `src/systems/goals/goal_system.lua`
- `src/systems/parties/party_system.lua`
- `src/systems/campaign/campaign_battle_result_applier.lua`
- `src/debug/inspector.lua`
- `tests/unit/injury_treatment_scenario.lua` (new)
- `tests/unit/main.lua`
- `docs/CAMPAIGN_ARCHITECTURE.md`
- `docs/MILESTONE_8D_REPORT.md` (new)

## Automated verification

LÖVE 11.5 ran every scenario individually before editing: 35/41 passed, with the six
failures already documented in 8C.5. After implementation, 36/42 pass, including the
new treatment scenario. No new regression failures remain and no old assertions were
weakened. The following baseline failures reproduce at the same assertions:

| Scenario | Unchanged failure |
| --- | --- |
| `campaign_runtime_scenario` | line 92, clock/simulation conversion |
| `party_speed_scenario` | line 9, party movement speed |
| `personality_return_home_scenario` | line 26, 5.3333333333333 versus 12 |
| `recovery_scenario` | line 165, ordinary goal did not resume |
| `world_encounter_scenario` | line 48, elapsed game-hour expectation |
| `world_time_sync_scenario` | line 201, hour-to-simulation-second conversion |

Passing coverage includes persistent injuries, unified inventory, dynamic importance,
NPC goals, travel and activities, services, population, retinues/inline parties,
interactive battle simulation, headless combat, campaign results, raids, remains,
caravans, investigations, knowledge and debug facilities.

The focused deterministic scenario covers:

- Capability/identity eligibility, dead/removed participants, humanoid/minotaur/dragon/
  plant injuries, self-treatment and independent self-only selection.
- Exactly one herb at start, no refund, no-stock/replenished-stock handling without
  repeated failing debits, shared-before-personal policy, no borrowing, metadata and
  unrelated cargo preservation, and duplicate healer/patient rejection.
- Exact 12-hour boundaries, split accumulation, fractional rounding, paused/zero-scale
  clock, acceleration, authoritative runtime hours, actual Space waiting and idle pause.
- Threshold rolls below/at 0.5, specific same-ID limb removal, other injuries retained,
  immediate combat/movement/sight stat restoration, no HP grant, retries and repeated
  failures using additional resources and hours.
- Random patient/injury selection, multiple healers and parties, identical large/split
  update throughput, travel movement and destination/activity continuity, actual goal
  switching and full-HP treatment without recovery dominance.
- Actor combat, actual interactive battle reservations, headless WorldEncounter pause,
  combat-completion snapshot exclusion, resume, death/removal, both roster-removal APIs,
  worsening injury cancellation, lost capability, no stale records and no duplicate close.
- RestAndRecover importance/actionability, no futile rest loop, existing HP recovery,
  HP service busy/released availability, existing obligations, item stock and inspector text.

Reproduce the focused scenario:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' tests/unit injury_treatment_scenario
```

The aggregate runner still stops at the preexisting party-speed failure; individual
execution prevents that early failure from hiding later scenarios. Navigation tests
pass before that aggregate failure. `git diff --check` passes, with existing line-ending
normalization warnings. The final self-treatment membership edge case was also rerun
through the focused scenario after the full-suite comparison.

## Manual verification and limits

Rendered gameplay was not manually playtested. Automated scenarios exercise real
WorldState waiting, TravelActivity, BattleState, WorldEncounter and inspector output.
For a live check:

1. Buy Healing Herbs from an elder's existing stock and put them into shared cargo;
   include an actor with the existing heal capability and an injured living member.
2. Inspect the healer or party with F1. Advance time with Space or movement. Observe
   the herb consumed, selected injury and increasing progress; idle to pause it.
3. Travel and switch the leader's primary goal. Confirm movement/destination behavior
   continues and the same treatment retains progress. At 12 hours observe success or
   failure, then automatic further attempts while supplies/injuries remain.
4. Enter a battle during treatment. Confirm reservation pause and resumed progress
   afterward, or cancellation on casualty/separation. Inspect restored effective stats
   after success and confirm HP is unaffected by the treatment operation itself.

Paid injury services, commission/reward design, triage, supply purchasing/gathering,
crafting, production, a generic activity lock/scheduler, broad clock cleanup and full
campaign save/load remain outside this milestone. Active records survive world updates;
full campaign save/load remains unimplemented in the surrounding architecture.
