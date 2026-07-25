# Game Concept: Geherra Realms — Warband

*Created: 2026-07-25*
*Status: Draft*

---

## Elevator Pitch

> It's a 2D Mount & Blade-inspired RPG where you lead a party of adventurers across a procedurally generated fantasy world, engaging in real-time tactical battles where preparation and knowledge matter more than reflexes. Navigate dynamic biomes, build reputation with factions, and discover a living world full of quests, secrets, and dangers.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D Open-World Tactical RPG |
| **Platform** | PC (Steam) + Retro handhelds / Cross-platform (LÖVE native) |
| **Target Audience** | Explorer and Achiever players; fans of Mount & Blade, Battle Brothers, and Kenshi |
| **Player Count** | Single-player |
| **Session Length** | 30–60 minutes (natural stopping points at towns or after completing quests) |
| **Monetization** | Premium (Steam release) |
| **Estimated Scope** | Medium (months, solo developer) |
| **Comparable Titles** | Mount & Blade, Battle Brothers, Kenshi |

---

## Core Fantasy

You are a warband captain whose genius lies in preparation, not reflexes. Your skill is tested *before* the battle — in choosing the right weapons for the right enemy, picking the safest route across the map, recruiting the right companions, and knowing when to fight and when to flee. The world is a living, breathing place where your choices leave marks, factions remember you, and every journey is a story waiting to happen.

---

## Unique Hook

"Like Mount & Blade, AND ALSO a fully procedural 2D world with a tick-based tactical combat system where every action is deliberate — combined with biome-based traversal that makes route planning a meaningful strategic decision."

The biome system is key: travelling through forest or wasteland is slower and riskier than plains or grassland, so choosing your path across the world map is a tactical decision before any battle begins.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 4 | Pixel-art visuals, satisfying combat feedback, ambient world map audio |
| **Fantasy** (make-believe, role-playing) | 2 | You are a captain building a warband from nothing, building reputation across factions |
| **Narrative** (drama, story arc) | 3 | Player-driven emergent stories through faction reputation, quest choices, and dynamic NPC interactions |
| **Challenge** (obstacle course, mastery) | 1 | Knowledge-based challenge — knowing what beats what, optimal route planning, resource management |
| **Fellowship** (social connection) | N/A | Single-player experience |
| **Discovery** (exploration, secrets) | 1 | Procedural world with hidden POIs — shrines, ruins, wizard towers, ancient trees, natural springs, geysers |
| **Expression** (self-expression, creativity) | 5 | Party composition choices, equipment loadouts, faction alignment decisions |
| **Submission** (relaxation, comfort zone) | 6 | No time pressure — players can pause, plan, and proceed at their own pace |

### Key Dynamics (Emergent player behaviors)

- Players will plan routes around biome hazards and opportunities before travelling
- Players will experiment with weapon types against different enemies and share "what beats what" knowledge
- Players will develop attachments to factions based on reputation-driven quest outcomes
- Players will return to previously discovered POIs when they're strong enough to tackle them

### Core Mechanics (Systems we build)

1. **World Map Navigation** — Real-time continuous movement across a procedurally generated world with biome-based traversal modifiers
2. **Tactical Combat** — Real-time continuous-space battles with direct captain control and AI followers; tick-based action resolution
3. **Faction Reputation** — Persistent reputation tracking that affects quest availability, trade prices, and NPC interactions
4. **Quest Generation** — Template-driven procedural quests offered by NPCs based on their role and your reputation
5. **Character & Party Management** — Attributes, skills, inventory, equipment, and party composition

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Open world — choose where to go, who to fight, which quests to take, which factions to align with | Core |
| **Competence** (mastery, skill growth) | Knowledge-based skill — feeling smart for knowing what beats what, planning routes, preparing correctly | Core |
| **Relatedness** (connection, belonging) | Faction reputation system — factions remember you; companions have identities; NPCs react to your history | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- ✅ **Achievers** (goal completion, collection, progression) — Leveling up, collecting better gear, growing your party, completing quests
- ✅ **Explorers** (discovery, understanding systems, finding secrets) — Procedural world with hidden POIs; discovering what each biome, enemy, and faction offers
- ⬜ **Socializers** (relationships, cooperation, community) — N/A (single-player)
- ⬜ **Killers/Competitors** (domination, PvP, leaderboards) — N/A (single-player PvE)

