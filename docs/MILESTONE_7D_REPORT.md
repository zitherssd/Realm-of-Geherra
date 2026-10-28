# Milestone 7D implementation report

Implemented reusable actor-owned AcquireKnowledge and timed SearchActivity. Missing-caravan
investigations, commissioning, target selection and new knowledge representations are deferred.
The implementation was checked against the complete prompt, including physical NPC discovery,
activity interruption, repeated searches and debugging requirements.

## Architecture and behavior

1. **Architecture inspected:** goals/definitions/priorities/completion; ProvideService and
   FulfillObligation; Roam/Travel/WorldActivitySystem; navigation/shared movement; campaign clock
   and pause; VisibilitySystem and remains discovery; immutable WorldEvents/subject references;
   KnowledgeSystem projections/sharing; important actor versus party memory; ownership,
   recovery and encounter reservations; F1/debug campaign and CAMPAIGN_ARCHITECTURE.md.
2. **Goal data:** `acquire_knowledge` defaults to priority 30 and accepts a historical
   `subject = {type = "party", id = "party_42"}` and/or `eventId`, optional `eventType`, and
   explicit nonempty `requiredDetails = {outcome = true}`. Other supported subjects are actor,
   location, battlefield and service. Nested definitions are copied into plain actor goal data.
3. **Satisfaction:** `Knowledge.findKnownInformation` iterates only personal memory IDs and
   filtered views. Disclosed references must identify the subject; all required categories must
   be known on one matching event. Hidden subjectIds, departures, unrelated battles and partial
   knowledge cannot establish the example's battle outcome. Historical targets need not still
   exist. Missing facts leave `blocked / awaiting_knowledge`, permitting lower-priority work.
   Existing arrival exchange/sharing/observation supplies facts. No new communication channel or
   destination is invented. Evaluation uses the existing one-second simulation interval;
   permanent satisfaction stores `knownEventId` and stops scanning. Historical location is
   supported; current whereabouts are unsupported (`current_location` is rejected).
4. **Search design:** a small adapter registers `search` in the existing activity system and
   shares Roam's preparation, update and cleanup. It requires positive finite `durationSeconds`,
   valid `originX/originY` (or `originLocationId`) and positive `radius`. Start inside the area;
   use Travel separately to approach it. Roam's optional unlimited duration is unchanged.
5. **Waypoints:** shared Roam samples points within the disk, calls existing Navigation, and
   rejects any path with waypoints outside the circle. Selection tries at most 12 candidates.
   Shared movement handles terrain speed/walkability; no evidence/history chooses waypoints.
6. **Termination:** world-simulation duration clamps the final step and completes with the normal
   `completed / duration_elapsed` result. Failed selection, stalled routes, explicit cancellation
   and party removal retain ordinary activity outcomes/retry rules. Navigation/elapsed state is
   cleaned up. Completion never claims discovery, grants knowledge or creates a search event.
7. **Observation:** existing VisibilitySystem already observes from arbitrary NPC parties using
   actual positions and sight/profile range. BattleKnowledge teaches the observing party and
   important living members. Ordinary troops retain no personal memory. Repeated observation
   adds no history; distant parties stay unaware and NPC sight does not reveal player markers.
   No observation logic change was needed. The new fixed-evidence scenario moves a searching NPC
   from outside detection range into range, with a separate distant player, without injecting
   knowledge. AcquireKnowledge becomes satisfied only after that normal observation.
8. **Ownership:** Search occupies the ordinary single activity slot; world pause and encounters
   freeze movement/progress. Busy parties cannot be overwritten. Player Search suppresses manual
   movement; map removal cancels it. Existing actor-ID/sequence ownership lets future goal-owned
   Search be interrupted by RestAndRecover while preserving the objective. Recovery cannot cancel
   externally owned Search. Repeated standalone searches at different centers use normal cooldowns.
9. **F1/debug:** the existing goal editor exposes subject/event/category fields. Inspection shows
   query, status and learned ID; Search shows center, radius, duration, elapsed time, waypoint,
   lifecycle and owner. The party inspector adds **Search here (radius 150 / six world hours)**.
   It starts external Search at the real position, preserving goals and rejecting players,
   accepted services, encounters, active movement and cooldowns. No new debug interface/profile.

## Automated checks

