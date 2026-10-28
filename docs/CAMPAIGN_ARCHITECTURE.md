# Campaign Architecture (Target Decisions)

This document records the agreed architecture for the campaign simulation and implemented milestones. Some later campaign systems remain future work.

## A. Actors / NPCs

- Actors are persistent individuals with stable identities.
- Actors can own personal equipment and possessions independently of any party or location.
- Relationships, reputation, dialogue identity, and personal goals belong to the actor.
- An actor may be a resident at a location or a member of a party, but it remains one persistent identity.
- Moving or stationing an actor must not create a second copy of the character.
- Personal equipment follows the actor, not the party or location.

## B. Parties

- Parties are persistent, organized groups containing actors.
- Parties have a leader, shared inventory, treasury, and activities.
- Merchants, bandits, minotaurs, soldiers, and player parties use the same underlying party mechanics.
- Party inventories are authoritative for shared cargo during travel.
- Parties may travel in the world or be stationed at a location.
- Stationing a party does not dissolve it or transfer its actors into a separate resident roster.
- Party leaders remain the same NPCs regardless of where the party is encountered.

## C. Locations

- Locations are persistent places.
- Locations can have independent resident NPCs and stationed parties.
- Available NPCs are resolved from independent residents plus actors belonging to stationed parties, without duplication.
- Locations may eventually change ownership or faction control.
- Stationary goods still belong to stock owners such as shops or location stores rather than an acting shopkeeper.
- The current location inventory and shop model is retained for this milestone; a broader economy framework remains future work.

## D. Inventory

- Actors, parties, and stock owners are all valid inventory owners.
- Inventory operations use consistent generic rules and metadata-safe stacking.
- Every transferable item quantity or currency amount has one authoritative owner at a time.
- Actor possessions and party cargo remain distinct.
- Goods must move without duplication between owners.
- Items are not merged when their instance metadata differs.
- A merchant does not require a special inventory implementation.

## E. Dialogue

- Dialogue belongs to the persistent NPC identity.
- Meeting a party leader on the road or inside a location uses the same dialogue system and personal options.
- Context can add or restrict options, but it must not duplicate the dialogue identity.
- Existing dialogue paths are reused rather than replaced.

## F. Activities and goals

- Activities describe how a party acts.
- Goals describe why a character or faction wants something.
- Actor goal evaluation selects existing World Activities through `GoalSystem`.
- Travel is represented as a generic TravelActivity.
- Raid remains a reusable World Activity.
- TravelActivity is the authoritative generic party travel implementation.
- TraderTravelSystem has been removed. Merchant-specific departure schedules, random destinations, escort creation, and automatic trading decisions are intentionally absent until goals select activities.
- Location-specific or merchant-specific decisions belong in future goal and decision logic rather than generic travel mechanics.
- Only one controller owns a party's movement at a time.
- Simulation uses the established world-time model.

## Campaign runtime extraction (A1)

`src/game/campaign/campaign_runtime.lua` owns campaign subscriber setup, new-campaign
context/ECS creation, encounter travel resets, elapsed-time conversion and simulation
scheduling. Startup calls `init` after the event bus and states are initialized;
`GameInitializer.beginNewGame` delegates campaign creation to `beginNewGame`.
Quest and random-encounter listeners are unsubscribed/rebound on setup, so repeated
setup and setup after `EventBus.init` do not duplicate listeners. World entry resets
random-encounter travel accumulators and rebinds world-encounter/activity listeners;
resume only resets the travel accumulators. World exit does not tear down campaign
subscriptions, which must remain active through player battles and overlays.
The player raid-contact listener remains in WorldState with the battle transition.

The frame sequence remains:

1. WorldState decides whether time advances and sets the clock pause flag.
2. `advanceTime(dt)` updates the clock and returns world hours and simulation seconds.
3. WorldState applies manual player movement and updates the camera using frame seconds.
4. `updateEncounters` rolls random encounters only for manual movement (including zero
   distance against an obstacle), snapshots recovery reservations, then advances existing
   world encounters in world hours. WorldState refreshes encounter hover inspection.
5. `update` runs, for positive simulation seconds: Concord flush, service cleanup,
   caravan advancement, goal evaluation, recovery using the earlier reservation snapshot,
   default activities, then legacy party AI. It always invokes activity update, even
   with zero time, to clean up terminal activities without ticking cooldowns.
6. WorldState starts any pending player battle and returns immediately on transition;
   otherwise it refreshes visibility and handles location/party interactions.

Activity update also retains its existing internal default-activity check after cleanup.
Idle and zero-scale frames retain terminal cleanup and visibility; developer modals
return before the simulation and skip both. StateManager updates only the top state,
so other screens do not implicitly advance the campaign. Waiting, resting and active
player Travel/Roam admit time; manual movement speed still uses unscaled frame seconds.
One real second at scale 1 produces 1.5 world hours; simulation seconds are those hours
divided by 1.5. The clock displays minute increments but returns unquantized elapsed hours.

`GoalSystem.update` retains its signature and standalone Concord flush, but now only
evaluates goals. Campaign callers that need service/caravan coordination use
`CampaignRuntime.updateGoals`; the runtime calls `GoalSystem.evaluate` after its own
flush, preserving the original flush position before services and caravans.

Reset behavior is deliberately preserved: ordinary new games replace context/ECS but
retain the clock's transient scale, pause flag and fractional accumulator. Debug new
games reset those too and start at day 1, hour 6. This asymmetry and singleton campaign
state remain follow-up lifecycle concerns; this extraction does not change their policy.
Full save/load, battle consequence convergence and goals/services/caravans dependency
cleanup are outside this change. `campaign_runtime_scenario` covers ordering, unit
conversion, pause/modal behavior, zero-time cleanup and reset/subscription lifecycle.

## G. Identity and quests

- Campaign entities use campaign-scoped, monotonic, non-reused IDs.
- Long-lived relationships store stable IDs and resolve through safe campaign lookups.
- Characters initially own personal goals; factions may later own collective goals.
- Quests represent opportunities to help NPCs achieve goals arising from actual world circumstances.
- World facts, NPC knowledge, goals, activities, and quests remain distinct concerns.

## Actual Milestone 1 ownership and membership model

The implementation uses the following minimal, compatible model:

- Party cargo remains a list of item tables, as in the current runtime, with ownership represented by the party entity itself.
- Actor personal inventory remains the existing item-ID quantity map; `inventoryFormat` disambiguates empty inventories, while populated legacy inventory shapes remain recognizable.
- Resident NPCs remain in `location.npcs` as the independent resident roster.
- Stationed parties are tracked only in `location.stationedParties`; there is no mirrored party location field.
- `Map:stationParty` enforces one location per party, while adding a party to the traveling map removes its stationed membership. Party removal clears any stationed reference.
- Available NPCs are derived from resident NPCs and actors in stationed parties, with de-duplication by entity ID or reference.
- Transfers debit the source and credit the destination; item instances are deep-cloned to avoid sharing mutable metadata. Snapshot copies do not change ownership.
- Meta-safe stacking only combines entries when their item IDs and metadata signatures match.

## Actual Milestone 2 identity model

- The campaign Concord world owns an `IdAllocator`; independent campaigns and test worlds
  receive independent allocator instances. New actor, party, location, quest-instance, and
  quest-offer IDs use namespaced counters such as `actor_1` and `quest_1`.
- Allocation is monotonic. Allocated and explicitly claimed IDs remain reserved after entity
  removal. Existing explicit string or numeric IDs are retained, and namespace counters advance
  past explicit IDs that match the allocator's namespace format.
- `EcsWorld.serializeIdAllocator(world)` returns the allocator's versioned plain-data state.
  Supply that state to `EcsWorld.init({idAllocatorState = state})` when restoring a campaign, or
  use `EcsWorld.restoreIdAllocator(world, state)` to restore it into an existing ECS world. The
  allocator scans existing and pending entities during restoration/allocation so the next ID
  cannot collide with an entity not already recorded in allocator state. Full campaign
  serialization and entity migration remain out of scope.
- Safe resolution is available through `EcsWorld.findEntityById`,
  `findActorById`, `findPartyById`, `findLocationById`, and `findQuestById`. Missing, removed,
  and pending-removal entities resolve to `nil`; duplicate live IDs are reported as an error.
- `GameContext` stores `playerId`, `playerPartyId`, and party-roster actor IDs; its existing
  `player`/`playerParty` read access resolves through the safe ECS lookups for compatibility.
- Party leader references, quest giver references, and quest objectives
  use IDs. Party rosters and location/map membership continue to hold direct ECS references as
  active membership collections. Active map encounter records store participant IDs; the
  transient battle runner retains entity references only for the duration of execution.
- Procedurally generated runtime locations now receive `location_*` IDs. Existing supplied IDs,
  including static/legacy location IDs, remain unchanged. Generic non-ECS entities such as item
  instances require explicit IDs rather than falling back to time/random generation.
- World encounters and battlefield remains retain their existing map-scoped monotonic sequences
  (`<map-id>:encounter:<n>` and `<map-id>:remains:<n>`), which are kept with the map's existing
  sequence state rather than migrated into the ECS entity allocator. They are not campaign
  entities or journey/event history records.

## Legacy or unimplemented areas

The following remain intentionally out of scope:

- Faction planning and additional NPC goal types
- NPC knowledge (world-event history is implemented in Milestone 6A below)
- Procedural quest generation
- Full economy or barter framework
- Full save/load migration

## Actual Milestone 3 travel model

- `TravelActivity` is registered in `WorldActivitySystem` and accepts a destination location ID.
  It resolves locations through the campaign entity lookup and confirms that the destination is
  present on the current map.
- Travel stores IDs and serializable waypoint coordinates, not long-lived ECS object references.
  It follows the map's generated road graph, uses the shared party movement helpers, map
  walkability, biome speed modifiers, and the former merchant travel speed of 70 world pixels
  per world-simulation second.
- Starting travel on a stationed party adds it to the map through `Map:addParty`, which removes
  its stationed membership. Arrival uses `Map:stationParty`; NPC availability therefore continues
  to derive from the party roster without copying actors into `location.npcs`.
- Active travel owns movement and pauses during active encounters. The world clock remains the
  source of elapsed travel time, so paused world time freezes movement. Player input is suppressed
  while the player's party has an active travel activity.
- Completion, cancellation, and failure expose a serializable outcome containing the destination
  ID, status, and reason. Invalid or removed destinations terminate travel without arrival.
- Travel does not transfer cargo, treasury, actors, or personal possessions, and does not choose
  destinations or trigger merchant behavior.

## Remaining limitations

