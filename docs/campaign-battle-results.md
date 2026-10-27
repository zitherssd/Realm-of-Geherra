# Campaign Battle Results

`CampaignBattleResultApplier.apply(result, context)` applies a completed,
serializable encounter result to the campaign. The context supplies a campaign
map with `getParties()` and `removeParty()`, the participating campaign parties
(directly or through `map:getParties()`), and the owning encounter handle. The
encounter handle must be in its `completed` state.

The applier validates both party IDs and the complete actor roster before
changing campaign state. It persists final HP, removes defeated actors through
`PartySystem`, removes only empty parties from the map, and emits
`party_killed` once per eliminated party. Draws apply their final HP and may
eliminate both parties. Timeouts apply partial casualties and HP, but require
at least one survivor in each party; a timeout alone cannot eliminate a party.
Runner results also include copied `equipment` and `itemDurability` maps per
actor. The applier persists these maps for survivors; legacy results without
them leave equipment unchanged. Defeated actors' equipment belongs to the loot
application step, which runs before casualty removal. Inventories, treasury,
and loot are not changed by the result applier.

The encounter handle carries a `resultApplied` flag to reject duplicate
application for that encounter lifecycle. The applier does not maintain a
global result registry.

`WorldEncounterSystem` owns active world-time encounters per map. It reserves
both parties with their `activeEncounterId` for the full active lifecycle;
party AI, trader travel, activities, player interactions, and shop transactions
skip reserved parties. Encounters progress only from elapsed game-hours reported
by `TimeSystem`, at a default rate of 200 combat ticks per world-hour (configurable
through `WorldEncounterSystem.combatTicksPerWorldHour`). The game clock advances
at 1.5 world-hours per real-time second by default, so a typical ~374-tick
encounter takes roughly 1.25 real-time seconds at default settings.

`WorldState` converts the returned elapsed world-hours to simulated-world
seconds using `TimeSystem.worldHoursToSeconds`. Party movement, trader travel,
Raid pursuit/lost-sight timers, activity retry timers, and passive healing use
that one simulated-seconds delta; encounter progression and encounter cooldowns
continue to use elapsed world-hours. Both deltas are zero while idle/paused,
and scale consistently with time acceleration. Player movement, camera motion,
interface timers, and interaction cooldowns continue to use real frame seconds.
World simulation also advances while resting. Trader daily travel counters catch
up across multiple in-game days if a high time scale skips over days in one
update.
The system applies completed results here, then releases reservations and cleans
up the headless simulation. Draws, timeouts, and failures receive a temporary
world-time cooldown before those parties can be engaged again.

`WorldEncounterSystem.start` remains available for explicit callers. The
`party_contact` integration requests encounters through the same lifecycle API
and does not call the headless runner directly.

Active encounters expose lightweight inspection data through
`WorldEncounterSystem.getInspectionData(map, encounterId)`. The world map draws
a crossed-swords marker and participant highlights, and hovering the marker
shows party names, active status, elapsed world-hours, and surviving unit
counts. Start and completion (including outcome, winner, casualties, duration,
and combat ticks) are written to the debug log.

Raid contact is now connected through `party_contact`: the encounter system
validates both NPC parties and their active source activity, starts one battle,
and emits start/finish notifications. The Raid activity enters an engaged phase
while reserved, then completes on a raider victory or is cancelled on defeat,
draw, timeout, or encounter error. Duplicate or stale contacts are rejected;
the normal party cooldown applies after disengagement.

`WorldActivitySystem` generically archives terminal activity type/status/reason
in `lastActivity`, resets the active activity slot to `idle`, and releases
movement ownership on its next update. Terminal activities without an encounter
cooldown receive a short retry cooldown; encounter outcomes use the existing
map-level cooldown. This prevents a failed pursuit from restarting every frame
while allowing fallback party movement.

Interactive `BattleState` remains on its existing outcome path. It has
player-specific defeat transitions, victory callbacks, favor, loot, gold, and
casualty UI data that the generic applier intentionally does not handle.

`LootResolver.resolve(partyA, partyB, battleResult, policy, randomSource)` is a
pure planning API; it does not apply transfers or remove parties. `policy` must
explicitly set `plunderAllowed` and may override `stolenProportion` (default
0.40) and `destroyedProportion` (default 0.15). Eligible cargo is divided into
stolen, destroyed, and retained item quantities; treasury gold is split only
between stolen and retained amounts. Fractional quantities use stochastic
rounding through the injected `randomSource()` function (which returns a
number in `[0, 1)`).

The serializable `LootResult` contains `combatLoot`, `plunder` allocations,
`destroyedResources`, and `retainedResources`. Combat loot is limited to
possessions of defeated actors; actor inventories are read as item-ID-to-count
maps and equipment as slot-to-item-ID maps. Party cargo remains a list of item
instances, whose metadata is copied without merging variants. The result marks
whether each party has surviving actors or is eliminated. Draws and timeouts
award no combat loot or plunder and report campaign cargo as retained. The
resolver does not roll troop drop tables; they remain a potential separate
compatibility source and are not combined with recovered possessions. NPC world
encounters use the resolver and its separate application layer; interactive
player battles remain on the existing reward path.

Equipment worn during the battle uses its final durability in recovered loot.
Equipment broken during the battle is recorded as destroyed, preserving resource
accounting without returning the broken item as loot. Headless simulation never
mutates campaign equipment before result application. Interactive battles copy
surviving player units' equipment and durability back at battle completion.

NPC world encounters now resolve and apply `LootResult` before campaign casualty
removal. Raid contacts supply an explicit plunder policy; encounters without one
use an explicit non-plunder policy. Loot application validates source inventories
and treasury accounting before mutation, credits combat loot and plunder without
merging metadata-distinct items, removes destroyed cargo, retains resources with
surviving parties, and moves retained resources from eliminated parties into
map-owned battlefield remains. Defeated actors' item stores are cleared after
their possessions are accounted for. Interactive `BattleState` is not connected
to this path and retains its prior reward behavior.

`Map.battlefieldRemains` stores primitive site records with encounter history,
world time, recoverable item/gold, and corpse identity snapshots made from actual
defeated campaign actors. `BattlefieldRemainsSystem.serialize(map)` and
`restore(map, data)` round-trip this map state. The current `Save` module remains
a stub, so these helpers are ready for save integration but do not themselves
write to a save file. Battlefield remains are discovered with the existing
party-sight radius and remain remembered after moving out of sight; current
visibility is transient and is recalculated after loading. Discovered sites use
world-map markers and the existing proximity/Enter interaction to open dialogue.
Inspect reads the authoritative remains record. Search, corpse looting, and
burial are explicitly unavailable placeholders; they do not mutate remains.
Searching supplies transfers all abandoned cargo item instances and gold to the
player party without merging variants, then clears those resources from the
site. It does not collect possessions from corpses. There is no decay,
scavenging UI, corpse looting, burial effect, or necromancy behavior yet.

Hostile parties with no assigned activity automatically start a Raid when an
eligible target exists. Raid selects the nearest traveling or locally wandering
merchant, or player party, currently detected by the raider and uses the same pursuit/contact path
for either. Detection uses `VisibilitySystem.canSee(observer, target)`, retaining
the existing asymmetric sight/profile rule. While sight is lost, Raid follows
the serializable last-known position without contacting at stale coordinates;
it abandons the target if sight is not regained within five seconds. NPC targets
are routed to `WorldEncounterSystem`; player contacts enter the existing
interactive `BattleState`, whose optional completion callback closes the Raid
lifecycle.
World activities update before fallback party AI, so active Raids own movement
and `PartyAISystem` only provides wandering when no activity is active.
