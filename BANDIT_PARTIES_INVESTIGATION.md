# Bandit Parties Investigation Report

## Issue Summary
**Problem**: Bandit parties do not wander around towns on the map as they're supposed to do.

**Root Cause**: The bandit parties feature is **not implemented** in the current codebase.

## Detailed Analysis

### Current Game State
After examining all source files in the `src/` directory, the current implementation includes:

1. **Player System** (`player.lua`)
   - Single player character with stats (Strength, Agility, Vitality, Leadership)
   - Player army management
   - Player movement around the overworld

2. **Overworld Map** (`overworld.lua`)
   - Static towns with different types (village, city, port, fortress)
   - Terrain features (forests, mountains, lakes)
   - Roads connecting towns
   - No NPC units or wandering parties

3. **Army Units** (`army_unit.lua`)
   - Unit types: Peasant, Militia, Soldier, Knight, Archer, Crossbowman
   - Only used for player's army
   - No AI-controlled armies or bandits

4. **Town System** (`town.lua`)
   - Unit recruitment
   - Shopping and services
   - Static locations only

### What's Missing
The following features related to bandit parties are **completely absent**:

- ❌ NPC army units or bandit parties
- ❌ AI movement systems for non-player units
- ❌ Wandering/patrol behavior
- ❌ Bandit spawning mechanics
- ❌ Combat encounters with bandits
- ❌ Any reference to "bandits" in the codebase

### Search Results
Comprehensive searches revealed:
- **"bandit"**: No matches found
- **"wander"**: No matches found  
- **"AI"**: No matches found
- **"enemy"**: No matches found
- **"party"**: No matches found

## Conclusion

This is **not a bug** but rather an **unimplemented feature**. The game appears to be in early development, with only basic player movement, town interaction, and army recruitment systems in place.

## Recommendations

To implement wandering bandit parties, the following systems would need to be developed:

1. **NPC Army System**
   - Create bandit party objects similar to player armies
   - Implement different bandit types and compositions

2. **AI Movement System**
   - Pathfinding around the overworld
   - Wandering patterns near towns
   - Collision detection with player

3. **Spawn System**
   - Generate bandit parties at appropriate locations
   - Manage party lifecycle (spawn, wander, despawn)

4. **Combat System**
   - Battle mechanics when player encounters bandits
   - Rewards and consequences

5. **Game Loop Integration**
   - Update bandit positions each frame
   - Handle interactions with player and towns

## Files That Would Need Modification/Creation

- `src/bandit_party.lua` (new) - Bandit party logic
- `src/ai_movement.lua` (new) - AI movement and pathfinding
- `src/combat.lua` (new) - Battle system
- `src/game.lua` - Integrate bandit updates into main game loop
- `src/overworld.lua` - Add bandit rendering and management

The current codebase provides a solid foundation for these features, but significant development work is required to implement wandering bandit parties.