- Automatic merchant departures, autonomous destination choice, and trade planning are not
  implemented. Merchants can receive explicit TravelActivity or actor-owned Reach Location goals.
- Road travel requires locations with generated road-site IDs and a connected road route. Parties
  not stationed at a location start from their nearest road-site location; the initial connector
  is subject to normal walkability and can fail as a stalled route.
- Full save/load and campaign migration remain out of scope.

This milestone deliberately avoids a broad ECS restructuring and preserves existing Raid, battle,
inventory, and location membership behavior.

## Actual Milestone 4A NPC goals foundation

### Representation and public API

`src/systems/goal_system.lua` exposes:

- `GoalSystem.configure(actor, definitions, capabilities)`: opt an actor into goal control,
  replacing its goal list and capability flags. Replacement is rejected while a goal still owns
  an activity. An empty configured list deliberately suppresses legacy automatic Raid too.
- `GoalSystem.addGoal(actor, definition)`: append a goal without interrupting existing work.
- `GoalSystem.cancelActivities(actor, reason)`: explicitly cancel owned attempts and observe
  their outcomes without advancing time. Rejects cancellation while an owned party is reserved
  by an encounter. The debug editor uses this before replacing goals.
- `GoalSystem.update(elapsedWorldSeconds, map, playerParty)`: evaluate and request activities.
  `CampaignRuntime.update` schedules evaluation after world encounters advance and before fallback movement and
  activity execution. A zero elapsed time does nothing, including leaving retry timers frozen.

One optional `npc_goals` Concord component belongs to a persistent actor. It stores `goals`,
`capabilities = {raid = true, travel = true}` and an evaluation cooldown. Capability flags default
to disallowed and have no species/profession checks. Configuration copies supported definition
fields into plain data; there are no entity references, callbacks, or profession-specific classes.
The component can be serialized with Concord, independently of the deferred full save/load work.

```lua
local GoalSystem = require("src.systems.goal_system")
GoalSystem.configure(leader, {
    {type = "acquire_gold", amount = 200, priority = 20},
    {type = "reach_location", destinationLocationId = destination.id, priority = 10}
}, {raid = true, travel = true})
```

A runtime goal retains its definition plus `status` (`pending`, `active`, `blocked`, `satisfied`),
optional `reason`, `attempts` (accepted activity starts), `retrySeconds`, optional
`activity = {partyId, sequence}`, and `lastOutcome = {status, reason, activityType}`.
Activity sequences are monotonic per party and copied into `world_activity.lastActivity`, allowing
the evaluator to associate terminal outcomes with its own attempt after activity cleanup.

### Evaluation, ownership and outcomes

- Living non-player actors are queried from the campaign ECS after flushing pending membership.
  Command is resolved from the actual leader and roster of traveling and stationed map parties.
  Milestone 7A also evaluates independent important residents: local recovery works without a
  party, while party-dependent goals remain blocked. Missing or destroyed parties cannot satisfy
  goals and are never recreated. Non-leader members and unattached actors are inactive.
- Evaluation occurs once per world-simulation second per actor, or on an observed terminal
  outcome. Higher priorities are considered first; insertion order breaks ties. An infeasible
  goal permits consideration of a lower-priority goal. Active work is never preempted merely
  because priorities change. Milestone 7A adds an explicit recovery safety interruption below.
- Acquire Gold reads `PartySystem.getTreasury`. It can request existing Raid only with the
  actor's `raid` capability, existing party hostility, a traveling party, and an eligible visible
  target from `RaidActivity.hasEligibleTarget`. Visibility, target choice, pursuit, encounters and
  loot remain owned by the existing pipeline.
- Reach Location requests existing Travel using a stable destination ID. Satisfaction requires
  that the actual commanded party is in the live destination's `stationedParties`; activity success
  alone or proximity alone is insufficient. Missing/removed destinations block the goal safely.
- Encounter reservations and source encounter cooldowns prevent selection. Active or terminal
  activities and activity retry cooldowns are respected. The evaluator never writes positions,
  inventories, treasuries or battle results and never claims externally assigned activities.
- Completion, failure, cancellation or a missing owned activity triggers a fresh check of the
  desired condition, followed by a ten-world-second retry delay if still unsatisfied. Failed start
  requests also back off. Conditions are checked again periodically, so satisfied goals may become
  pending again if the actual condition ceases to hold.
- When an owned goal becomes satisfied during execution, its activity is cancelled through
  `WorldActivitySystem`; a reserved encounter is allowed to finish first. Loss of command cancels
  the old owned activity once its encounter reservation is released. Selected activities carry a
  primitive `goalActorId` so this check also releases commands from dead or removed actors that
  no longer participate in evaluation. Destroyed parties cannot keep executing goal commands.
- Legacy automatic Raid skips parties whose current leader has `npc_goals`, including leaders
  with satisfied, blocked or empty goal lists. Unconfigured leaders retain existing automatic Raid.
  Explicit activities and fallback wandering remain available. Terminal cleanup and activity
  cooldown ticking also cover stationed parties, allowing later goal-selected departures.

### Current limits and verification

This is an opt-in foundation: generation and troop templates do not assign goals automatically.
The example above configures existing actors; it does not add NPC archetypes or alter initial
world generation. Raid still requires existing hostility and map presence; there is no automatic
departure to raid, item valuation, trade method, knowledge model, faction planning or quest creation.
Only the currently active map is evaluated. Travel retains its existing connected-road and
walkability/stall limitations. Retry delay and evaluation interval are simple shared settings,
without recursive planning, escalating backoff or general priority preemption. Full campaign save/load is
still deferred.

`tests/unit/npc_goals_scenario.lua` uses the existing LÖVE/assert scenario conventions and covers
selection, priority stability, capability gating, real stationing, external activity ownership,
removed destinations, outcome backoff, partyless/destroyed-party safety, legacy Raid compatibility,
paused timers, component serialization and a real Raid → battle → treasury → satisfaction chain.
It is registered in `tests/unit/main.lua`.

Manual playtests should configure an existing hostile leader with a gold target, advance world
time through a raid and inspect its actual treasury/goal state; assign a Reach Location goal to a
stationed leader on a connected road; and repeat while waiting, resting, pausing and accelerating
time. Also inspect interruption by a player encounter and resumed decisions after its outcome.

### Development demonstration with the existing debugger

The in-game alternative is now **F1**, then right-click a party and choose **Configure leader
goal** or **Inspect party**. Location inspection also links to stationed parties. See
`docs/DEBUG_MODE.md` for controls, replacement semantics and extension points. The external
debugger expressions below remain useful for lower-level inspection.

The repository's `.vscode/launch.json` already defines **Debug Love** (`lua-local`);
`main.lua` starts `lldebugger` when that launcher sets `LOCAL_LUA_DEBUGGER_VSCODE=1`.
This requires the Local Lua Debugger extension and `love` on PATH. There is no in-game Lua
console. Start a campaign under that configuration and break inside `WorldState.update`.
Inspect these expressions in the Debug Console/Watch view to choose existing entities:

```lua
require("src.game.game_context").data.currentMap:getParties()
require("src.game.game_context").data.currentMap:getLocations()
```

Location entries expose `stationedParties`; parties expose `id`, `leaderId`, `treasury`,
and `world_activity`. Choose two different living NPC-led parties, outside encounters.
For Raid choose a traveling hostile party with a visible eligible merchant/player target.
For Travel choose a stationed party and a different location connected by generated roads.
Replace the placeholder IDs below. Evaluate each block as one expression (join its lines
if the console accepts only one line). The blocks return the configured component for inspection.

```lua
(function()
    local p = assert(require("src.ecs.world").findPartyById("RAIDER_PARTY_ID"))
    require("src.systems.world_activity_system").cancel(p, "goal_demo_setup")
    return require("src.systems.goal_system").configure(
        assert(require("src.systems.party_system").getLeader(p)),
        {{type = "acquire_gold", amount = p.treasury + 100}}, {raid = true})
end)()
```

```lua
(function()
    local p = assert(require("src.ecs.world").findPartyById("TRAVELER_PARTY_ID"))
    require("src.systems.world_activity_system").cancel(p, "goal_demo_setup")
    return require("src.systems.goal_system").configure(
        assert(require("src.systems.party_system").getLeader(p)),
        {{type = "reach_location", destinationLocationId = "DESTINATION_LOCATION_ID"}},
        {travel = true})
end)()
```

Use fresh, unconfigured leaders; replacing goals while they own an activity is rejected.
Resume and hold Space to advance world time, allowing any cancelled activity's normal cooldown
to expire. Release Space while stationary to freeze evaluation/retries; rest or change the
existing `TimeSystem.setTimeScale` to compare pacing. Break again and inspect these expressions
for each selected party ID:

```lua
require("src.systems.party_system").getLeader(require("src.ecs.world").findPartyById("PARTY_ID")).npc_goals
require("src.ecs.world").findPartyById("PARTY_ID").world_activity
```

Expand `goals[1]` for `status`, `reason`, `attempts`, `retrySeconds`, `activity` and `lastOutcome`.
The party component shows the selected type/phase/sequence and `lastActivity`; treasury and
destination `stationedParties` show the real satisfaction conditions. Missing opportunities
remain visible as blocked goals. Existing world encounter log messages and hover markers show
combat progress. These snippets change only the running campaign, with no generation or UI changes.

### Deferred goal design considerations

- Goal-selected raids should eventually be independent of global party hostility.
- Fortress-stationed leaders need a way to seek raid opportunities beyond immediate visibility.
- A goal may eventually require several activities, such as travel, raid, then return home.
- NPC archetype templates will eventually supply initial goals and capabilities.

These are design considerations only; none is implemented in Milestone 4A.

### Milestone 5B: generic RoamActivity

`WorldActivitySystem.start(party, "roam", params, map)` starts explicit roaming
for any party (including the player). Parameters are primitive values:

- `originX`, `originY`: finite world coordinates; alternatively supply
  `originLocationId` for a persistent location in this map and campaign.
- `radius`: positive finite radius in world pixels. The party must already be
  inside this circle; Roam does not travel to or teleport into its area.
- `durationSeconds` (optional): positive duration in world simulation seconds,
  using the same scaled time passed to Travel, not wall-clock seconds or game hours.
  Omit it to continue until cancelled or unable to proceed.

Each destination selection samples at most 12 points uniformly over the circle.
Candidates must be at least `min(16, radius / 4)` pixels from the party. Existing
`Navigation.findPath` validates bounds, walkability and reachability. Every returned
waypoint must lie within the circle; convexity keeps the connecting segments inside.
No new navigation grid, terrain model or pathfinder is introduced. A rejected batch
returns `no_roaming_destination`; it does not retry forever.

