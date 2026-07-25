# Aptitudes System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Meaningful Progression, Preparation Over Reflexes, Discovery-Driven Exploration

## Overview

The Aptitudes System manages a character's innate and trained capabilities — aptitudes like Command, Oratory, Tracking, and Divination that grow through training, practice, and discovery rather than automatic leveling. These are distinct from **combat Skills**, which are actions used in battle scenes. Aptitudes are increased by finding **trainers** (NPCs who teach specific aptitudes), visiting **special locations**, or performing **specific deeds**. To improve Shadowcraft, seek out an assassin. To improve Oratory, complete a quest for a poet. Aptitudes reward exploration and relationship building.

## Player Fantasy

You grow by *doing* and *learning*, not by accumulating XP. Want better Tracking? Find the hunter in Oak-Wall and prove yourself. Want Divination? The shrine in the eastern hills might grant you insight. Every aptitude point tells a story — a favour repaid, a monster conquered, a secret learned. A character's aptitudes reflect their journey, not just their level. (Combat Skills — the actions you use in battle — are a separate system.)

## Detailed Design

### Core Rules

1. **Aptitude list** (MVP):
   | Aptitude | Trained By | Also Improved By |
   |----------|-----------|------------------|
   | Command | Military officer, warlord NPCs | Winning large battles |
   | Oratory | Poet, elder NPCs | Completing negotiation quests |
   | Navigation | Trader, sailor NPCs | Discovering new regions |
   | Tracking | Hunter NPCs | Defeating rare monsters |
   | Shadowcraft | Assassin, rogue NPCs | Successful stealth actions |
   | Divination | Druid, witch, wizard NPCs | Praying at shrines, visiting sacred sites |
   | Engineering | Blacksmith, forger NPCs | Using ancient forge locations |

2. **Aptitude level range**: 0–4. Each point represents a tier:
   - 0: Untrained — no capability
   - 1: Novice — basic effectiveness
   - 2: Adept — reliable, moderate effectiveness
   - 3: Expert — strong, most checks pass
   - 4: Master — legendary effectiveness

   A single point gain is a major event — it requires finding the right trainer, completing significant quests, or achieving rare deeds.

3. **Aptitude points from trainers**: When the player finds a trainer NPC and meets their conditions (gold, reputation, completed quest), the trainer grants **one** aptitude point:
   - Basic training: +1 for gold (significant cost — hundreds of gold per point)
   - Quest training: +1 after completing a quest for the trainer (no gold cost)
   - Reputation training: +1 when faction reputation reaches Friendly or Allied
   - Each trainer can only grant 1 point per aptitude. To gain further points, the player must find different trainers or use location/action methods.

4. **Aptitude points from locations**: Visiting certain locations can grant **one** aptitude point (one-time, not repeatable):
   - Shrine of Divination → +1 Divination (one-time, first visit)
   - Ancient Forge → +1 Engineering (one-time, first use)
   - Grove of Spirits → +1 Divination (druid dialogue, one-time)

5. **Aptitude points from actions**: Certain significant deeds automatically grant **one** point:
   - Defeating a rare/unique monster → +1 Tracking
   - Winning a large battle (10+ enemies) → +1 Command
   - Discovering a new region → +1 Navigation

6. **Maximum per source**: A character can gain at most:
   - +1 per trainer (per aptitude) — must find different trainers for more
   - +1 per location (per aptitude) — one-time per location
   - +1 per action type — defeating 20 rare monsters doesn't give +20 Tracking

7. **Aptitude effects**: Each aptitude affects gameplay proportionally to its level (0–4):
   - **Command** (0–4): Party size limit (+1 per point), follower combat effectiveness
   - **Oratory** (0–4): Trade prices (−5% per point), NPC persuasion, quest availability
   - **Navigation** (0–4): World map speed (+5% per point), reduces night penalty
   - **Tracking** (0–4): Spotting range (+10% per point), reveals creature info
   - **Shadowcraft** (0–4): Stealth effectiveness, trap detection
   - **Divination** (0–4): Shrine prayer success, mystical vision (hidden POI hints)
   - **Engineering** (0–4): Equipment repair quality, forge/crafting effectiveness

8. **Aptitude checks**: 
   ```lua
   success = character.aptitude >= difficulty  -- binary check (difficulty 1–4)
   effectiveness = character.aptitude / 4       -- gradual effect (0.0–1.0)
   ```

### Aptitude Progression Summary