### Flow State Design

- **Onboarding curve**: First 10 minutes — simple movement on the world map, one introductory combat, one town visit with a quest. Systems are revealed gradually as the player encounters them.
- **Difficulty scaling**: Early enemies are straightforward (bandits, wild beasts). Stronger enemies require specific preparations (blunt weapons for stone-skinned trolls, fire for regenerating foes). The world's difficulty is area-based — players can venture into dangerous biomes but are warned.
- **Feedback clarity**: Combat results clearly show why damage was effective or ineffective. Tooltips explain biome effects on movement. Reputation changes are displayed after quest completion.
- **Recovery from failure**: Losing a battle means retreating to the nearest town with reduced resources (not death). Failure is educational — the player learns what they needed to prepare.

---

## Core Loop

### Moment-to-Moment (30 seconds)

The player moves their party across the world map in real-time continuous 2D space. Other parties are visible moving around them. The player scans the terrain, spots POIs and enemy parties, and decides: engage, avoid, or investigate. Between encounters, they open inventory to manage equipment, check their party status, and plan their next destination.

### Short-Term (5-15 minutes)

Encounters structure the short-term loop: spot a party → decide to engage or avoid → enter tactical combat (if engaged) → resolve → loot/inspect rewards → choose next direction. On the map, this is punctuated by reaching POIs — a shrine to pray at, ruins to explore, a travelling NPC with a quest offer.

### Session-Level (30-60 minutes)

A full session typically looks like:
1. Start in a town — get quests, trade, recruit companions
2. Travel across the world map, navigating biomes and avoiding or engaging parties
3. Reach the quest POI — resolve the objective (delivery, hunt, clear location)
4. If wounded, wander — random encounters, discover new POIs along the way
5. Arrive at the next town — heal, sell loot, upgrade gear, find companions in the tavern, get new quests

Natural stopping points: reaching a town, completing a quest, winning or retreating from a major battle.

### Long-Term Progression

Over days and weeks: stronger gear and stats → larger party size → deeper faction reputation → access to better quests and equipment → new regions unlocked → return to challenging POIs with new capabilities. The player's identity grows from a wandering nobody to a captain of renown.

### Retention Hooks

- **Curiosity**: What's beyond that mountain range? What's inside those ruins? What does the hidden faction offer?
- **Investment**: Your party composition, your reputation with factions, the gear you've collected — progress you don't want to lose.
- **Mastery**: Learning optimal equipment against each enemy type, finding the safest routes between towns, understanding faction politics.

---

## Visual Identity Anchor

*Note: This section was defined collaboratively during brainstorming. It is the seed of the art bible and captures the visual direction before it can be forgotten between sessions.*

### Selected Direction: Antediluvian Earth

**One-line visual rule**: Grounded, earthy pixel art with a bronze-age-meets-high-magic aesthetic — think Mycenaean frescoes crossbred with Sumerian cylinder seals, where every gemstone glows and every god-touched creature is visibly *other*.

### Supporting Visual Principles

1. **Earth-Tech Visual Language** — Architecture and technology use cyclopean masonry, timber, clay, bronze, and gem inlays. No iron plate armour, no steel swords — think layered linen, bronze scale, obsidian-edged weapons. Gems are socketed into tools, weapons, and armour as power conduits.
   - *Design test*: "Does this object look like it belongs to a civilisation that mastered gem-magic instead of electricity?"

2. **God-Touched Creatures** — Monsters and giants are visually distinct from natural fauna — they have extra eyes, crystalline growths, iridescent patches, or anatomical impossibilities. A giant isn't just a big human; a sphinx has lapis-lazuli veins in its wings.
   - *Design test*: "At a glance, can you tell this creature was shaped by divine experimentation rather than natural evolution?"

3. **Faction Identity Through Material & Motif** — Each faction's visual identity is rooted in a distinct material and decorative language:
   - **Pelasgians (proto-Dacian/Indo-European)**: Wool, leather, bronze torcs, spiral motifs, forest colours (deep greens, ochre, copper)
   - **Proto-Mycenaeans**: Linen, boar-tusk helms, octopus/pillar motifs, Aegean blues and rust reds
   - **Proto-Egyptians (Middle Eastern)**: Linen kilts, lapis lazuli, gold, scarab and lotus motifs, desert ochres and indigos
   - *Design test*: "From colour and silhouette alone, can you identify which faction a unit belongs to?"