Roam follows the accepted route with the shared waypoint movement helper at base
speed 70, retaining existing biome penalties and road bonuses. It selects another
route on the update after arrival, with at most one selection batch per update.
Only explicit world simulation time advances movement, duration and stall timers.
World pauses and encounter reservations freeze them. Duration expiry completes with
`duration_elapsed`; 15 simulation seconds without progress fails with `route_stalled`.
As with Travel, update failures use the activity system's cancelled outcome convention.

The existing single-activity guard rejects attempts to replace active work. Fallback
AI and player keyboard movement yield to Roam. Stationed parties depart through
`Map:addParty`. Removal cancels roaming; destroyed parties are removed on update.
A deleted origin location fails with `origin_missing`, and moving that location fails
with `origin_moved`. External displacement outside the circle also terminates roaming.
Cancellation uses `WorldActivitySystem.cancel(party, reason)` and normal terminal cleanup
and retry cooldown. Completion/cancellation restores the previous party state without
returning home or stationing. Ordinary fallback behavior may resume afterward.

Retained component state consists of primitive params, origin coordinates,
`elapsedSeconds`, waypoint coordinates/index, and the previous state. It holds no
entity references. Existing debug inspection shows activity type, phase and last
outcome; the debugger can inspect the full serialized component.

Limitations: finite random sampling can miss viable destinations. A* may prefer a
route outside the circle even when a more expensive contained path exists; that
candidate is rejected rather than modifying navigation. Very small circles relative
to grid cells may provide no suitable route. There is no dynamic replanning or pause
between destinations, and leftover time at a destination is not used for a second
destination selection in the same update. Goals are neither created nor changed;
goal-driven interruption and Roam-to-Raid transitions are added in Milestone 5C below.

#### Manual roaming demonstration

For explicit activity assignment independent of goals, run **Debug Love**, break
in `WorldState.update`, and use the
debugger console with an idle party ID (no active encounter or retry cooldown):

```lua
(function()
    local map = require("src.game.game_context").data.currentMap
    local party = assert(require("src.ecs.world").findPartyById("PARTY_ID"))
    return require("src.systems.world_activity_system").start(party, "roam", {
        originX = party.x, originY = party.y, radius = 300, durationSeconds = 30
    }, map)
end)()
```

Resume and hold Space for an NPC party; release it while stationary to verify pause.
An explicitly roaming player advances time automatically, like Travel; use time scale
zero to freeze it. Enable F1 and inspect the party to see `roam / active / roam` and
the final `duration_elapsed` outcome. In the debugger inspect `party.world_activity`
for the route and elapsed time. Omit duration for continuous roaming; cancel with
`WorldActivitySystem.cancel(party, "manual_stop")`. Location-centered roaming uses
`{originLocationId = "LOCATION_ID", radius = 300}` with a party already in that area.
Try terrain obstacles and roads, and observe encounter suspension and subsequent resume.

### Milestone 5C: goal-driven opportunity seeking

Acquire Gold may use the existing Roam activity when no eligible Raid target is
visible. Both `raid` and `roam` capabilities must be explicitly enabled, and the
goal must have a configured territory. Goals still belong to persistent actors
and command only their current party. No additional goal type is introduced.

```lua
GoalSystem.configure(leader, {{
    type = "acquire_gold", amount = 200,
    roam = {originX = 500, originY = 500, radius = 300, durationSeconds = 60}
}}, {raid = true, roam = true})
```

`roam` accepts the same parameters as RoamActivity: world-coordinate origin or
`originLocationId`, positive radius, and optional positive `durationSeconds`.
Configuration copies these values, retaining no entity references. The commanded
party must already be traveling and inside the circle. This goal does not launch
stationed parties. Explicit Travel/Roam departure APIs remain available.

While goal-owned Roam runs, the evaluator checks for opportunities at its existing
one-world-second evaluation interval, independent of attempt retry timers.
`RaidActivity.selectTarget` reuses the existing nearest eligible visible target
selection; `visibleTarget` revalidates a specific ID. Neither selection uses unseen
target positions to plan destinations. Pausing world time freezes evaluation,
movement, and retry timers. Encounter reservations prevent interruption.

A transition checks the goal's party ID and activity sequence plus `goalActorId`.
It stores only `detectedTargetId`, then calls normal cancellation with
`opportunity_detected`. The activity executor releases Roam's waypoints and restores
its previous party state before Raid can start on the next simulation update.
Only this goal-owned Roam cancellation skips the ordinary five-second activity
cooldown and ten-second goal backoff; its cancelled outcome is still recorded.
GoalSystem waits for idle activity state, rechecks visibility/eligibility, and starts
Raid with `targetPartyId`. Raid rechecks that ID at acquisition and never substitutes
another target. If it disappeared during the handoff, the goal resumes seeking;
if lost during Raid, the existing pursuit/lost-sight failure and backoff apply.
External/manual activities are neither claimed nor cancelled by opportunity detection.

Ordinary completions and failures retain retry behavior. Expired Roam remains an
unsatisfied attempt and may run again after backoff. Legacy fallback wandering is
suppressed for leaders with Raid/Roam capabilities and an Acquire Gold territory,
including while waiting or satisfied, so it cannot move them outside that territory
between attempts. Other parties retain existing fallback movement and goal-free
hostile parties retain automatic Raid. Active explicit activities still own movement.

Raid uses the existing encounter, casualty, and loot pipeline. Only actual party
treasury satisfies Acquire Gold; cargo is not valued as money. Satisfaction cancels
owned roaming, while reserved encounters finish normally. Existing dead/removed
leader and party checks release commands and prevent further attempts.

#### Debug configuration and manual verification

1. Enable F1 and right-click a traveling hostile NPC party. Select **Configure leader
   goal**, choose **Acquire Gold**, and enter a treasury target above its current gold.
2. Enable **Raid capability** and **Roam capability**. Set origin X/Y and radius so
   the party is inside walkable territory; optionally set a duration in world seconds
   (blank means unlimited). Defaults show its current position and radius 300.
   Applying a location-origin goal through this coordinate editor converts its origin
   to the displayed coordinates. The API also accepts location IDs directly.
3. Apply, then hold Space to advance world time. The live inspector shows goal state,
   treasury, capabilities, territory, current activity, target ID, and latest outcomes.
   Release Space while stationary to verify pause. Editing the form pauses world input.
4. With no detectable target, observe Roam. When an eligible caravan enters sight,
   observe the cancellation outcome followed by Raid against that ID. Watch the real
   encounter outcome and treasury: sufficient gold satisfies the goal; insufficient
   gold or failure leads to backoff and another seeking attempt.

Limitations: existing hostility restrictions and eligible target categories (traveling
or wandering trader parties and the player) remain. No unseen knowledge, automatic
territory choice, fortress departures, return-home behavior, or new planner is added.
Roam remains bounded; Raid pursuit retains its existing behavior and may leave that
circle. If it does, subsequent Roam fails with `party_outside_roaming_area` until the
party is returned or its territory is explicitly reconfigured. Existing bounded random
sampling and navigation limitations still apply. Fast targets can pass through sight
between evaluation ticks. No generation or high-level simulation design changed.

Verification: the existing NPC-goals scenario now covers Roam selection, owned
handoff, disappearing targets, fixed Raid targeting, duration/retry, manual ownership,
pause, and real encounter gold feedback. The debug scenario covers territory input
validation. The suite remains 14/17 passing: the previously reported combat timeouts
in `headless_battle_scenario`, `world_encounter_scenario`, and
`battlefield_remains_scenario` remain outside this milestone.

## Actual Milestone 6A: World Event Log and F2 viewer

`src/systems/world_events.lua` owns private history keyed by the persistent campaign
Concord world, not the transient exploration screen or a map. The weak-key store
lives for the lifetime of that world; independent worlds have independent histories.
Scene transitions retain history. EventBus remains transient notification only.

API (explicit campaign world argument):

- `record(world, type, data, sourceKey?)` returns a defensive event copy. Supply
  `data.time = {day = ..., hour = ...}` from the campaign clock. An optional unique
  occurrence key makes repeated recording return the original event unchanged.
- `get(world, id)`, `getAll(world)`, `getByType(world, type)`, and
  `getBySubject(world, subjectId)` return defensive copies. Integrations explicitly
  declare a `subjectIds` array (party, actor, location, map, or battlefield IDs).
- `count(world)` and `getAt(world, chronologicalIndex)` support bounded viewer reads.
- `serialize(world)` returns a version-1 plain-data snapshot of events and occurrence
  keys. Pair it with the campaign allocator snapshot for future persistence work.
  There is currently no event restore API or disk save/load implementation.

IDs use the existing campaign allocator's `event_*` namespace. Events contain
`id`, `type`, a campaign day/hour `time`, and compact event-specific plain data.
They are ordered by timestamp, preserving insertion order on ties. Input tables,
returned events, query arrays, and snapshots never alias stored history. Metatables,
functions, cycles, and non-finite numbers are rejected. There is no update/delete API.

The NPC battle emitter is `WorldEncounterSystem.finishEncounter`: it captures
party names and actor IDs before removal, then records `battle_ended` after
`LootApplication.apply` and `CampaignBattleResultApplier.apply`, before encounter
removal, activity completion notifications, and runner cleanup. The timestamp is the
campaign clock at finalization (the same minute-resolution clock used by remains),
not wall time or elapsed combat ticks. Incremental execution records nothing until
completion. The encounter guard and `battle_ended:<encounterId>` occurrence key
prevent repeat completion from producing another record.

Player-interactive battles also record `battle_ended` from
`BattleState.checkBattleEnd`, after the existing casualty, gold, enemy-party removal,
and favor application, before victory/completion callbacks and scene transition.
`BattleState.enter` captures historical participant identities and campaign-map
coordinates and allocates a campaign-scoped `player_battle_*` encounter ID. A
completion guard prevents repeated or reentrant checks from applying consequences
or recording twice. Victory, player defeat (a victory for the enemy), and mutual
destruction (draw) use actual surviving units. Eliminated IDs only describe parties
actually removed by this path. Player battles currently create no battlefield
remains, so their history omits that optional reference. Their combat/loot flow is
otherwise unchanged.

Player-battle regression checks in `battle_simulation_scenario` cover historical
victory, defeat, draw, identity retention, world timestamps, absent remains, and
duplicate/reentrant completion. That scenario and the world-event, raid-encounter,
and world-time-sync scenarios pass after the player integration was added.

Battle records contain encounter/map IDs, coordinates, participants with historical
names and actor IDs, per-party casualty counts, the actual victory/draw/timeout
outcome, winner and defeated IDs where applicable, eliminated party IDs, combat
ticks, and an optional battlefield ID. Draw and timeout records never invent a
winner. Eliminated parties remain identifiable after removal. Resources and full
combat logs are not copied. Changing or removing corpses, loot, or battlefield
resources never rewrites history; `BattlefieldRemainsSystem` remains authoritative
for current resources.

