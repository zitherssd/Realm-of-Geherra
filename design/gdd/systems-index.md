# Systems Index: Geherra Realms — Warband

*Created: 2026-07-25*
*Status: Draft*
*Design Order: Defined below*

---

## System Enumeration

### Foundation Layer (zero dependencies)

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S01 | Input System 💡 | Foundation | Keyboard/mouse + gamepad input handling. Wraps LÖVE callbacks for uniform access. | Implicit |
| S02 | Save/Load System 💡 | Foundation | Game state serialization and persistence. | Implicit |
| S03 | Audio/Music System 💡 | Foundation | SFX playback, ambient music, combat music triggers. | Implicit |
| S04 | Main Menu System 💡 | Foundation | Title screen, new game, load game, settings. | Implicit |

### World Layer

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S05 | Procedural World Generation 💡 | World | Seeded multi-stage world creation: terrain mask, site placement, Voronoi biomes, road network. Hybrid: procedural layout + hand-crafted location templates. | Explicit |
| S06 | Biome System 💡 | World | Biome definitions with traversal modifiers (speed cost), visual palette, and encounter tables. | Explicit |
| S07 | Time System 💡 | World | Day/night cycle (16s real-time), game-day tracking, time-dependent effects on visibility and encounters. | Explicit |
| S08 | Location/Town System 💡 | World | Persistent settlements and POIs with NPCs and/or location Actions (pray, rest, explore, etc.). | Explicit |
| S09 | NPC Data System 💡 | World | NPC definitions: name, role, faction, location, recruitable flag, dialogue pool, services offered. | Implicit |

### Character Layer

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S10 | Character Stats System 💡 | Character | HP, Offence, Defence, Speed, Size. Protections: Slashing/Piercing/Blunt/Fire/Ice/Shock. Creatures share universal model. | Explicit |
| S11 | Aptitudes System 💡 | Character | Aptitudes trained through NPC trainers, location actions, and significant deeds. Range 0–4. Not automatic. | Explicit |
| S12 | Inventory System 💡 | Character | Shared party inventory. Items have weight. Party carry capacity. Slot-based equipment. | Explicit |
| S13 | Equipment System 💡 | Character | 8 slots per character (head, chest, main-hand, off-hand, boots, ranged, accessory×2). Equipment modifies stats. | Explicit |
| S14 | Progression/Leveling System 💡 | Character | 20 levels. +1 Offence, +1 Defence, +3 HP per level. XP from combat, quests, discovery. | Explicit |

### Gameplay Layer

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S15 | World Map Navigation 💡 | Gameplay | Real-time continuous party movement with biome-based speed modifiers, road bonuses, night penalties, POI/encounter proximity detection. | Explicit |
| S16 | Party Encounter System 💡 | Gameplay | Spotting, chasing, and engaging parties on the world map. Hostile → combat, trader → trade, friendly NPC → dialogue (same as location NPCs). | Implicit |
| S17 | POI System | Gameplay | MERGED INTO S08 — all locations (settlements + POIs) share a unified model with progressive discovery. | Explicit |
| S18 | Tactical Combat System 💡 | Gameplay | Real-time continuous-space. Tick-based action (act→cooldown→ready). Ticks pause when captain is ready. No reflex pressure. | Explicit |
| S19 | Unit AI System 💡 | Gameplay | Simple behaviour: attack nearest, follow captain, use skills when available. Competent but predictable. | Implicit |
| S20 | Damage Calculation System 💡 | Gameplay | Hit chance (Offence vs Defence), damage (weapon + Offence/5), protection (flat subtraction per type), tag modifiers. | Implicit |
| S21 | Health & Status System 💡 | Gameplay | HP tracking, incapacitation, wound recovery. Status effects: Burn, Poison, Stun, Slow. | Implicit |
| S22 | Combat Skills System 💡 | Gameplay | Special battle actions: Fire Breath, Oakskin, Fireball, Javelin, Heal, Summon, etc. Per-creature skill sets with cooldowns. | Explicit |
| S23 | Equipment Effects System 💡 | Gameplay | Weapon-vs-creature interactions (blunt vs skeletons, fire vs trolls). Weapon tags (reach, fast, heavy, versatile). | Explicit |
| S24 | VFX Pipeline 💡 | Gameplay | Event-driven visual effects: projectiles, impacts, auras, status indicators. Gemstone colour mapping. | Explicit |

