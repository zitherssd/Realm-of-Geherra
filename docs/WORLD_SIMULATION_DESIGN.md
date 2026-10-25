# Realms of Geherra — World Simulation Design

**Status:** Agreed design direction / living document  
**Scope:** World simulation, NPC autonomy, emergent adventures, and procedural quests  
**Updated:** 2026-10-25

## 1. Vision

Realms of Geherra is a world in which characters and factions pursue interests of their own. The player is an inhabitant and participant, **not the reason events happen**. Procedurally generated initial circumstances, autonomous behavior, and persistent consequences should produce adventures whether or not the player intervenes.

**Core loop:**

> Generated circumstances → needs and goals → decisions → local actions / world activities → simulated outcomes → persistent world facts → NPC knowledge and reactions → revised goals and player opportunities → repeat.

A quest is normally a player's opportunity to help, oppose, exploit, or investigate an existing situation. It should not normally be the mechanism that creates that situation.

## 2. Non-negotiable design principles

1. **Generate initial conditions, not scripted destinies.** Templates establish coherent geography, locations, factions, characters, resources, relationships, and situations; simulation determines their future.
2. **Prefer reusable motivations and actions over archetype scripts.** A minotaur and a merchant can both seek wealth, but differ in methods, capabilities, personality, knowledge, and constraints.
3. **Simulate consequential actions physically; routine work abstractly.** Physical world parties matter when their position, timing, exposure, or interruption produces meaningful gameplay. Otherwise use time-based local processes and aggregate results.
4. **Resources have real ownership.** An inventory or treasury belongs to one authoritative actor, party, shop, or other appropriate stock owner. Transfer, theft, consumption, and production affect actual state without duplication.
5. **World facts are not NPC knowledge.** An event can occur without distant NPCs instantly learning of it. Knowledge is acquired through observation, delayed expectations, reports, investigation, or later rumors.
6. **NPCs act with incomplete information.** They choose methods based on what they reasonably know, not the engine's omniscient state.
7. **Outcomes matter and persist.** Goods change hands, casualties produce corpses, battlefields can be discovered, parties disappear, and goals may become obsolete or urgent.
8. **The world continues without the player, within the established clock model.** While simulation time advances, NPCs may act and create consequences. When world time is paused, simulation progression stops; UI and input stay responsive.
9. **Keep scope bounded.** Do not build a detailed economy, ecology, social simulation, planner, or full physical population merely to justify one quest.
10. **Build vertical causal slices.** Prove a goal drives an activity and responds to its real outcome before adding many goal types, professions, activities, and economy rules.

## 3. Simulation layers and their boundaries

### 3.1 Initial world generation

Use coherent, lightly randomized **templates**:

- **NPC archetypes**: likely goals, roles, capabilities, personal traits, and starting possessions. Separate species, profession, social position, and personality; none alone dictates behavior.
- **Location templates**: villages, fortresses, ruins, shrines, markets, groves, caves, and their plausible infrastructure and resources.
- **Situation templates**: a minotaur clan holds a fortress; a merchant partnership depends on a route; a druid protects a grove; a wizard seeks an artifact; a village faces a deliberate shortage.

Generation should validate basic coherence: viable locations and activities need plausible resources or access to them, while intentional scarcity is a valid authored initial situation. Templates set up the **starting state**, not a mandatory chain of quests or eventual outcomes.

**Boundary:** Initial generation is not part of the next NPC-goals milestone. Existing travel/road generation limitations remain deferred.

### 3.2 Major NPCs versus minor population

- **Major characters** are persistent individuals with identities, personal goals, relationships, knowledge, possessions, and meaningful choices. Examples: elder, merchant sponsor, blacksmith of interest, priest, druid, minotaur leader, necromancer, fort holder, faction leader, named companion.
- **Minor population** may be represented in aggregate when their individual decisions do not matter. Farms, workshops, woodcutting and similar production need not instantiate every worker as a fully autonomous person.
- A minor character can become a persistent individual when needed by a significant event or interaction; avoid retroactively creating duplicates.
- Animals and simple creatures may use simpler needs/decision logic while sharing world mechanics where appropriate.

### 3.3 Goals, requirements, methods, execution

Keep the following conceptually distinct:

| Concept | Question | Example |
| --- | --- | --- |
| **Goal** | What world state do I want? | Accumulate wealth; protect a grove; find a missing caravan |
| **Requirement / need** | What is missing or blocking it? | Need charcoal to forge equipment |
| **Decision / method** | Which feasible action should I try? | Buy charcoal, request help, gather it |
| **Activity / local process** | How is it performed? | Travel, raid, gather, produce, heal |
| **Outcome** | What actually happened? | Cargo stolen; party defeated; shipment arrived |
| **Reaction** | What changes in my priorities or beliefs? | Pursue a different source; investigate a loss |

A goal is not a sequence of scripted tasks. A small priority-based evaluator is preferable initially to full GOAP, recursive planning, or a complex behavior tree. Re-evaluate at suitable **world-time** intervals or meaningful outcome triggers, not every render frame. Protect active activity ownership, encounter reservations and existing cooldowns; prevent decision thrashing and repeated failed actions.