`src/ui/screens/world_event_viewer.lua` supplies the two-panel read-only overlay;
`src/ui/world_event_text.lua` handles descriptions, calendar formatting, and complete
sorted field inspection separately. On the exploration screen, **F2** toggles it;
**Escape** or **Close** closes it. Click an entry to select it, and use the mouse
wheel over either panel to scroll independently. The list is newest-first, highlights
the selection, draws only visible rows, and reads newly recorded events each frame.
Layout follows window dimensions; empty histories display a clear message.

The viewer follows the existing live F1 inspector's time policy: it does not add a
pause mode. Opening clears held gameplay inputs and closes F1 menus/editors; normal
world time remains paused while stationary, while an existing travel/roam activity
or rest can continue and produce events. Keys and pointer actions used in the viewer
do not reach gameplay controls. F1 remains available. Scene transitions close the
viewer, and history remains available when returning to exploration.

Limitations before 6B: F2 is an exploration-screen tool; player-interactive battles
retain their existing casualty/loot/completion path and do not create battlefield
remains. No broad combat refactor was introduced. History is
unbounded in memory, queries are simple linear scans, and descriptions are not
localized. The viewer is omniscient debug inspection only. Recording does not grant
knowledge; future party/major-NPC memories will reference event IDs. No memory,
discovery, communication, necromancy, or additional gameplay event emitters are
implemented.

Verification: `world_events_scenario` covers defensive copies, IDs, chronological
queries, independent campaigns, duplicate occurrence keys, incremental completion,
victory/draw/timeout, partial casualties, destroyed participants, mutable remains,
optional absent remains, and lightweight LÖVE rendering/input/scroll checks. It uses
controlled battle-unit HP to exercise real result resolution and finalization
without depending on the existing combat timeout bug. All 18 scenarios were run
independently: 15 pass; the prior failures persist in `headless_battle_scenario`
(timeout at 4000 ticks), `world_encounter_scenario` (expected victory), and
`battlefield_remains_scenario` (eliminated-party cargo assertion after timeout).
No existing assertions were weakened. The game was launched with the same LÖVE
executable/project arguments as Debug Love, but Windows capture timed out twice;
live manual clicking, natural NPC battle observation, and resize playtesting remain
unverified. Automated rendering/input checks are not a substitute for that pass.
A separate LÖVE-rendered 800x600 fixture with 100 synthetic battle events was
visually inspected: the two panels, selection, wrapped descriptions, and clipped
scrollable detail layout rendered correctly. This was a rendering fixture, not
manual verification of a naturally occurring gameplay battle.

## Actual Milestone 6B: actor and party memory

Actors and parties use the same optional Concord `memory` component:

```lua
owner.memory.knownEvents = {
    event_1 = {details = {location = true, participants = true}}
}
```

Entries contain stable event IDs and true flags only, never event copies, live
entities, resource pointers, confidence, or expiration. History stays in the
campaign's World Event Log. Recording history grants no knowledge.

Every party assemblage gets an empty memory. Personal memory belongs to an actor,
independent of membership or leadership. Existing `player` and `companion` template
types receive memory in the unit assemblage. Named settlement NPC creation and
the initial custom bandit leader, wandering trader, and debug trader explicitly
attach it. Other important characters can opt in with `actor:ensure("memory")`.
There is no new character taxonomy: ordinary unit names, recruitment, goals, and
appointment as leader do not grant personal memory. In particular, the existing
`npc` marker means settlement/dialogue NPC, not all non-player combatants. Custom
NPC creation sites must explicitly opt in when appropriate; names alone cannot
distinguish template-named soldiers from important individuals.

`src/systems/knowledge_system.lua` exposes plain functions:

```lua
local Knowledge = require("src.systems.knowledge_system")
Knowledge.learn(actor, "event_1", {"location"}, world)
Knowledge.learn(party, "event_1", {participants = true}, world)
Knowledge.knows(actor, "event_1", world) -- existence, not complete knowledge
Knowledge.getKnownEvent(actor, "event_1", world) -- filtered view or nil
Knowledge.getKnownEvents(actor, world, "battle_ended") -- optional type filter
Knowledge.getKnownDetails(actor, "event_1", world) -- copied category flags or nil
Knowledge.share(actor, party, "event_1", world) -- source -> recipient only
Knowledge.getDetailCategories("event_1", world) -- supported names for debug UI
```

Owner-based calls may omit `world` to use the owner's actual ECS world. Learning
and sharing return `true` or `false, reason`. Invalid categories reject the entire
request without partial changes. Nil/empty details learn existence only. Repeated
learning/sharing unions flags permanently, without duplicate entries. Sharing
transfers only the source's flags, preserving the recipient's previous knowledge.
No social, faction, party-member, or leadership synchronization is installed.

Reads require a live actor/party in the specified world. A private weak runtime
binding also rejects memory moved to another owner/campaign, even when separate
campaigns reuse `event_1`. That binding is outside component serialization; entries
and the normal component snapshot contain plain data only. There is no memory
restore API yet: future persistence must restore history and memory together and
reestablish provenance in the correct campaign. Destroyed owners use normal ECS
cleanup; there is no personal-memory archive. Destroying historical participants
does not affect another owner's knowledge, which reads recorded facts by event ID.

Battle projections explicitly allowlist both top-level and nested fields:

| Category | Historical facts exposed |
| --- | --- |
| `time` | Campaign day/hour |
| `location` | `x`, `y`, optional `battlefieldId` |
| `participants` | Party IDs, recorded names, actor IDs; no casualty counts |
| `outcome` | Outcome, winner/defeated/eliminated party IDs, `casualties[partyId]` counts |

Every view includes `id` and `type`. Location-only views contain no time,
participants, winner, casualties, or outcome. Internal map/encounter IDs, ticks,
subject indexes, unrestricted summaries, and arbitrary nested fields are never
projected. All read results can be modified without altering history or memory.
Unknown events cannot be read. Future types add small explicit projections in
the module; unrecognized types support existence only. Queries inspect only the
owner's entries, return deterministic event-ID order, and optionally filter by
type; they never discover events by scanning global history.

F1 party inspection shows shared memory, event count, IDs/types, known categories,
and descriptions from filtered views using `src/ui/knowledge_text.lua`. Actor
links open personal memory for important party members; location inspection links
to resident NPCs and stationed parties. **Grant event knowledge** opens a small
debug-only form: enter an existing ID from F2, toggle specific categories, and
grant. No selected categories means existence only. This uses the existing editor
input/scroll/pause conventions. F2 remains the unrestricted historical viewer.

For 6C, a battlefield reference is evidence of a historical battle, not proof of
current corpses or loot. Goals must query owner knowledge, travel, then inspect
`BattlefieldRemainsSystem` for current resources. Discovery, observation, automatic
sharing, necromancy, and save/load remain deferred. Storage is unbounded; reads
use simple scans with no new index or universal detail-schema engine.

Verification: `knowledge_scenario` covers actor/party learning, existence and
partial views, nested-field filtering, expansion, directional unions, independent
owners, defensive reads, generic leaders without personal memory, membership
changes, destroyed participants/owners, campaign collisions, and F1 rendering and
grant controls. It passes. The initial combined suite reached the preexisting
`headless_battle_scenario` timeout at 4000 ticks after the preceding scenarios
passed. Subsequent independent runs had 7 passing scenarios and 12 blocked during
module loading by an unrelated missing comma in `src/data/items/melee_weapons.lua`
at line 106 (reported at line 107). That file was not changed for 6B. The previous
world-encounter and battlefield-remains failures could not be reassessed in those
runs. Live manual gameplay inspection remains unverified.

## Actual Milestone 6C: battle participation and battlefield discovery

`src/systems/battle_knowledge_system.lua` supplies two acquisition hooks that
always call `KnowledgeSystem.learn`; it owns no memory or event store. Both grant
the four supported battle categories (`time`, `location`, `participants`, `outcome`).
F1 continues to read filtered owner knowledge; F2 continues to show full history.

**Participation:** NPC encounter finalization and interactive player-battle
completion call `learnParticipants` immediately after recording `battle_ended`.
The historical participant IDs and a surviving-actor-ID set are captured before
campaign casualty/removal callbacks can change rosters. Only surviving participants
with personal memory and surviving participating parties with shared memory learn
the event. Survival comes from actual battle results, including on the enemy side
of interactive battles where campaign HP is not fully synchronized by the existing
combat path. Dead, destroyed, unrelated, and memoryless owners are safely skipped.
Existing completion guards plus monotonic learning prevent duplicate history or
memory when processing repeats. No knowledge-acquisition event is emitted.

Forest Bandits' starter leader already explicitly receives `memory` in
`GameInitializer._createStarterParties`; its `bandit` troop template alone is generic.
That creation path and classification were left unchanged. Its other five starting
bandits remain generic troops without personal memory.

**Discovery:** Newly finalized NPC remains store their associated event ID in
`site.history.eventId`, which survives existing remains serialization. Older sites
without that link resolve through the event log's subject query, requiring matching
battlefield, map, and encounter IDs. Missing history or a mismatched explicit link
grants nothing. Resolving this exact site does not reveal other historical battles.

The established `VisibilitySystem.update` now applies its existing
`(partySight + siteProfile) / radiusDivisor` sight test to battlefield remains for
each traveling party. An in-range observer learns that site's event along with its
current living members who have personal memory. Each party is checked independently:
the global sticky `site.discovered` flag is not used as a knowledge gate. Render
flags (`discovered`, `currentlyVisible`) retain their player-only meaning, so an
NPC discovery does not reveal player map markers. Repeated in-range observations
merge the same flags and can teach members present at the site; joining a party
away from the site does not synchronize knowledge. Stationed parties and settlement
residents are not battlefield observers in this milestone.

Knowledge remains historical. Discovery and participation do not copy corpses or
loot into memory, change resources, or prove resources remain available. Resource
availability still belongs to `BattlefieldRemainsSystem`. There is no information
spreading, travel-event integration, necromancy, faction behavior, or persistence
expansion. Visibility uses straightforward party/site scans with no new perception
index. Synthetic or legacy remains without a corresponding event remain visible
and usable through existing interactions, but cannot grant event knowledge.

