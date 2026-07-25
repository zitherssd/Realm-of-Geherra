# NPC Data System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: A Living, Persistent World, Meaningful Progression

## Overview

The NPC Data System defines every non-player character in the game — their identity, role, appearance, dialogue, services, and recruitment conditions. NPCs are data-driven: each NPC is a record with fields for name, faction, role, appearance sprite, location, services offered, dialogue pool, and recruitable conditions. Name pools are faction-specific (Pelasgian names, Egyptian names, etc.) to reinforce cultural identity. NPCs can offer services (Trade, Heal, Repair), dialogue (with role-specific language), or recruitment (with varying conditions from simple gold to complex quest requirements).

## Player Fantasy

NPCs make the world feel alive. A barbarian speaks with blunt directness and might join your party for coin. A Pelasgian elder speaks of the old ways and offers quests tied to the forest. A necromancer speaks in riddles and can raise skeleton allies — for a price. The player learns who to talk to for what: traders for goods, elders for quests, barbarians for muscle, witches for magic. Each NPC feels like a person, not a menu.

## Detailed Design

### Core Rules

1. **NPC definition structure**: Each NPC is defined as a record with the following fields:
   ```lua
   {
       id = "npc_pelasgian_elder_01",
       name = "Brogar",
       faction = "pelasgian",
       role = "elder",
       sprite = "npc_elder_pelasgian_01",
       location = "town_pelasgian_1",
       services = {"quest_giver", "dialogue"},
       dialogue_pool = "elders",         -- which dialogue set to use
       recruitable = false,
       -- for recruitable NPCs:
       recruitment = nil,                 -- nil if not recruitable
   }
   ```

2. **NPC roles** (MVP):
   - `elder` — Quest giver, lore dialogue. Found in settlements.
   - `trader` — Buy/sell goods. Subtypes: general, blacksmith, fisher based on settlement type.
   - `blacksmith` — Trade, repair, upgrade equipment.
   - `tavern_keeper` — Dialogue, rumors, recruitment leads.
   - `hunter` — Quest giver (hunt beasts), trade pelts.
   - `lord` — Quest giver (faction quests), reputation dialogue.
   - `guard` — Dialogue, patrol information.
   - `druid` — Dialogue, herbal trade, nature-related services.
   - `witch` — Dialogue, magical services, potion trade.
   - `wizard` — Dialogue, magical services, gem trade.
   - `necromancer` — Unique services (raise skeletons), requires rare items.
   - `barbarian` — Recruitable (coin), combat dialogue.
   - `tracker` — Recruitable (reputation + coin), wilderness dialogue.
   - `assassin` — Recruitable (complex conditions), shadowy dialogue.
   - `villager` — Ambient dialogue only. No services.

3. **Faction name pools**: Each faction has a separate name pool in `data/name_pools.lua`:
   ```lua
   -- Pelasgian names (Indo-European/Dacian flavor)
   pelasgian_male = {"Brogar", "Dacian", "Alaric", "Burebista", "Comatzi", "Gaete"},
   pelasgian_female = {"Zora", "Briseis", "Rada", "Vela", "Dacia"},

   -- Mycenaean names (Aegean/Greek flavor)
   mycenaean_male = {"Agamemnon", "Nestor", "Idomeneus", "Menelaus", "Eteocles"},
   mycenaean_female = {"Clytemnestra", "Helen", "Andromache", "Cassandra", "Electra"},

   -- Egyptian names (Middle Eastern flavor)
   egyptian_male = {"Narmer", "Menes", "Horapollo", "Serket", "Khemet"},
   egyptian_female = {"Neith", "Merit", "Hathor", "Bastet", "Seshat"},
   ```

4. **Recruitment conditions**: The `recruitment` field defines how an NPC can join the party:
   ```lua
   -- Easy: barbarian joins for coin
   recruitment = { type = "gold", amount = 500 }

   -- Reputation-gated: requires faction standing
   recruitment = { type = "reputation", faction = "pelasgian", min_standing = 30, gold = 200 }

   -- Complex: requires item + reputation
   recruitment = { type = "item_and_reputation", item = "death_stone", faction = "neutral", min_standing = 20 }

   -- Quest-gated: complete a specific quest first
   recruitment = { type = "quest", quest_template = "free_the_tracker" }
   ```

5. **Dialogue pools**: NPCs reference a `dialogue_pool` that determines their speaking style and available topics. Example pools:
   - `elders` — Formal, lore-heavy, quest offers
   - `traders` — Transactional, price talk, market rumours
   - `barbarians` — Blunt, short sentences, combat talk
   - `hunters` — Practical, wilderness knowledge, beast lore
   - `necromancers` — Cryptic, death-themed, unique service offers
   - `villagers` — Simple, daily life, rumours

   The Dialogue System (S31) handles the actual conversation flow. This system only stores which pool the NPC uses.