| Aptitude | Start | Max | Gain Method |
|----------|-------|-----|-------------|
| Command | 0 | 4 | Win large battles, train with warlord |
| Oratory | 0 | 4 | Complete quests for poets, train with elder |
| Navigation | 0 | 4 | Discover new regions, train with trader |
| Tracking | 0 | 4 | Defeat rare monsters, train with hunter |
| Shadowcraft | 0 | 4 | Stealth actions, train with assassin |
| Divination | 0 | 4 | Pray at shrines, train with druid/witch |
| Engineering | 0 | 4 | Use ancient forge, train with blacksmith |

### States and Transitions

| State | Level | Description |
|-------|-------|-------------|
| **Untrained** | 0 | No capability. Checks always fail. |
| **Novice** | 1 | Basic effectiveness. Easy checks pass. |
| **Adept** | 2 | Reliable. Moderate checks pass. |
| **Expert** | 3 | Strong. Difficult checks pass. |
| **Master** | 4 | Legendary. Almost all checks pass. |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S31 Dialogue System | Consumed by | NPC dialogue checks against Oratory, Command |
| S15 World Map Navigation | Consumed by | Navigation reduces night penalty, increases speed |
| S16 Party Encounter | Consumed by | Tracking increases spotting range |
| S08 Location System | Consumed by | Divination checks at shrines, Engineering at forges |
| S18 Tactical Combat | Consumed by | Command affects follower effectiveness |
| S27 Economy/Trading | Consumed by | Oratory affects trade prices |
| S28 NPC Recruitment | Consumed by | Some NPCs require aptitude thresholds to recruit |

## Formulas

**Aptitude check (binary):** `success = character.aptitude >= difficulty`

**Aptitude effect (gradual):** `effectiveness = character.aptitude / 4`

**Example:** Tracking at 2 → `effectiveness = 0.5` → spot range multiplier = `1.0 + 0.5 * 0.2 = 1.1`

**Oratory price effect:** `price_multiplier = 1.0 - (character.oratory * 0.05)`

At Oratory 4: `1.0 - (4 * 0.05) = 0.8` (20% discount at max).

## Edge Cases

- **If the player finds a trainer but lacks gold**: Training refused. Trainer indicates cost.
- **If an aptitude is at 4 (Master)**: Further training refused. Location/action gains ignored.
- **If the player recruits a trainer NPC as a companion**: NPC still offers training while in party.
- **If a location granting aptitude points has already been visited**: One-time only. No repeat gain.
- **If a deed would grant an aptitude point but aptitude is already 4**: Point lost. Deed still counts narratively.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S09 NPC Data System | Hard | Trainer NPCs with aptitude training capabilities |
| S08 Location System | Soft | Locations granting aptitude points |

**Depended on by:** S15 World Map Navigation, S16 Party Encounter, S31 Dialogue System, S18 Tactical Combat, S27 Economy/Trading, S08 Location System.

## Tuning Knobs

- **Aptitude range**: 0–4. Per the design.
- **Training gold cost per point**: Per-trainer configurable. Range: 200–1000.
- **Command battle threshold**: Default: 10 enemies.
- **Oratory price effect per point**: 0.05 (5% discount per point).

## Visual/Audio Requirements

- **Aptitude icons**: 16×16px icons. Symbols: banner, scroll, paw, compass, crescent, eye, hammer.
- **Aptitude gain notification**: Significant cue — warm glow, chime, banner.
- **Trainer indicator**: Book icon on NPCs who can train aptitudes.

## UI Requirements

- **Aptitude screen**: List with filled gemstones (0–4). Text describing current tier effects.
- **Training UI**: Available aptitudes shown with cost and current level.
- **Unlock notification**: Explanation of new capabilities when reaching a new tier.

## Acceptance Criteria

- **GIVEN** Command at 0, **WHEN** a warlord trains, **THEN** Command increases to 1.
- **GIVEN** Divination at 2, **WHEN** praying at difficulty-2 shrine, **THEN** success.
- **GIVEN** Divination at 2, **WHEN** praying at difficulty-4 shrine, **THEN** failure.
- **GIVEN** Oratory at 3, **WHEN** trading, **THEN** 15% discount included.
- **GIVEN** aptitude at 4, **WHEN** attempting further training, **THEN** refused.
- **GIVEN** defeating a rare monster, **WHEN** battle ends, **THEN** Tracking +1 (if below 4).
- **GIVEN** visiting a sacred location twice, **WHEN** aptitude gain triggers, **THEN** no gain (one-time).

## Open Questions

- **Aptitude caps per character**: All characters can reach 4, but training opportunities vary.
- **Combat Skills**: Battle actions to be designed with S18 Tactical Combat System.