Verification: `battle_knowledge_scenario` exercises the real starter-party creation
path, controlled victory through the real encounter/result/loot/remains pipeline,
surviving leader and party memory, generic troops, distant owners, later player/NPC
discovery of the same event ID, hidden sites, repeat processing, restored/legacy
associations, depleted resources, destroyed observers/participants, optional memory,
timeout survivors, and draws. Controlled battle HP keeps acquisition tests independent
of existing combat bugs. `battle_simulation_scenario` additionally checks interactive
victory/defeat/draw knowledge, acquisition before completion callbacks, and repeated
completion. All 20 scenarios ran independently: 17 pass. The existing failures remain
in `headless_battle_scenario` (4000-tick timeout), `world_encounter_scenario` (expected
victory, received timeout), and `battlefield_remains_scenario` (cargo assertion after
timeout). The combined suite reaches the same headless failure. The previously
reported melee-weapon syntax error was already fixed in the checkout; no additional
syntax or combat changes were needed. `git diff --check` passes.

Manual playtest (new campaign):

1. Keep the player outside sight of the starter battle, advance world time, and
   let Forest Bandits defeat Wandering Trader. In F2 note the resulting event ID
   and coordinates.
2. Enable F1, right-click Forest Bandits, and inspect its party memory. Open its
   leader through **Inspect actor**: both should contain that ID and all four
   categories. An unrelated distant party should lack it. Generic troop actors
   still have no personal `memory` component (inspect through the debugger).
3. Inspect the player's party before approaching, then walk within the existing
   sight radius of the remains. Inspect the party, player, and companion again:
   each should now know the same event ID. For another NPC observer, move an
   unaware traveling party into range through the debugger and advance the world;
   its important members should learn without revealing markers to a distant player.
4. Leave and reenter sight, and advance several updates. The original event ID
   should occur only once in each owner's memory and once in F2. Inspect actual
   remains separately for current resources. These updated live gameplay steps
   remain a manual verification task; automated scenarios above pass.

## Milestone 6D: travel history and information spreading

`TravelActivity.prepare` captures the origin from existing stationing membership
before `Map:addParty` unstations it. `onStart` records `party_departed` only after
that transition succeeds. The destination is an intention. The arrival branch
of `TravelActivity.update` records `party_arrived` only after the existing route
completion/radius checks and successful `Map:stationParty`. Failed, cancelled,
removed, or stalled travelers get no arrival or exchange. Encounter reservations
continue to pause travel through the existing activity dispatcher.

`src/systems/travel_knowledge_system.lua` owns these acquisition hooks, using
`WorldEvents.record` and the existing `TimeSystem` day/hour clock. Records contain
plain historical snapshots, never entity references:

| Field | Meaning |
| --- | --- |
| `id`, `type` | Assigned by WorldEvents |
| `time` | Simulation day/hour at departure or successful arrival |
| `partyId`, `partyName` | Participating identity at recording time |
| `originLocationId`, `originLocationName` | Origin captured before departure, when present |
| `destinationLocationId`, `destinationLocationName` | Intended destination on departure; actual location on arrival |
| `mapId`, `x`, `y` | Map identity and party coordinates at recording time |
| `subjectIds` | Party, destination, and optional origin for historical queries |

Renaming or destroying entities cannot rewrite these records. A wilderness start
retains normal routing and can record an arrival without an origin; it emits no
location departure. A request to travel to the same stationed location emits
neither event nor exchange. Initial placement, generic stationing, Roam, Raid,
waypoint changes, and combat movement have no travel-history hooks.

Travel knowledge uses the existing event-ID/detail-flag memory model:

| Category | Departure projection | Arrival projection |
| --- | --- | --- |
| `time` | Day/hour | Day/hour |
| `party` | Party ID/name | Party ID/name |
| `location` | Coordinates and origin ID/name | Coordinates, destination and optional origin ID/name |
| `destination` | Intended destination ID/name | Not a category; included in `location` |

Only allowlisted scalar identities/names and a copied day/hour table are exposed;
map IDs, subject indexes, arbitrary nested fields, and unknown details stay hidden.
The party and its living important members learn all supported details of their
own travel events. Generic troops never receive personal memory. Remote sponsors
and other unrelated owners learn nothing merely because history was recorded.

Each meaningful successful arrival performs one bounded exchange:

1. Living important travelers merge their personal knowledge into party memory.
2. `LocationSystem.getAvailableNpcs` resolves actual independent residents and
   members of stationed parties, deduplicating actors and pruning removed members.
   The arriving roster, dead or removed actors, memoryless troops, actors outside
   the campaign, and actors/parties reserved in encounters are excluded.
3. Each eligible NPC receives one random roll. `exchangeProbability` defaults to
   **0.5**, with `TravelKnowledge.random` wrapping `love.math.random` and allowing
   deterministic injection in scenarios. Selected NPCs and the arriving party
   share all known events in both directions using `Knowledge.share`. Already
   known flags are skipped; only existing source knowledge can transfer.
4. Party knowledge merges back into living important travelers' personal memories,
   allowing information to survive later membership changes.

The per-activity plain `travelJourney` snapshot stores departure/arrival event IDs.
The arrival ID is set before exchange, preventing repeated callbacks from rerolling
partners; terminal cleanup releases the journey. A genuine later journey gets a
new snapshot and opportunity. No per-frame synchronization or real-time timer is
introduced. WorldState's existing simulation-time gating prevents arrivals while
paused; explicit debug travel starts may still record a departure.

F2 formats both travel types and retains its complete historical detail pane. F1
describes filtered travel views and shows the party's last arrival ID/location,
selected/eligible NPC counts, event transfers, and added category flags. Transfer
counts include member synchronization; event transfers count successful source to
recipient additions, not unique global events. The summary is transient debug data.

Limitations: no settlement memory, remote sponsor notification, proximity sharing,
faction propagation, conversation events, social model, new goals, or save/load.
Selected conversations share all known events, and later conversations in the same
arrival may carry information learned earlier in that arrival. Residents retain
personal knowledge; their stationed party synchronizes on its own next arrival.
Future topic selection or additional communication triggers can reuse the same
Knowledge APIs without changing historical records.

Verification: `travel_knowledge_scenario` covers lifecycle/deduplication, paused
updates, failure/removal paths, immutable historical names, filtered travel views
and nested-field exclusion, own-journey acquisition, controlled resident selection,
bidirectional partial unions, generic/dead/unavailable actors, personal retention,
and battlefield sight discovery followed by arrival and onward carriage of the
same battle ID. All 21 scenarios ran independently: 18 pass. The three existing
combat failures persist: `headless_battle_scenario` times out at 4000 ticks;
`world_encounter_scenario` expects a victory but gets a timeout;
`battlefield_remains_scenario` fails its eliminated-party cargo assertion following
a timeout. No combat fixes are included. `git diff --check` passes.

Manual playtest (live UI remains unverified):

1. Discover a recorded battlefield with a party using the existing sight system.
   Confirm its battle event ID in F1 and F2.
2. In F1 configure that party leader's existing Travel goal to a village with
   important residents, enable Travel capability, then advance world time by
   moving/waiting. If starting in wilderness, expect only an arrival; start a
   subsequent journey from a stationed location to test both event types.
3. In F2 inspect departure and arrival names, IDs, day/hour, and coordinates. In
   F1 inspect the party's last-exchange counts, its important members, and resident
   NPC memories. Selection is random, so a particular visit may select all or none.
4. Send another party to that village, then onward to another inhabited location.
   Verify the same battle ID spreads through selected residents and travelers.
   Genuine later returns allow new rolls; waiting, pausing, reopening F1/F2, and
   duplicate stationing do not. A distant sponsor stays unaware until contacted.
5. Cancel travel before arrival and verify there is no arrival record or exchange.
   Use F1's existing Grant event knowledge control to give an unrelated actor
   existence/party-only travel knowledge; its description must omit unknown places
   and time, while F2 continues to show the full event.

## Milestone 7A: independent goals and RestAndRecover

Repository findings: GoalSystem previously queried every living non-player actor with
`npc_goals`, but all conditions and methods required a commanded party. Residents could only
have blocked goals. Important characters already opt into personal `memory`: player/companion
templates, named resident creation, and custom important leaders/traders. The `npc` marker means
settlement/dialogue NPC; names or leadership alone do not establish importance. No new taxonomy
is added. Actual health is `hp`/`maxHp`, with the existing `stats.health` maximum fallback.
Campaign battle results apply survivor HP and casualties. There is no separate injury component.
WorldState already had player-party passive regeneration and a rest multiplier; this existing
rule is now shared by all parties instead of introducing a separate NPC healing rate.

The existing GoalSystem update builds commanded-party, roster-membership and live resident sets,
then visits each configured actor once. A living important resident in a live current-map
location's `npcs` list can evaluate independently only when absent from all live party rosters.
Roster membership wins over stale resident references. Leaders retain existing behavior,
including explicitly configured generic leaders for compatibility. Generic residents, players,
non-leader members, dead/removed actors and actors outside the active map do not execute goals.
Inactive former leaders only observe/release old owned commands. Debug `evaluationMode` records
`party leader`, `independent resident`, or `inactive` on positive updates.

`npc_goals` remains on the original actor throughout joining, leaving, party creation and
leadership changes. Existing ID/sequence attribution releases the old party's command; an eligible
actor continues with the same goal objects in its new context. No party is manufactured for a
resident. Party-dependent goals still require actual command. Acquire Gold is not renamed;
treasury, capability, visibility, Roam and Raid rules remain intact.

Choosing Rest through a goal is opt-in. Passive healing does not require a goal.
Neither generation nor injury automatically attaches goals:

```lua
local Goals = require("src.systems.goal_system")
Goals.addGoal(importantNpc, {type = "rest_and_recover"})
-- Or include this definition in an initial Goals.configure call.
```

The shared `src/systems/recovery.lua` rule exposes configurable module settings. Healing settings
previously on WorldState now live here, preserving their original defaults:

| Setting | Default | Meaning |
| --- | --- | --- |
| `injuredThreshold` | `0.6` | Begin below 60% of maximum HP |
| `recoveredThreshold` | `0.9` | Continue initiated recovery until at least 90% HP |
| `passiveHealSecondsToFull` | `300` | Passive rate is maximum HP / 300 per simulation second |
| `restHealMultiplier` | `10` | Resting multiplies the passive rate by ten |

Separate thresholds avoid repeated switching near the injury threshold. Healing adds actual HP
and clamps to maximum. Large steps can finish above 90%, never above maximum. Dead or removed
actors cannot heal. All healing consumes elapsed simulation seconds supplied by WorldState;
paused/zero-time updates grant no healing. No combat, event or money API is changed.

