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