6. **Services**: NPCs can offer zero or more services from:
   - `dialogue` — Talk to the NPC (always available)
   - `trade` — Buy/sell goods
   - `quest_giver` — Offers available quests
   - `heal` — Restore HP for gold
   - `repair` — Fix equipment for gold
   - `recruit` — Can join the party (if `recruitable = true`)
   - `unique` — Custom service (necromancer raising skeletons, etc.)

### States and Transitions

| State | Description |
|-------|-------------|
| **Active** | NPC is alive and at their assigned location. Available for interaction. |
| **Recruited** | NPC has joined the player's party. Removed from location. |
| **Dead** | NPC has been killed. Removed from location permanently. |
| **Departed** | NPC has left (story reasons). Removed from location. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S08 Location/Town System | Consumed by | Locations reference NPC IDs to populate scenes |
| S31 Dialogue System | Provides | `npc.dialogue_pool`, `npc.role`, `npc.name` for dialogue context |
| S27 Economy/Trading | Provides | `npc.services` includes "trade" → NPC has a trade inventory |
| S28 NPC Recruitment | Consumed by | `npc.recruitment` defines conditions for joining party |
| S05 World Generation | Consumed by | NPC faction assignment links to world faction data |

## Formulas

No mathematical formulas. NPC data is declarative.

## Edge Cases

- **If an NPC's location is destroyed or removed**: The NPC is reassigned to the nearest settlement of the same faction. If none exists, the NPC is flagged as `departed`.
- **If a recruitable NPC is killed before recruitment**: The NPC is permanently lost. Another NPC of the same role may appear later (replacement logic).
- **If an NPC's name conflicts with another (same name, same location)**: A numeral suffix is added (e.g., "Brogar the Younger"). Prevented by unique NPC IDs.
- **If an NPC's sprite file is missing**: A placeholder silhouette is used. A warning is logged.
- **If a recruited NPC dies in combat**: The NPC transitions to Dead state. Their equipment is recoverable from their body.
- **At 800×600 resolution**: NPC sprites use the same pixel art scaled to fit.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S08 Location/Town System | Hard | Locations provide NPC ID lists for population |
| S05 World Generation | Hard | Faction assignment aligns with world faction data |

**Depended on by:** S08 Location/Town System, S31 Dialogue System, S28 NPC Recruitment, S27 Economy/Trading.

## Tuning Knobs

- **Name pools**: All names in `data/name_pools.lua` are data-driven. Add/remove names freely.
- **Recruitment gold costs**: Integer. Per-NPC configurable. Range: 0–5000.
- **Recruitment reputation thresholds**: Integer 0–100. Per-faction configurable.
- **NPC service lists**: Per-role configurable. Add/remove services from any NPC role.

## Visual/Audio Requirements

- **NPC sprites**: Each NPC has a unique sprite (32×48px standing, matching unit sprite scale). Sprites are faction-specific (clothing, colour palette). Sprites are stored in `assets/sprites/npcs/`.
- **Portrait art**: A smaller portrait (64×64px) for dialogue screens. May be extracted from the full sprite or drawn separately.
- **Audio**: No unique audio per NPC. NPCs use generic voice/grunt sounds from the Audio/Music System.

## UI Requirements

- **NPC interaction screen**: When interacting with an NPC, the UI shows:
  - NPC portrait (left)
  - NPC name + role (top)
  - Available interaction options (buttons): Talk, Trade (if vendor), Recruit (if recruitable), etc.
  - Dialogue text area
- **Recruitment confirmation**: A prompt showing the NPC's class, stats, and recruitment cost/conditions before confirming.

## Acceptance Criteria

- **GIVEN** an NPC ID, **WHEN** the NPC data is loaded, **THEN** all fields (name, faction, role, location, services) are valid.
- **GIVEN** an NPC with `recruitable = true` and valid recruitment conditions, **WHEN** the player meets those conditions, **THEN** the NPC can be recruited.
- **GIVEN** an NPC with `recruitable = true`, **WHEN** the player does not meet the conditions, **THEN** the NPC cannot be recruited and may indicate what's needed.
- **GIVEN** a Pelasgian NPC, **WHEN** their name is generated, **THEN** it comes from the Pelasgian name pool.
- **GIVEN** an NPC role of "trader", **WHEN** the NPC is interacted with, **THEN** the Trade option is available.
- **GIVEN** an NPC role of "villager", **WHEN** the NPC is interacted with, **THEN** only Talk is available (no Trade).
- **GIVEN** a recruitable NPC joins the party, **WHEN** they are recruited, **THEN** they are removed from their location's NPC list.

## Open Questions

- **NPC schedule**: Should NPCs have daily schedules (e.g., trader is at stall during day, at home at night)? Adds depth but complexity. Proposed: deferred from MVP — NPCs are always available at their assigned location.
- **Unique NPC sprites**: Each recruitable NPC having a unique sprite is a significant art cost. For MVP, could some share a base sprite with a colour tint/accessory swap? Decision deferred to art production.