`Recovery.update` runs once after GoalSystem and before world activity execution. It applies
passive healing to every living member of traveling and stationed current-map parties, including
player characters, important NPCs, companions and generic troops, without requiring goals or
personal memory. The player's existing rest input and an active NPC Rest activity apply the same
rest multiplier to their respective whole parties. Party/actor encounter reservations prevent
healing. Removed actors/parties are excluded and duplicate references are deduplicated. Rest
activities only check recovery completion; they do not apply a second healing step. Goals and
activities still own decisions/movement; Recovery owns the single healing pass for both party
members and independent important residents. Independent residents receive the same passive rate
without goals, or the same 10x multiplier while their local RestAndRecover goal is active.
Roster membership takes precedence over stale resident references, and the shared per-update
actor set prevents duplicate healing across lists. WorldState captures encounter reservations
before advancing encounters; actors reserved at the beginning or during recovery cannot heal
that update, even if combat finishes and clears their reservation. They can heal next update.

Rest goals default to priority 1000. Multiple recovery goals use descending numeric priority,
with insertion order breaking ties. Needed recovery is a safety override of ordinary work even
if ordinary numeric priority is higher; ordinary selection is otherwise unchanged. Recovery
preserves unrelated goal data and cancels only its current owned activity with `recovery_required`.
Normal terminal cleanup releases movement state, and existing cooldowns apply before Rest starts.
Ordinary retry timers can elapse while resting. Ordinary execution resumes after recovery and any
remaining cooldown. There is no general preemptive scheduler or activity stack.

For a party leader, `rest` is registered in WorldActivitySystem with normal sequence,
`goalActorId`, outcome, cancellation and terminal cleanup. Its `actorId` parameter identifies the
living important NPC leader. Start saves party state and sets `rest`; cleanup restores it. The
dispatcher additionally executes Rest for stationed parties without unstationing them; movement
activities retain traveling-party requirements. Loss of actor, leader or party releases Rest.
Encounter reservations suspend recovery and interruption. Explicit activities are never claimed
or interrupted; encounter/activity cooldowns remain in force. Fallback wandering is suppressed
while recovery is required, including cleanup/cooldown gaps.

Independent residents retain only a `recovering` flag and goal status in GoalSystem; the goal
does not change HP. Recovery.update chooses the rest multiplier only for an active local rest
goal without a party activity, and uses the normal rate otherwise. No local activity framework,
timer, or scheduler is added. Healing happens once per positive update, independently of the
ordinary one-second decision cooldown. Actor-level encounter reservations block local recovery.
Ordinary work is not selected while recovery is needed. GoalSystem observes health on its next
evaluation, marks Rest satisfied at or above 90%, and allows ordinary goals to resume. Keeping
Rest installed permits later injuries to reactivate it. `cancelActivities` ends the current
attempt; remove/replace the goal to opt out of choosing Rest permanently, not passive healing.

For 7B, ProvideService can use the independent-resident evaluation path. FulfillObligation must
keep accepted assignment/progress in persistent actor-owned goal data, separate from its current
activity. Recovery cancels an attempt, never erases or satisfies an unrelated goal; future
obligation execution must reselect an appropriate activity afterward. WorldEvents IDs,
KnowledgeSystem memory and physical arrival sharing remain available without unrestricted
historical queries. Services, hiring, obligation execution, caravans, Search and investigations
are not implemented in 7A. Non-leader companions receive passive party healing and their party's
rest bonus, but do not independently interrupt their leader's movement to initiate Rest.

F1 actor inspection shows goals, priorities/status/reasons, highest unsatisfied goal (with
recovery safety precedence), last evaluation mode, recovery status and current/maximum HP. Party
inspection adds the leader's evaluation summary and each member's last recovery mode, including
generic troops. Actor inspection shows `lastRecovery` mode (`passive`, `resting`, `suspended`, or
`inactive`) and context (`party member` or `independent resident`). These are debug snapshots of
the last positive simulation update, not a timer or additional source of healing.
Existing resident/member links reach these
views. **Add RestAndRecover goal** appends an idempotent recovery goal to a living important NPC
without replacing existing goals. No new screen or injury editor was added.

Verification: all 22 scenarios ran independently with LÖVE 11.5; 19 pass, including recovery,
NPC goals, real Roam/Raid loot feedback, travel, debug, knowledge and world-clock scenarios.
`recovery_scenario` covers independent execution, generic exclusion, duplicate-leader prevention,
safety priority, actual timed healing/maxima, pause, thresholds, ordinary-goal resumption,
membership/goal identity, stale residence, stationed parties, reservations, explicit ownership,
and actor/party removal or changed command. Follow-up coverage checks passive healing for player,
generic and companion actors, traveling/stationed parties, whole-party rest bonuses, no revival,
reserved encounters, deduplication, and real WorldState pause/time integration. The combined suite passes recovery and reaches the
existing headless failure. Three previously documented combat failures remain:
`headless_battle_scenario` (4000-tick timeout), `world_encounter_scenario` (expected victory,
received timeout), and `battlefield_remains_scenario` (cargo assertion following timeout).
Combat is unchanged. `git diff --check` passes. Live gameplay/rendering remains unverified.

Manual playtest:

1. Enable F1, inspect a location, open an important resident with **Inspect NPC**, and click
   **Add RestAndRecover goal**. Inspect HP, goals, and evaluation mode.
2. In the existing Lua debugger set that actor's actual `hp` to `maxHp * 0.4`; the inspector
   does not damage actors. Hold Space to advance the world: independent HP should rise without
   creating a party. Stop advancing time and confirm HP stays fixed.
3. After 90% HP confirm satisfaction. Damage to 70% and verify Rest stays inactive while slower
   passive healing continues, then below 60% to verify another Rest starts.
4. Configure an important leader's Travel goal through the existing editor, then inspect the
   actor and append recovery. Damage the leader during travel. Owned Travel should cancel,
   movement stop, Rest start after cooldown, and Travel resume after recovery.
5. Repeat with a stationed party: it stays stationed. An explicit activity or reserved encounter
   must retain ownership while recovery waits. Change membership/leadership using existing APIs;
   goals should remain on the original actor and execute only in its eligible context.

Files changed for 7A: `src/systems/goal_system.lua`, `src/systems/recovery.lua`,
`src/systems/world_activities/rest_activity.lua`, `src/systems/world_activity_system.lua`,
`src/systems/party_ai_system.lua`, `src/debug/inspector.lua`, `src/debug/campaign_tools.lua`,
`src/ui/screens/debug_overlay.lua`, `tests/unit/recovery_scenario.lua`,
`tests/unit/npc_goals_scenario.lua`, `tests/unit/main.lua`, `tests/unit/world_time_sync_scenario.lua`,
`src/game/states/world_state.lua`, and this document.
Preexisting checkout changes are retained.

### Recovery consolidation audit before 7B

The audit found the original WorldState player-party healing loop had been fully replaced by
`Recovery.update` for parties; there was no remaining player-specific HP increment. Both party
and local resident healing already used `maximum HP / 300` with a 10x rest multiplier. The earlier
25%-per-world-day rate was absent. However, local residents still called `Recovery.advance`
from GoalSystem, whereas party members healed in Recovery.update. Residents without an active
rest goal received no passive healing, creating a discontinuity when joining/leaving parties.
Normal roster guards prevented simultaneous local/party healing in the established update order,
but retaining two update entry points was unnecessary and fragile across membership transitions.

The consolidated implementation removes the goal's healing call. `Recovery.advance` is the sole
HP calculation and is called only by Recovery.update. RestActivity only validates its owner and
checks completion. WorldState supplies one elapsed-world-time delta for all eligible current-map
owners. The single pass handles player characters, player companions/troops, NPC leaders,
important followers, generic NPC troops, stationed parties, and independent important residents.
It applies either 1x or 10x, never a passive increment plus another Rest increment. No rates or
60%/90% thresholds were rebalanced. Residents use their existing personal-memory importance
convention, need no fake party, and need no goal for passive healing. Generic residents still
have no autonomous goals; generic party members always receive the party recovery rule.

Other paths inspected: `LocationActions.rest` is a dialogue placeholder and changes no HP;
heal-skill and health-potion data declare healing amounts but have no runtime healing consumer.
CombatSystem reduces battle-unit HP. Battle initialization copies starting HP, and interactive
battle/campaign-result code writes battle outcomes back to actors. Progression increases maximum
health without restoring current HP. None of these is another passive/resting world heal source;
none was changed by this audit. No new combat healing mechanics were added.

A separate timing defect was fixed: encounter completion previously cleared reservations before
the recovery pass, letting survivors heal for time just spent in combat. A per-update reservation
snapshot now prevents that increment while allowing recovery on the next update. Current actor
and party reservations are checked as well, so resting cannot bypass them.

Focused tests now verify matching passive rates, exact 10x resting for player/whole NPC parties
and independent residents, goal evaluation without HP changes, passive healing without goals,
duplicate/stale list references, joining/leaving between decision and recovery, death/removal,
encounter suspension/resumption/completion, exact 90% satisfaction and ordinary-goal resumption,
F1 recovery modes, real WorldState pause gating and 2x clock scaling. All 22 scenarios were run
independently: 19 pass; the same three documented headless-combat-related failures remain.
Live UI/gameplay is still unverified. `git diff --check` passes.

Audit files changed: `src/systems/recovery.lua`, `src/systems/goal_system.lua`,
`src/game/states/world_state.lua`, `src/debug/inspector.lua`, `tests/unit/recovery_scenario.lua`,
`tests/unit/world_time_sync_scenario.lua`, and this document. Recovery remains scoped to the
active map and living important independent residents; non-leader members do not choose Rest
on their party's behalf. Future callers must invoke Recovery.update once per simulation step,
after goal decisions, with the same reservation snapshot when they advance encounters first.
Milestone 7B and all services/caravans/investigations remain unimplemented.


## Actual Milestone 7B: services and accepted obligations

### Ownership and boundaries

Goals answer **why** an actor acts. Capabilities answer **what** it can do. The existing
actor-owned `npc_goals.capabilities` now accepts named boolean flags (including `heal`)
without a profession registry. Switching selected goals never removes these flags.
`npc_goals.selectedGoalIndex` records the evaluator's actual selection; availability does
not infer selection from the largest configured priority. Recovery remains the safety
interruption even when another goal has a larger numeric priority.

Future capability-specific operational state belongs to a separate actor component. A future
CaravanFormation component can retain preparations, cooldown timestamps and service IDs while
the actor changes between Acquire Gold, recovery and other goals. Its configuration flag only
controls eligibility. Service assignment status stays authoritative in ServiceSystem; capability
state must not mirror the assigned worker or lifecycle status. No CaravanFormation component,
cooldown, preparation process, planner or unused generic capability-runtime framework exists in
7B. Heal is stateless and needs no such component.

