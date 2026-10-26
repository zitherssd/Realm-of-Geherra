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
- NPC knowledge or world-event history
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
  `WorldState.update` calls it after world encounters advance and before fallback movement and
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
  Partyless actors remain valid: their goals become blocked without creating a party. Missing or
  destroyed parties cannot satisfy goals and are never recreated.
- Evaluation occurs once per world-simulation second per actor, or on an observed terminal
  outcome. Higher priorities are considered first; insertion order breaks ties. An infeasible
  goal permits consideration of a lower-priority goal. Active work is never preempted merely
  because priorities change.
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
without recursive planning, escalating backoff or priority preemption. Full campaign save/load is
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
