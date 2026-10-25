# Campaign Architecture (Target Decisions)

This document records the agreed architecture for the campaign simulation and implemented milestones. Some later campaign systems remain future work.

## A. Actors / NPCs

- Actors are persistent individuals with stable identities.
- Actors can own personal equipment and possessions independently of any party or location.
- Relationships, reputation, dialogue identity, and future personal goals belong to the actor.
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
- Future goal evaluation selects existing World Activities.
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

- NPC goal evaluation and faction planning
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

- NPC goals, activity selection, automatic merchant departures, destination choice, and trade
  planning are not implemented. Merchants remain valid campaign actors and parties and can be
  assigned TravelActivity explicitly.
- Road travel requires locations with generated road-site IDs and a connected road route. Parties
  not stationed at a location start from their nearest road-site location; the initial connector
  is subject to normal walkability and can fail as a stalled route.
- Full save/load and campaign migration remain out of scope.

This milestone deliberately avoids a broad ECS restructuring and preserves existing Raid, battle,
inventory, and location membership behavior.