Immediate services execute another actor's capability directly. Commissions persist a request,
assignment and obligation. Ordinary healing creates neither a request nor a world event.

### ServiceSystem API and current state

`src/systems/service_system.lua` uses a small context `{world = campaign, map = currentMap}`.
The world defaults to `EcsWorld.campaign`; map-dependent interactions require an explicit map.

- `findLocalProviders(customer, "heal", context)` returns eligible, affordable local actors.
- `canPerform(provider, customer, "heal", context)` returns `true` or `false, reason`.
- `perform(provider, customer, "heal", context)` revalidates, transfers payment and changes HP;
  returns `true, {serviceType, providerId, healed, price}` or `false, reason`.
- `createRequest(employer, {type, requiredCapability, locationId?, data?}, context)` returns a
  snapshot or `nil, reason`. Employer must be present and accessible; an optional location ID
  must match its actual location. `data` must be a plain serializable table. Arbitrary callbacks,
  entities, cycles and explicit unsupported `constraints` are rejected. Additional request-specific
  execution constraints will need validation when their actual professions are implemented.
- `getRequest(id, context)` and `listRequests(context)` return detached plain-data snapshots.
- `isAvailable(id, context)` checks the current open request and employer availability/location.
- `assign(id, worker, context)` rechecks availability, selected ProvideService, required capability,
  physical interaction, distinct employer/worker identities and conflicting accepted work.
- `complete(id, context)` accepts assigned work; `cancel(id, context, reason?)` accepts open or
  assigned work. Repeating the same terminal operation succeeds without extra events; different
  transitions from a terminal state fail.
- `learnCurrentStatus(id, worker, context)` teaches an applicant the latest announcement or
  closure only when it meets the employer at the same actual location.
- `update(context)` cancels live requests whose employer, assigned worker or location was
  removed (including pending ECS removal) or whose participant died. GoalSystem calls this
  only when elapsed world time is positive. Viewer refresh does not run lifecycle cleanup.

Current requests live in `campaign.serviceRequests`, keyed by campaign-allocated `service_*`
IDs. Completed and cancelled records are retained, so old references never resolve to another
job. Allocation additionally skips retained records if allocator state is restored independently.
Multiple requests per employer are supported. Request records contain only IDs and plain data:
`id`, `type`, `employerId`, historical `employerName`, `locationId`, `requiredCapability`, `status`,
`assignedActorId`, `data`, `offerEventId`, `filledEventId`, `closureEventId`, optional `reason`.
All assignment authority lives here; goal service IDs are references, not another assignment table.
Full service/campaign save and load remains deferred.

### Immediate healing, locality and gold

A commercial provider must be a living important actor (`memory`), actually located on the map,
with Heal and **selected active ProvideService**. Encounters, active incompatible party activities
and accepted obligations block availability. Independent residents and important stationed-party
members are found through `LocationSystem.getAvailableNpcs`. Roster membership wins over stale
resident references. Dead/removed actors, generic troops, self-service and absent actors are excluded.
A party member may offer locally without acquiring command of the party. Traveling important
followers cannot autonomously command travel. Existing generic NPC leaders retain their older
non-service goal behavior; generic troops do not independently choose service goals.

The player location screen does not station the player party. Locality therefore also accepts
its existing interaction-radius proximity for the actual player character. Remote context IDs cannot
make an actor local. Player and NPC customers call the same `perform` function. The existing NPC
conversation greeting adds **Heal my wounds (10 gold)** when the target is offering Heal; the
action displays the operation's real result, including affordability failures.

Defaults: **40 HP for 10 gold**. HP is clamped to maximum; dead or fully healed customers are
rejected. `healAmount` and `healPrice` are configurable finite values; price is a nonnegative integer.
Party members pay/receive through their actual party treasury. An independent actor uses personal
`treasury`, initialized to zero by the unit assemblage. Personal and party balances stay separate.
`InventorySystem.transferGold` debits and credits the actual owners. Shared-treasury transactions
are rejected rather than charging the same owner. No gold is generated and no stock-owner economy
is introduced. A zero-price configuration skips currency transfer while retaining eligibility checks.

### RestAndRecover integration and the inspected-checkout discrepancy

The supplied milestone described pre-existing settlement travel. Inspection found that this checkout
started RestActivity **in place**, with no nearest-settlement routing. The user explicitly authorized
adding nearest-settlement travel during 7B. This is therefore a deliberate change from the inspected
7A checkout, not a claim that an existing route was preserved unchanged.

For a recovering real party leader outside a settlement, the existing recovery handler now chooses
the nearest living town/village/castle by squared map distance and requests the existing generic
TravelActivity. Healer availability is never consulted to choose a destination. No new activity or
navigation implementation was added. Actual stationing establishes arrival. Travel failures retry
using the goal's existing world-time retry counter; with no settlement, the previous in-place Rest
fallback remains. Independent residents cannot travel without a real party and rest locally.

At a settlement, selected recovery checks local healing only when its world-time
`healingRetrySeconds` expires. Defaults: at least **20 useful HP**, an affordable complete price,
and **30 world seconds** between attempts/purchases. Useful healing is
`min(healAmount, maxHP - HP)`. No provider or insufficient money leaves ordinary resting intact.
The retry counter advances only with positive elapsed simulation time; large updates cause at most
one purchase each, without a catch-up purchase loop. RestActivity and `Recovery.update` continue
owning all passive/rest regeneration. The established 60% injury / 90% recovered thresholds,
passive rate, rest multiplier, shared party healing and encounter exclusions are unchanged.

### ProvideService, knowledge and FulfillObligation

ProvideService defaults to priority 20. While selected it offers local capabilities and may apply
for matching commissions. Remote discovery iterates only `Knowledge.getKnownEvents(actor,
world, "service_offered")`. An application needs learned **service**, **employer** and **location**
details and a matching actor capability. Existence-only or partial knowledge cannot disclose the
missing fields. Known closure outcomes prevent pursuing closed offers. Unknown remote jobs are
never discovered by scanning the registry. A known remote offer requests existing TravelActivity
only for the actor's actual commanded party with Travel capability. An independent resident remains
local with reason `independent_resident_cannot_travel`; there is no fake party or population rewrite.
An outdated applicant can still travel, then learns current filled/cancelled/completed status on
contact and fails assignment safely. Existing arrival knowledge exchange can also share these events.

Creating a request records immutable `service_offered`; assignment records `service_filled`;
cancellation and completion record `service_cancelled` and `service_completed`. Events contain
IDs, historical names, location, service type/capability and lifecycle outcome, with campaign time.
ServiceSystem source keys prevent duplicate history. Direct participants learn the event through
KnowledgeSystem; unrelated distant NPCs receive nothing automatically. Projections separately
allowlist `time`, `location`, `employer`, `service`, `outcome`. F2 formats readable service history;
knowledge text uses only filtered views. Original offer events remain unchanged after closure.

Successful commissioning appends actor-owned FulfillObligation (default priority 80) referencing
the service ID and immediately selects it. The underlying ProvideService goal and capabilities
remain intact. Unrelated hiring is blocked while the registry has an accepted assignment. Rest can
supersede the obligation without deleting it. No profession executor exists in 7B: the obligation
holds with `awaiting_service_execution` until the API completes/cancels the request. Missing or
otherwise invalid assignments satisfy the reference goal safely. Closure resolves the matching
goal immediately; ProvideService can resume on the next evaluation. Goal replacement is rejected
while work is accepted, including a readable F1 editor error. This goal is never a World Activity.

### F1, F2 and F3 controls

F1's existing inspector now displays capabilities, actual selected goal, commercial availability,
obligation service ID, owned requests with status/worker IDs, and recent service/healing results.
Inspect an important NPC and choose **Add Heal / ProvideService** to enable a local provider for
playtesting; **Add RestAndRecover goal** remains available. These append goals without replacing
capabilities or actor runtime state. Advance world time to evaluate selection.

F2 retains historical event selection/scrolling and adds readable service summaries. F3 opens a
read-only **Global Service Viewer** using the same full-screen two-panel pattern:

- F3 again, Escape or Close closes it; F2 switches to history and F3 switches back.
- Tab (or the left header) switches Requests / Providers.
- 1 All, 2 Open, 3 Assigned, 4 Closed filter requests; Closed includes completed and cancelled.
- R (or the right header) refreshes current snapshots. Opening also refreshes.
- Click a row to select it; wheel over either pane scrolls that pane.
- Request rows show ID/type/status, employer/location, capability and worker. Details include
  current IDs, offer/filled/closure event IDs and complete plain request data.
- Provider rows show actor name/ID, actual location, selected goal, Heal capability, price and
  amount; details include the full relevant capability flags.

Both full-screen viewers pause world updates and consume gameplay keys, mouse and wheel input,
matching the F1 modal pause rule. They do not change service assignments. F3 derives providers on
opening/refresh and renders only visible rows. There is no persistent provider registry or per-draw
provider scan. Its unrestricted campaign view is solely a developer tool, unavailable to NPC decisions.

### Verification and playtest fixture