### Faction/Economy Layer

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S24 | Faction Data System 💡 | Faction | Faction definitions, relationships, visual identity, reputation scale. 3 active + 1 hidden (Atlantean). | Explicit |
| S25 | Faction Reputation System 💡 | Faction | Player standing tracking per faction. Tiers: Hostile → Unfriendly → Neutral → Friendly → Allied. Affects quests, trade, NPCs. | Explicit |
| S26 | NPC Faction Assignment 💡 | Faction | Which NPCs belong to which faction, faction-based NPC behaviour triggers. | Implicit |
| S27 | Economy/Trading System 💡 | Faction | Buying and selling. Prices affected by base value, prosperity, Oratory aptitude, faction reputation. | Explicit |
| S28 | NPC Recruitment System 💡 | Faction | Two-tier: named companions (aptitudes, full gear, dialogue) + generic troops (limited gear, no aptitudes). Party limited by Command. | Explicit |

### Narrative Layer

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S29 | Quest Template System 💡 | Narrative | Reusable quest structures. Supports hunt, delivery, clear, destroy, kill, find, discover, bring types. Extensible via data. | Explicit |
| S30 | Quest Instance System 💡 | Narrative | Active quest tracking. Progress counters, expiry, turn-in, rewards. Multiple instances per template supported. | Explicit |
| S31 | Dialogue System 💡 | Narrative | Mount & Blade-style context-sensitive interaction menu. Options appear/disappear based on NPC role, reputation, quests, services. | Explicit |

### Presentation Layer

| # | System | Category | Description | Source |
|---|--------|----------|-------------|--------|
| S32 | Map/Minimap System | Presentation | ❌ NOT NEEDED — the player navigates by sight and landmarks on the world map. No map or minimap. | — |
| S33 | Time UI 💡 | Presentation | Period name + sun/moon icon + day counter. Poetic period names, no exact clock. | Implicit |

---

## Dependency Map

```
FOUNDATION
├── S01 Input System
├── S02 Save/Load System
├── S03 Audio/Music System
└── S04 Main Menu System

WORLD (depends on Foundation)
├── S05 Procedural World Generation
├── S06 Biome System
├── S07 Time System
├── S08 Location/Town System
└── S09 NPC Data System ────────── depends on S08, S24

CHARACTER (depends on Foundation)
├── S10 Character Stats System
├── S11 Skill System
├── S12 Inventory System
├── S13 Equipment System ───────── depends on S12
└── S14 Progression System ────── depends on S10, S11

GAMEPLAY (depends on World + Character)
├── S15 World Map Navigation ──── depends on S05, S06, S07
├── S16 Party Encounter System ── depends on S15
├── S17 POI System ────────────── depends on S05, S08
├── S18 Tactical Combat ───────── depends on S10, S13, S19, S20, S21, S22, S23
├── S19 Unit AI System
├── S20 Damage Calculation ────── depends on S10, S13, S22
├── S21 Health & Status System ── depends on S20
├── S22 Equipment Effects System ─ depends on S10, S13
└── S23 VFX Pipeline

FACTION/ECONOMY (depends on World + Character)
├── S24 Faction Data System
├── S25 Faction Reputation ────── depends on S24
├── S26 NPC Faction Assignment ── depends on S24, S08
├── S27 Economy/Trading ───────── depends on S25, S12, S08
└── S28 NPC Recruitment ───────── depends on S25, S09, S08

NARRATIVE (depends on Faction + Character)
├── S29 Quest Template System
├── S30 Quest Instance System ──── depends on S29
└── S31 Dialogue System ───────── depends on S30, S25, S09

PRESENTATION (depends on all above)
├── S32 Map/Minimap System ────── depends on S05, S15
└── S33 Time UI ───────────────── depends on S07
```

---

## Priority Assignment

### MVP (Required for core loop)