Start with broadly reusable goal families, expanding only when gameplay requires them:

- Acquire resources / wealth
- Protect a person, group, possession, or place
- Maintain wellbeing and safety
- Investigate / acquire knowledge
- Fulfill obligation or provide a service
- Preserve / restore / heal
- Gain power or influence / control territory
- Build relationships / gain followers
- Seek justice / revenge / restitution
- Explore, avoid, escape, or seek solitude

These are **design families**, not a requirement to implement all goal classes now.

### 3.4 Action execution: local vs. world

**Local abstract processes:** crafting, healing, researching, farming, charcoal production, ritual preparation, ordinary shop activity. They advance through world time, resource transactions and requirements; they need not produce mobile parties.

**Physical World Activities:** Travel, Raid, Patrol, Hunt, Escort, Gather at a remote site, recover remains, deliver cargo. These use actual parties, location and visibility rules, movement, encounters, and resource changes. Activities describe **how**, never hardcode why a character chose them. One controller owns party movement at a time.

Some goals may request help instead of acting directly. Assistance can create NPC contracts or **player-facing quest opportunities**.

### 3.5 Minimal resource economy, not full economics

Use existing authoritative inventories/treasuries and introduce new systems only when needed:

1. **Stocks:** available wood, charcoal, iron, herbs, food, goods, gold, etc., owned by appropriate entities.
2. **Processes / recipes:** inputs + time + requirements → outputs (e.g., wood → charcoal; iron + charcoal → weapon).
3. **Demands:** shortages arise from an actual production goal, consumption, or contract, not arbitrary quest flags.
4. **Transportation:** when goods move between locations, an actual party can carry and lose them.
5. **Threshold events:** significant changes, such as stock shortages, interrupted production or missed shipments, can trigger reactions.

A forest can have abstract renewable timber stock; woodcutting reduces it. No need to simulate each tree or individual worker. More complex economics—prices, finite shop funds, market clearing, ecology, logistics—are optional later additions, not prerequisites for the first goals milestone.

### 3.6 Persistent world facts, knowledge, and reactions

- **World facts** record meaningful objective changes using stable IDs, times, participants and relevant location/resource references. EventBus notifications alone are transient and do not constitute history.
- **Knowledge** records what a specific character or faction has learned, when and from whom; facts may be incomplete or mistaken in future designs.
- **Reactions** create or reprioritize goals in response to knowledge and circumstances rather than instantly creating a quest on every event.
- **Quest opportunities** are agreements/offers derived from unresolved goals and real facts; acceptance does not need to spawn the target. Existing player discoveries or earlier actions should be reconcilable with a newly accepted quest.

Illustration: a caravan's **traveler** dies in a raid, but its separate **sponsor** at a location first knows only that it is overdue. On receiving evidence, the sponsor can change from `investigate` to `recover_property` or `seek_justice`.

## 4. Authoritative ownership and identity

- **Actor:** persistent individual, personal items/equipment, dialogue identity, relationships, knowledge and personal goals.
- **Party:** persistent organized group, leader and roster, shared traveling inventory/treasury, one active movement-owning World Activity.
- **Location:** persistent place containing independent residents and a single `stationedParties` collection; available NPCs are derived without duplicating actor entities.
- **Stationary stock owner:** shop, workshop, institution or location store, as appropriate; do not assume every shop's inventory is the shopkeeper's personal belongings.
- **Faction:** collective affiliation and, eventually, collective interests/authority; do not confuse with actor reputation storage.
- **ID references:** stable campaign-scoped IDs for long-lived relationships; safe lookup of destroyed entities. Historical facts retain identities even after the entity is gone.

An NPC's dialogue identity persists whether encountered on the road as a party leader or at a location. A party may be stationed without disbanding; actor personal possessions follow the actor, shared cargo follows the party.

## 5. Examples of emergent chains (design targets, not implemented features)

### Minotaur and merchant caravan

1. Initial world generation creates a ruined fortress, an affiliated minotaur leader, and a warband.
2. Leader seeks wealth; a decision selects Raid if feasible and known targets are available.
3. Existing raid/pursuit/encounter systems resolve the attack.
4. Real cargo changes hands; corpses and abandoned supplies create battlefield remains.
5. A separate caravan sponsor later detects an overdue journey without magically knowing who attacked it.
6. Sponsor seeks information; offers player an investigation opportunity through normal dialogue.
7. Player may investigate before accepting; reported evidence can resolve the need. Alternatively other NPCs may act and change the outcome.

### Blacksmith, charcoal and druid

1. A forge's abstract recipe requires charcoal; stocks deplete.
2. A relevant actor seeks a supply through purchase, delivery, or help.
3. If woodcutting near a protected grove becomes necessary, the druid's `protect` goal can conflict with the settlement's resource goal.
4. A confrontation can produce casualties; their corpses and history become a battlefield site.
5. A priest, necromancer, elder or player may respond for different reasons.