4. **Gemlight as Magic Language** — Magic and skill effects are expressed through gemstone colours and crystalline geometry. A divination spell pulses with moonstone white. A fire invocation glows like a ruby. Engineering constructs hum with amber light.
   - *Design test*: "Is every magical effect visually tied to a gemstone or earth-material, not to generic sparkles?"

### Colour Philosophy

A warm, earthy base palette — clay reds, amber, ochre, verdigris, deep indigo. Faction colours are natural pigments (copper, lapis, cinnabar). Magic and gems introduce saturated, luminous accents (emerald green, sapphire blue, ruby red, amethyst purple) that pop against the grounded world. Monsters have unnatural colour shifts — a giant scorpion's carapace might catch light with an opalescent sheen.

---

## Game Pillars

### Pillar 1: Preparation Over Reflexes
The player's skill is tested *before* the battle — in gear choices, troop composition, route planning, and knowing your enemy. The game never punishes slow reaction times.

*Design test*: "Does this feature reward knowledge and planning, or twitch reflexes?"

### Pillar 2: A Living, Persistent World
The world is alive — parties move in real-time, factions track your reputation, locations have dynamic economies and populations. Your choices leave marks.

*Design test*: "Does this feature make the world feel more reactive and interconnected, or does it treat the world as a static backdrop?"

### Pillar 3: Meaningful Progression
Every upgrade, companion, and reputation gain opens *new options*, not just bigger numbers. A party at 10 hours plays qualitatively differently than at 1 hour.

*Design test*: "Does this choice meaningfully change how the player plays, or is it just a bigger number?"

### Pillar 4: Discovery-Driven Exploration
The world rewards curiosity — hidden shrines, rare monsters, unexpected quests from travelling hunters. The player's story is what they *find*, not what they're told to do.

*Design test*: "Does this encourage the player to explore, or funnel them along a single path?"

### Anti-Pillars (What This Game Is NOT)

- **NOT a reflex-based game**: No QTEs, no dodge-rolling, no frame-perfect timing. Combat is tactical, not twitchy. This protects *Preparation Over Reflexes*.
- **NOT a linear story**: No "chosen one" narrative. The player writes their own story through choices and reputation. This protects *Discovery-Driven Exploration*.
- **NOT a grind**: Progression opens options, not gates. If a player needs to kill 50 bandits to afford a sword, the design has failed. This protects *Meaningful Progression*.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **Mount & Blade** | Open-world party command, faction reputation, direct captain control in battle | 2D pixel-art, fully procedural world, biome-based traversal, gridless tactical combat | Validates the core fantasy of "warband captain in a living world" |
| **Dominions 6** | Deep item progression, knowledge-based strategy, preparation-driven gameplay | Real-time world map (not turn-based), RPG character layer, smaller scope | Validates that "preparation is the skill" is a compelling design |
| **Battle Brothers** | Mercenary company management, procedural world, tactical combat | Direct captain control (not squad-only), stronger faction narrative layer, lighter management overhead | Validates the 2D tactical mercenary genre has an audience |

