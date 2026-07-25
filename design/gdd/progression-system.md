# Progression/Leveling System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Meaningful Progression

## Overview

The Progression System handles character growth through leveling. As the player gains experience from combat, quests, and discoveries, their captain and companions level up. Each level grants stat increases (+1 Offence, +1 Defence, +3 HP) — a small but meaningful power gain. Over 20 levels, this transforms a starting peasant into a legendary captain.

## Player Fantasy

Every level feels earned. That +1 Offence means a noticeably higher hit chance. That +3 HP means you survive one more hit. The growth is steady and predictable — you always know what you're getting, and it always matters.

## Detailed Design

### Core Rules

1. **Level cap**: 20 levels. Level 1 is starting, Level 20 is legendary.

2. **Starting stats (Level 1, ungeared)**: HP 30, Offence 10, Defence 10, Speed 3, Size 3.

3. **Per-level gains** (applied on each level-up):
   - Offence +1
   - Defence +1
   - HP +3

4. **Experience gain**: XP is awarded for:
   - Defeating enemies in combat (XP per enemy based on their stats)
   - Completing quests (significant XP rewards)
   - Discovering new locations (minor XP)

5. **Level requirements**:
   - Level 2: 100 XP
   - Level 3: 250 XP
   - Level 4: 500 XP
   - Level 5: 800 XP
   - Then +400 XP per level
   - Level 20: ~8000 XP total

6. **Companion leveling**: Recruited companions start at a fixed level based on when they're found. They gain XP alongside the captain but at a reduced rate (80%).

7. **Generic troops**: Do not level. They are replaced with better troops as the player progresses.

### Stat Table (All Levels)

| Level | Offence | Defence | HP | XP Needed (Total) |
|-------|---------|---------|----|-------------------|
| 1 | 10 | 10 | 30 | 0 |
| 5 | 14 | 14 | 42 | 800 |
| 10 | 19 | 19 | 57 | 2,800 |
| 15 | 24 | 24 | 72 | 4,800 |
| 20 | 29 | 29 | 87 | 8,000 |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S10 Character Stats | Modifies | Level-ups grant stat increases |
| S30 Quest Instances | Provides XP | Quest completion awards XP |
| S18 Tactical Combat | Provides XP | Defeating enemies awards XP |
| S12 Inventory | Consumed by | Level may unlock higher-tier equipment access |

## Formulas

**XP to next level:**

`xp_for_level(n) = 100 + (n - 2) * 200` for n ≥ 2

**Total XP for level N:**

`total_xp(N) = 100 * (N-1) + 200 * (N-2) * (N-1) / 2`

## Edge Cases

- **If the player reaches level 20**: Further XP gains are ignored. Max level achieved.
- **If a companion joins at a higher level than the captain**: Companion levels are capped at the captain's level.
- **If XP would skip multiple levels**: All level-up benefits are applied cumulatively. The player sees multiple level-up notifications.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S10 Character Stats | Hard | Stats are modified on level-up |
| S18 Tactical Combat | Soft | Combat grants XP per enemy defeated |
| S30 Quest Instance | Soft | Quest completion grants XP |

**Depended on by:** S10 Character Stats (stats grow with level).
