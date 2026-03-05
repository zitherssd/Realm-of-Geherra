# Procedural Quest System — Handoff Notes

Last updated: 2026-03-05

## What Is Implemented

### 1) NPC-owned quest offer state

Quest offer lifecycle is stored directly on NPC runtime data in `npc.questOfferState`:

- `status`: `none | available | accepted | cooldown`
- `offerId`, `templateId`
- `generatedDay`, `expiresDay`
- `questInstanceId`, `acceptedDay`
- `cooldownUntilDay`

Source of truth: `systems/quest_availability_system.lua`

### 2) Role-based procedural quest pools

`data/npc_quest_pools.lua` defines quest generation profiles per NPC role (`elder`, `trader`, etc):

- `rollChance`
- `offerDurationDays`
- `cooldownDays`
- `questPool`

### 3) Quest offer roll trigger

Offers are rolled when entering a location:

- Trigger point: `game/states/location_state.lua` in `enter()`
- Explicitly no re-roll on `resume()` (prevents return-from-dialogue rerolls)

### 4) Dialogue no longer generates procedural offers

Dialogue now consumes availability state and sends intent actions:

- `accept_available_quest`
- `turn_in_available_quest`

Action handling lives in `game/states/dialogue_state.lua` and forwards to:

- `QuestAvailabilitySystem.acceptOfferForNpc()`
- `QuestAvailabilitySystem.turnInQuestForNpc()`

### 5) UI indicator

Location NPC buttons show a tiny top-right red `!` when `hasOffer` is true.

Source: `ui/screens/location_screen.lua`

### 6) Role-specific NPC spawning

Settlement NPC composition by location type is data-driven in:

- `data/location_npc_spawn_rules.lua`

Applied in:

- `systems/location_population_system.lua`


## Current Behavioral Contract

1. Enter location → each NPC may roll offer from its role profile
2. If offer generated, it remains for `offerDurationDays`
3. Accepting locks NPC to that quest (`accepted`)
4. Completing + turning in moves NPC to `cooldown`
5. After cooldown, NPC can roll again on next location entry


## Important Files

- `systems/quest_availability_system.lua`
- `systems/quest_system.lua`
- `game/states/location_state.lua`
- `game/states/dialogue_state.lua`
- `ui/screens/location_screen.lua`
- `data/npc_quest_pools.lua`
- `data/location_npc_spawn_rules.lua`
- `data/dialogue.lua`


## Known Gaps / Next Work

1. Add more procedural quest templates beyond `hunt_dogs` in `data/quests.lua`.
2. Split quest pools by role + settlement type + biome (optional layered resolution).
3. Add a lightweight debug overlay showing NPC quest state (`none/available/accepted/cooldown`).
4. Add content-safe fallback dialogue variants per role when no quest is available.
5. Add optional periodic reroll event on day change (currently reroll is location-entry-driven).


## Content Backlog (Preserved Ideas)

### NPC Types to add

- Blacksmith
- Village Elder
- Druid
- Witch

### Quest Types to add

- Destroy Orc Party
- Skeletons on Battlefield
- Kill influencer (in another location)
- Kill dragon (very rare)
- Find bandit hideout
- Deliver message
- Escort important person (mage/smith/lord)
- Troll bridge
- Discover ancient ruins
- Bring healing item
- Bring death tome

### Potential generated location themes

- Ancient forge
- Ancient tomb
- Black tower
- Mausoleum
- Temple
- Broken tower
- Gallows
- Temple of life and death
- Cavern of souls
- Tower of thorns
- Giant oak
- Woodhenge
- Wolven gate
- Grove of revelry
- Grove of spirits
- Hall of ancients
- Healing spring
- Wind spire

### NPC service concepts

- Break curse
- Haruspex
- Teleport
- Dispel
- Cure disease
- Heal