**Non-game inspirations**: Medieval history (particularly the migration period and early feudalism), low-fantasy literature, tabletop wargaming aesthetics.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–40 |
| **Gaming experience** | Mid-core to Hardcore |
| **Time availability** | 30–60 minute sessions, weeknights and weekends |
| **Platform preference** | PC (Steam), retro handhelds |
| **Current games they play** | Mount & Blade, Dominions 6, Battle Brothers, RimWorld, Kenshi |
| **What they're looking for** | A deep strategic RPG where knowledge and planning matter more than reflexes; a living world that rewards exploration and tells emergent stories |
| **What would turn them away** | Twitch-based combat, linear narratives, grind-heavy progression, lack of meaningful choices |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | LÖVE (Love2D) v11.4 — already set up in the project. Excellent fit for 2D pixel-art, runs on Windows/macOS/Linux, community ports for retro handhelds |
| **Key Technical Challenges** | Real-time continuous-space tactical combat (collision detection, pathfinding, unit AI); procedural world generation with biomes and road networks |
| **Art Style** | 2D pixel-art, medieval-fantasy grounded style |
| **Art Pipeline Complexity** | Medium — custom pixel art by the developer, supplemented by AI generation |
| **Audio Needs** | Moderate — ambient world map music, combat SFX, UI sounds |
| **Networking** | None (single-player) |
| **Content Volume** | MVP: 2 factions, 4 towns, 3 quest templates, ~10 weapons/armors, 5-10 enemy types, 5+ POI types. Full vision: 3+1 factions, 15-20 towns, 40-60 weapons/armors, large enemy roster, many POI types |
| **Procedural Systems** | World map generation (terrain mask, site placement, Voronoi biomes, road network); quest generation (template-based procedural offers) |

---

## Risks and Open Questions

### Design Risks
- Core loop may not sustain engagement without enough POI variety — need to ensure the world feels full, not empty
- "Preparation over reflexes" is compelling in theory but needs careful tuning — the player needs enough information to prepare *without* feeling like the game gave the answer away

### Technical Risks
- Real-time continuous-space combat with unit collision and AI pathfinding is the hardest technical challenge. Should be prototyped early and in isolation
- Procedural world generation quality is unproven — terrain, biome, and road generation all need their own prototypes

### Market Risks
- 2D pixel-art RPG is a crowded space — the unique hook (preparation over reflexes + biome traversal) needs to be front and centre in marketing
- Niche audience may limit commercial reach, but the genre has proven fans (Mount & Blade 16M+, Battle Brothers 500K+)

### Scope Risks
- As a first game for the developer, scope management is the single biggest risk. Every feature beyond the MVP threatens the timeline
- Content volume (weapons, enemies, POIs, quests) could easily bloat — need strict scope tiers and discipline

### Open Questions
- Can real-time tactical combat feel satisfying with tick-based action resolution? Answer: prototype combat in isolation first
- How many biome types are needed before the world feels sufficiently varied? Answer: start with 3-4 (plains, forest, wasteland, hills) and expand from playtest feedback
- What's the right balance of procedural vs authored content for quests? Answer: start with 3 template types, expand if the procedural pipeline works

---

## MVP Definition

**Core hypothesis**: "Players find the exploration-combat-progression loop engaging — moving across a procedural world with meaningful biome choices, engaging in tactical battles, and growing their party through quests and reputation."

**Required for MVP**:
1. Procedurally generated world map with walkable terrain and **biomes** (plains/grassland = fast, forest/wasteland = slow/harder)
2. Player party movement on world map with real-time party encounters
3. **2 factions**, each with **2 towns** (4 total) — vendors and quest givers
4. Reputation tracking per faction
5. Tactical combat — direct captain control, AI followers auto-fight
6. **3 quest templates** (hunt target, delivery, clear location)
7. Meaningful weapons/armors with real trade-offs (blunt vs sharp, light vs heavy)
8. Neutral POIs (shrines, ruins, etc.)

**Explicitly NOT in MVP** (defer to later):
- 3rd faction and hidden faction
- Full 40-60 weapons/armors
- Companion recruitment system
- Large enemy roster
- Day/night cycle and complex time system
- Rich dialogue trees

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 2 factions, 4 towns, 3 quest templates, ~10 weapons, 5 enemy types, 3 biomes, basic POIs | World map + biomes, tactical combat, reputation, quest generation, inventory | Months |
| **Vertical Slice** | 2 factions, full polish on one region | MVP features + one fully polished region with hand-tuned encounters | Months + |
| **Full Vision** | 3+1 factions, 15-20 towns, 40-60 items, large enemy roster, many POIs | All features: companions, day/night, rich dialogue, full procedural quest pools | Beyond initial scope |

---

## Next Steps

- [ ] Get concept approval from creative-director
- [ ] Run `/setup-engine` to configure engine and populate version-aware reference docs
- [ ] Run `/art-bible` to establish visual identity before writing any GDDs
- [ ] Decompose concept into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`)
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`)
- [ ] Validate core loop with playtest (`/playtest-report`)