Run from the repository root:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' tests/unit knowledge_search_scenario
& 'C:\Program Files\LOVE\lovec.exe' tests/unit
```

The dedicated scenario checks actor versus party memory, unknown/unrelated/partial facts,
historical subject identity without a live target, explicit event queries, rejected current
location categories, copied definitions and F1 form round trips, independent resident
recovery, real Travel arrival sharing, search validation, bounded/speed-limited movement,
pause and encounter reservations, explicit player activity execution, activity ownership,
serialization, timed completion, unseen remains, ordinary visible-remains acquisition,
cancellation, unreachable destinations and party removal. Random hooks are restored after
the scenario. Existing Roam/navigation scenarios exercise obstacle-aware shared movement.

The full runner includes the new scenario alongside existing goals, recovery, services,
caravans, visibility, battle knowledge, world clock, campaign lifecycle and debug checks.
Both commands passed on 2026-10-28: all 35 scenarios and navigation tests passed.

Additional coverage exercises the real F1 button, physical NPC observation with distant
non-observers, no troop memory, repeated observation, external versus goal-owned recovery
interruption, and successive Search activities at different centers. Existing assertions were
not weakened. `git diff --check` passes.

The three previously documented combat failures now **pass individually** in this checkout:

- `headless_battle_scenario`: strong-a wins at 54 ticks.
- `world_encounter_scenario`: the victory fixture resolves with one casualty.
- `battlefield_remains_scenario`: passes including its duplicate-cargo assertion.

No combat or loot code was changed for 7D. The earlier 7B/7C reports describe historical results.

## Files changed

- `src/systems/goals/goal_definitions.lua`
- `src/systems/goals/goal_system.lua`
- `src/systems/knowledge/knowledge_system.lua`
- `src/systems/world_activities/search_activity.lua` (new)
- `src/systems/world_activities/world_activity_system.lua`
- `src/game/states/world_state.lua`
- `src/world/map.lua`
- `src/debug/campaign_tools.lua`
- `src/debug/inspector.lua`
- `src/ui/screens/debug_overlay.lua`
- `tests/unit/knowledge_search_scenario.lua` (new)
- `tests/unit/main.lua`
- `docs/CAMPAIGN_ARCHITECTURE.md`
- `docs/MILESTONE_7D_REPORT.md` (new)

Pre-existing edits to `location_actions.lua` and deletion of `actors/ai_system.lua` are preserved.

## Manual inspection

1. From the repository root run `& 'C:\Program Files\LOVE\love.exe' . --debug-campaign`.
   F1 is already enabled. Right-click Ur-Salim's travelers, select Inspect party, then click
   **Search here (radius 150 / six world hours)**. Scroll the inspector if needed.
   Hold Space to advance time and watch bounded movement, waypoint and elapsed time; release
   Space to pause. Recovery must respect this externally owned activity. After six active world
   hours, inspect `completed / duration_elapsed`. Retry only after the normal cooldown; other
   goals can resume after completion. A busy party reports an error instead of replacing work.
2. In F1, inspect an important resident or party leader and open the existing goal editor.
   Add Acquire Knowledge, enter a historical party ID, optionally restrict the event type
   to `battle_ended`, and enable Require outcome. Apply and advance world time.
3. Inspect the query and `awaiting_knowledge` reason. The goal should not invent a trip.
   Use the existing knowledge-grant tool to teach a relevant event's outcome, resume time,
   and inspect `satisfied` and its learned event ID. An unrelated event or departure should
   leave this query unsatisfied. F1 editing/grant modals retain their normal pause behavior.
4. The automatic focused scenario command above is the controlled physical NPC/evidence
   playtest: initially unknown evidence becomes known only after normal Search movement enters
   detection range. It exits after assertions; it is not an interactive preview. It uses no
   direct knowledge injection. Existing F1 knowledge grants in step 3 test query criteria only.
5. Rerun historical failures independently with `lovec.exe tests/unit headless_battle_scenario`,
   `lovec.exe tests/unit world_encounter_scenario`, and
   `lovec.exe tests/unit battlefield_remains_scenario` using the same LOVE executable path above.

Interactive playtesting was not performed. Automated scenarios exercise the real APIs and
inspector text; no new visual layout was introduced. Search retains Roam's bounded random
candidate sampling and may terminate when it cannot select a contained reachable path.
Current whereabouts, exhaustive area coverage and full save/load are unsupported. Debug Search
has fixed radius/time values. Knowledge evaluation uses the normal one-second interval.

## Remaining for Milestone 7E

Overdue detection, investigation service requests/hiring, FulfillObligation's route-based
Travel -> Search -> memory check -> Return execution, sharing discovered facts with sponsors,
and completing the investigation assignment remain unimplemented pending review. Search is
the reusable movement step; AcquireKnowledge supplies motivation and satisfaction criteria.