`tests/unit/services_scenario.lua` is registered in the existing runner. Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' tests/unit services_scenario
& 'C:\Program Files\LOVE\love.exe' tests/unit services_scenario --preview
```

The interactive preview creates 16 plain test commissions (open, assigned, completed, cancelled)
and a local healer; it executes no invented profession. Use F1/F2/F3, Tab, filters, selection and
wheel scrolling. Closing the preview window exits. The automatic scenario demonstrates learned
offer -> ProvideService application -> FulfillObligation -> completion/cancellation -> resumption,
plus remote stale offers, real healing/payment, recovery travel, missing participants and viewer
input/pause/rendering. Set `GEHERRA_SERVICE_SNAPSHOTS` to an existing output folder to render
Requests, Providers and empty views at 800x600, 1024x768 and 1280x720.

In a normal campaign, F1-inspect an important resident or stationed important NPC, enable Heal /
ProvideService and recovery, then advance time. Injure/fund a separate customer through the
existing debugger, watch it arrive/rest/buy healing, and compare actual HP/treasuries in F1.
Enter the provider's location and conversation to buy the same healing for the player. Verify
that an injured provider disappears from F3 while recovery is selected and reappears after recovery.

The following 7C implementation extends this service foundation. Investigation and search remain deferred.

## Milestone 7C: autonomous caravan sponsorship

### Capability, runtime ownership and scheduling

`npc_goals.capabilities.caravanFormation` enables sponsorship through the existing `acquire_gold`
goal. Important living NPCs can sponsor from a town, village or castle if the real funds owner has
500 gold. Independent residents use personal `treasury`; party members use their party treasury.
The goal condition now also checks personal funds for residents. Existing raiders retain Roam/Raid;
an actor with both capabilities can fall back to Raid if sponsorship cannot start.

The optional actor component `caravan_formation` owns:

```lua
nextSponsorshipAt = 0 -- absolute world-simulation seconds
preparation = { -- absent when none is active
    id = "preparation_1", startedAt = 4, readyAt = 52,
    originLocationId = "location_1", destinationLocationId = "location_2",
    investment = 500, leaderServiceId = "service_1",
    nextRecruitmentAt = 6 -- bounded local checks
}
expeditionServiceIds = {} -- references to dispatched services, not assignment copies
lastPreparation = nil -- most recently dispatched/cancelled preparation for inspection
```

All payloads use stable IDs and plain data. Concord's existing component serialization strips its
internal entity/class references. Runtime is separate from `npc_goals`, so replacing/selecting goals,
injury or recovery cannot erase preparation or cooldown. There is no general capability framework.

`CaravanSystem.begin` creates a preparation and one generic request, without creating a party or
debiting money. It chooses the first suitable settlement with outbound and return navigation paths.
Defaults are configurable module fields: investment **500**, preparation **3 days**, sponsorship
cooldown **30 days**, trading **6 hours**, profit rate **25%**, local recruitment interval **2 world
simulation seconds**. The cooldown begins with preparation and is never changed by dispatch,
completion or cancellation. Only one preparation is active, but dispatched expeditions do not block
a later preparation. No active-caravan cap exists.

`CampaignRuntime.updateGoals` invokes service cleanup and `CaravanSystem.update` once for positive elapsed
campaign simulation time. The latter processes existing preparations regardless of selected goals
or currently enabled capabilities. Readiness is an absolute world-clock deadline. A ready preparation
without a leader waits indefinitely. Insufficient dispatch funds leave the same preparation/request
recoverable with a visible reason; restoring funds permits retry. Closed requests retire preparation
without resetting the cooldown.

The established clock uses **16 simulation seconds per world day**. All caravan deadlines use
`TimeSystem.worldHoursToSeconds((day - 1) * 24 + hour)`, and durations use the same conversion.
This is the existing movement/scheduling unit, not a second clock. Paused campaign updates pass no
positive elapsed time, so neither preparation processing nor trading occurs while paused. The normal
goal evaluator's existing evaluation/retry interval can add a small scheduling delay after eligibility.

### Recruitment and actor transitions

Requests use type `lead_caravan`, capability `leadCaravan`, the sponsor/location IDs, and plain
`data` containing `preparationId`, `destinationLocationId`, `plannedDepartureAt`. `ServiceSystem`
remains authoritative for status, assigned actor and immutable offered/filled/closure events. Multiple
requests per employer remain supported. Requests gain `data.caravanPartyId` only after dispatch.

Sponsors periodically enumerate `LocationSystem.getAvailableNpcs` at their actual origin and call
`ServiceSystem.assign`. Proactive ProvideService uses its unchanged learned-offer path and calls
the same operation. Assignment requires selected active ProvideService, capability, accessible local
presence, no obligation and the existing availability/ownership checks. F3 is never an NPC discovery
source. Assignment immediately creates/selects FulfillObligation (priority 80); it waits for dispatch.

For NPC workers, 7C supports **independent important residents only**. Members/leaders of existing
parties are rejected at assignment, rather than taking over or silently disbanding those parties.
On dispatch, the exact actor leaves the resident roster and joins a new campaign-allocated party
through LocationSystem/PartySystem. HP, inventory, equipment, goals and memory stay on that actor.
The party is stationed at origin before Travel unstations it. No leader or party is cloned.

### Player volunteering and control

The existing greeting dialogue adds an explicit option when the player leads the actual
`GameContext` player party, is local to the sponsor, has no conflicting service, and physical dispatch
can succeed. It can be used immediately, before the preparation deadline, with or without an NPC hire.
Preflight checks are repeated on click. The existing player party becomes the expedition; no second
player party, actor or inventory is created. Its shared treasury participates in the expedition,
including any pre-existing gold: the dialogue explicitly states that **all remaining gold is delivered
on return**. There is no partitioned wallet or reimbursement of stolen capital.

After fallible physical dispatch succeeds, `ServiceSystem.volunteer` cancels the original request
with `player_volunteered`, resolving the displaced NPC's obligation, then offers/assigns a replacement
request for the player. The original offer and assignment remain historical facts. Preparation and
player work point to the replacement ID. Player capability/ProvideService checks are intentionally
replaced by explicit volunteering and actual player-party leadership checks; NPC hiring is unchanged.

TravelActivity already supports explicit travel for the player party. Its accepted player service is
executed from the positive-time caravan update because the generic NPC evaluator deliberately excludes
players. Travel owns movement normally; during trading/delivery, holding Space advances time. Manual
movement after stationing releases stationed membership through `Map:addParty`. Completion restores
normal player map membership and its prior trader flag, preserving GameContext identity/control.

### Dispatch, activity ownership and finances

Dispatch revalidates living participants, authoritative service assignment, local origin, compatible
ownership, available funds and both navigation routes. A new NPC party starts with zero treasury.
`InventorySystem.transferGold` debits the actual sponsor owner and credits the physical expedition
exactly once. Travel is prepared before payment. A failed Travel start refunds only that uncommitted
transfer, restores original resident/player membership and trader flags, and removes any newly created
party. Failed attempts may consume monotonic IDs, which are never reused.

`isTraderParty = true` reuses RaidActivity's existing trader-target classification. There is no special
caravan raid, combat or loot policy: generic encounters, casualties, shared treasury plunder and
remains retain authority. Once dispatched, loss never refunds sponsorship.

The worker's `caravan_work` component stores `serviceId`, `partyId`, `sponsorId`, origin/destination
IDs, `phase`, expected/departure times, investment, player flag and owned activity sequence. It stores
no duplicate hiring status. FulfillObligation drives `outbound -> trading -> returning -> delivery`.
Each travel start records normal goal/activity ownership. Only the matching Travel sequence with
`completed/arrived` and actual physical stationing advances an arrival phase. Cancelled or externally
owned travel cannot substitute for an arrival. No parallel movement system exists.

Encounters reserve the existing party and suspend normal activity progression. Recovery keeps its
priority and cancels only the goal's owned activity. The service/work survives; execution resumes its
actual phase after recovery. If recovery or player input moves the party during trading, it must
travel back to the destination before restarting that unperformed trading phase. External activities
are never replaced. No duplicate travel starts occur while a party is busy.

At the destination, after six world hours, trading adds `floor(actualTreasury * 0.25)` once and moves
the phase to returning. `caravan_traded` records that distinct gain; the worker learns it locally.
No investment is recreated. For example, 500 invested, 100 stolen before trade, then 25% profit
produces **500 deliverable gold** (400 surviving capital + 100 gain). Theft after trade also stays lost.

Delivery requires successful return Travel, stationing/proximity at origin, a living sponsor still
physically there, and a distinct valid current funds owner. The whole surviving treasury transfers
through InventorySystem. The service completes and resolves FulfillObligation. A sole NPC leader
with empty party cargo returns to the origin resident list, and the empty caravan party is removed.
Unexpected cargo/additional members cause the party to remain valid and stationed instead of deleting
their resources. Completed/failed plain work snapshots remain in `actor.lastCaravanWork`.

If the sponsor dies, disappears or moves, a surviving caravan waits at origin in `delivery`, retaining
funds and its accepted obligation with `awaiting_sponsor_at_origin`. It can deliver if the sponsor
becomes available there again. There is no pursuit, estate, alternate recipient or automatic refund.
If leader/party disappears, dies, disbands, loses command or the service closes, work terminates and
the service cancels. Only the worker's own activity can be stopped. Living surviving parties/resources
are retained; encounter lifecycle handles eliminated parties and loot. The sponsor's goal and cooldown
are untouched.

### Return estimates, history and knowledge

Expected return is `departureAt + (outboundEstimate + returnEstimate) * 1.20 + tradingDuration`.
Each estimate uses existing `WorldNavigation.findPath`, TravelActivity speed and four-unit terrain
samples along its waypoints; both directions are estimated independently. No route knowledge is added.
It is an estimate: encounters, recovery, retries and waiting for a relocated sponsor can delay return.

Dispatch temporarily supplies sponsorship metadata to the existing `TravelKnowledge.depart` path.
Its single `party_departed` record contains caravan party, sponsor ID/name, preparation, origin,
destination, departure time and expected return. A `sponsorship` knowledge category allowlists these
fields. The sponsor learns that event directly as an organizer. Ordinary travel is unchanged; genuine
later arrivals/departures use the existing Travel callbacks. No successful return is pre-recorded.

The sponsor does not automatically learn remote trade, battles, loss, position or arrivals. Existing
arrival conversation/witness knowledge can communicate facts normally. In particular, dispatched
service cancellation no longer automatically teaches a remote employer its closure: the authoritative
terminal service and F3 developer view may know a loss before the sponsor does. Pending recruitment
still uses normal direct-participant service knowledge. No overdue detection or investigation exists.

### Developer tools and verification

F1 shows capability flags, preparation start/ready times, cooldown remaining, destination, investment,
service/prospective worker, dispatched party, phase, expected return and obligation status. Existing
NPC inspectors add **Enable CaravanFormation / Acquire Gold** and **Enable LeadCaravan /
ProvideService** buttons. They grant capabilities/append goals without changing funds or preparation.
The existing goal editor also exposes both flags through its registry. Actors show personal treasury;
the existing party inspector shows shared treasury. F1 inspection is live; its editors pause the world.

F2 formats `caravan_traded` and expected return on departures; its existing plain-data details show
all optional metadata. F3 already renders generic request fields/data, including preparation and party
references, and needs no separate caravan registry or viewer. It remains read-only and pauses updates.

`tests/unit/caravan_scenario.lua` extends the existing scenario runner with timing/pause, goal changes,
late recruitment, duplicate assignment, independent leader identity, player override through real
dialogue, funding/rollback, overlapping expeditions, navigation estimates, owned Travel, trade once,
loss-adjusted returns, recovery, unavailable sponsor, generic raid targeting/loot and knowledge tests.
It also renders real F1/F3 views. See `docs/MILESTONE_7C_REPORT.md` for results and manual steps.

Limitations deliberately retained: independent NPC hires, first reachable settlement selection,
shared player expedition treasury, waiting at fixed origin for unavailable sponsors, and no generated
escorts/wages/markets. Full save/load is not implemented. Future investigation may compare a learned
departure's expected return with sponsor knowledge; 7C adds no SearchActivity, AcquireKnowledge,
investigations, rescue/fleeing, faction, economy or planner framework.