These examples validate *reusable systems* rather than prescribe minotaur-specific or blacksmith-specific quest code.

## 6. NPC archetypes are compositions

Species, profession, position, personality, capabilities, location, inventory and knowledge should be independently configurable. Examples:

| Archetype / role | Common starting interests (not fixed behavior) |
| --- | --- |
| Village elder | Protect residents, maintain wellbeing, investigate disappearances |
| Blacksmith | Produce equipment, obtain materials, earn livelihood |
| Witch / apothecary | Gather unusual ingredients, research, heal or trade |
| Doctor / healer | Restore health, obtain medicines, protect patients |
| Hermit mage / wizard | Acquire knowledge, protect secrets, study artifacts |
| Druid / dryad | Protect forests, groves, springs, or sacred places |
| Priest | Fulfill duty, bury the dead, protect shrines, purify disturbances |
| Necromancer | Obtain corpses, pursue forbidden knowledge, increase magical power |
| Merchant | Acquire resources, profit, fulfill contracts, preserve trade routes |
| Wandering sellsword | Find employment, honor contracts, gain wealth and allies |
| Fort holder / faction leader | Defend territory, maintain a garrison, expand influence |
| Minotaur / cyclops / ogre / troll | Guard territory, acquire food or treasure, demand tribute, avoid rivals |
| Satyr / goblin | Gather supplies, form groups, seek pleasure or wealth, bargain or raid |
| Dragon | Hoard, guard a lair, seek tribute, knowledge, or dominance |
| Ghost / spirit | Seek release, justice, remembrance, revenge, or protect a site |
| Wild dog / simple animal | Food, safety, territory, pack cohesion; simpler decision rules |

Archetype influences *initial tendencies and feasible methods*; it must not irrevocably define character behavior.

## 7. Architecture-to-code direction

Preserve and extend existing systems instead of introducing parallel alternatives:

- **Campaign ECS / `EcsWorld` / `IdAllocator`:** durable identity and references.
- **`WorldActivitySystem`:** lifecycle and exclusive movement control.
- **`TravelActivity`, `RaidActivity`:** currently implemented activity executors.
- **`WorldEncounterSystem`, combat runner, result applier:** actual NPC combat under the world clock.
- **`LootResolver`, `LootApplication`:** resource disposition and transfer.
- **`BattlefieldRemainsSystem`, visibility and dialogue:** persistent observable consequences.
- **Existing location residents + stationed parties:** consistent identity and interaction context.
- **Existing quest and dialogue modules:** future interface for opportunities; do not replace them wholesale.

**Future additions**, introduced incrementally: actor goal storage, evaluation/decision adapter, goal-to-activity outcomes, journey records, world-fact ledger, per-NPC knowledge/reactions, assistance/quest offers, selective local production and resource requirements, later faction goals and world-generation templates.

## 8. Implementation roadmap and explicit deferrals

### Next: Milestone 4A — minimal goal-driven activities

- Add simple actor-owned goal data and a small evaluator/selection boundary.
- Demonstrate that a leader's explicit goal can request an existing `RaidActivity` or `TravelActivity` without bypassing lifecycle, reservations, visibility or time rules.
- Measure success from *actual* inventory/treasury changes or travel arrival, not just activity launch.
- Prevent old default auto-Raid assignment from competing with goal-managed parties, while preserving working legacy NPC behavior where goals are absent.
- No world generation, resource production, autonomous economy, knowledge propagation, or quests.

### Later, in bounded milestones

1. Goal outcome feedback, reconsideration and failure/backoff behavior.
2. Merchant/other journey provenance, sponsor/owner relationships and expected arrivals.
3. Objective world facts and NPC-specific overdue knowledge.
4. Investigation/reactive goals and real player quest opportunities.
5. Local production/consumption, resource needs, professions and workshop stock.
6. Procedural initial templates for locations, archetypes, factions and situations.
7. Wider activities (Trade, Gather, Hunt, Escort, Patrol, burial, necromancy), richer capabilities and faction goals.

**Intentionally deferred:** TravelActivity 3.1 off-road/mixed routing and stall handling (may intersect world generation), full save/load, morale/fleeing/surrender, finite shop treasuries, full economy/ecology, large planners, and detailed minor-NPC simulation.

## 9. Success criteria

A milestone advances the vision when it creates a **testable causal chain** where state changes are explainable and persistent:

- An NPC's goal can be inspected and linked to a feasible activity it selected.
- An activity can fail, be interrupted, or succeed without claiming a fabricated outcome.
- Real resource, casualty, location or knowledge state changes affect future decisions.
- A character's death or a party's removal does not erase the context needed to understand past events.
- Other NPCs and the player can eventually respond without the world waiting for a quest to activate.
- The implementation remains small, legible, and compatible with established systems.

---

**Document maintenance:** Treat this as a design north star, not a list of features already shipped. Mark implemented vs. future capabilities accurately, and avoid silently turning illustrative examples into hard requirements.