| Priority | System | Why |
|----------|--------|-----|
| 1 | S01 Input System | Foundation — everything uses input |
| 2 | S04 Main Menu System | Player needs to start the game |
| 3 | S02 Save/Load System | Progress must persist |
| 4 | S03 Audio/Music System | Core feel — music and SFX |
| 5 | S05 Procedural World Generation | The world must exist for navigation |
| 6 | S06 Biome System | MVPs needs biomes for traversal decisions |
| 7 | S07 Time System | Day/night visual cycle for world immersion |
| 8 | S08 Location/Town System | 4 towns for quest hubs and trading |
| 9 | S09 NPC Data System | Town NPCs with roles and dialogue |
| 10 | S10 Character Stats System | Core character definition |
| 11 | S11 Skill System | Skills like Tracking, Oratory for gameplay |
| 12 | S12 Inventory System | Item management |
| 13 | S13 Equipment System | Gear affects combat |
| 14 | S14 Progression System | Growth over time |
| 15 | S15 World Map Navigation | Core loop — player moves across map |
| 16 | S16 Party Encounter System | Core loop — encounter other parties |
| 17 | S17 POI System | Shrines, ruins for exploration |
| 18 | S24 Faction Data System | 2 factions need data |
| 19 | S26 NPC Faction Assignment | NPCs need faction identity |
| 20 | S25 Faction Reputation System | Tracking standing with factions |
| 21 | S27 Economy/Trading System | Buying, selling in towns |
| 22 | S18 Tactical Combat System | Core loop — battles |
| 23 | S19 Unit AI System | Auto-fight for followers, enemy AI |
| 24 | S20 Damage Calculation System | Combat resolution |
| 25 | S21 Health & Status System | HP and status effects |
| 26 | S22 Equipment Effects System | Blunt vs sharp vs stone trolls |
| 27 | S23 VFX Pipeline | Visual feedback for combat |
| 28 | S29 Quest Template System | 3 quest templates |
| 29 | S30 Quest Instance System | Active quest tracking |
| 30 | S31 Dialogue System | NPC conversation, quest offering |
| 31 | S32 Map/Minimap System | Navigation aid |
| 32 | S33 Time UI | Day/night indicator |

### Vertical Slice (MVP + one polished region)

| Priority | System | Why |
|----------|--------|-----|
| 33 | S28 NPC Recruitment System | Relationship-gated companions add depth |

### Full Vision (post-MVP)

| Priority | System | Why |
|----------|--------|-----|
| 34 | S24 Expansion | 3rd faction + hidden faction |
| 35 | S07 Expansion | Full time system with gameplay effects |
| 36 | S14 Expansion | Companion-specific progression paths |
| 37 | S31 Expansion | Complex dialogue trees with branching |
| 38 | S17 Expansion | Full POI variety and procedural placement |

---

## High-Risk Systems

| System | Risk Level | Reason | Mitigation |
|--------|------------|--------|------------|
| S18 Tactical Combat | **HIGH** | Real-time continuous-space with collision, pathfinding, AI — hardest technical challenge in the project | Prototype in isolation first. Start with simple 1v1, scale up. |
| S05 Procedural World Gen | **MEDIUM** | Multi-stage generation (terrain, biomes, roads, sites) — quality is unproven | Each stage can be prototyped independently. Start with terrain, add layers. |
| S19 Unit AI | **MEDIUM** | AI followers need to feel competent without player commands | Start with simple behaviour (attack nearest enemy, follow captain). Expand later. |
| S31 Dialogue System | **MEDIUM** | Tight integration with quests, reputation, and NPC state — many cross-system dependencies | Define the data contract between Dialogue and Quest systems early. |

---

## Design Order (Recommended)

1. S01 Input System
2. S04 Main Menu System
3. S03 Audio/Music System
4. S02 Save/Load System
5. S05 Procedural World Generation
6. S06 Biome System
7. S08 Location/Town System
8. S09 NPC Data System
9. S24 Faction Data System
10. S26 NPC Faction Assignment
11. S07 Time System
12. S15 World Map Navigation
13. S16 Party Encounter System
14. S17 POI System
15. S10 Character Stats System
16. S11 Skill System
17. S12 Inventory System
18. S13 Equipment System
19. S14 Progression System
20. S25 Faction Reputation System
21. S27 Economy/Trading System
22. S18 Tactical Combat System
23. S19 Unit AI System
24. S20 Damage Calculation System
25. S21 Health & Status System
26. S22 Equipment Effects System
27. S23 VFX Pipeline
28. S29 Quest Template System
29. S30 Quest Instance System
30. S31 Dialogue System
31. S32 Map/Minimap System
32. S33 Time UI
33. S28 NPC Recruitment System

---

## Progress Tracker

| Status | Count | Systems |
|--------|-------|---------|
| 🔴 Not Started | 32 | All except S01 |
| 🟡 In Progress | 0 | — |
| 🟢 Complete | 33 | ✅ ALL SYSTEMS DESIGNED — see files in design/gdd/ |
| **Total** | **33** | |
