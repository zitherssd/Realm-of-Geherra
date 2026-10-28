-- data/encounters.lua
-- Encounter/combat scenarios

return {
    -- Tunables for the random encounter system (systems/campaign/encounter_system.lua).
    -- All content lives here so no system logic needs editing to retune.
    config = {
        -- Pixels of travel between encounter rolls while moving on the map.
        stepDistance = 180,
        -- Base chance per roll (before threat is added).
        baseChance = 0.10,
        -- Extra chance per threat point (chance = baseChance + threat * this).
        chancePerThreat = 0.004,
        -- Spawn placement around the player party (px).
        spawnMinDist = 90,
        spawnMaxDist = 140,
        -- Do not spawn closer than this to any settlement/location.
        minDistFromLocation = 200,
        -- Do not spawn closer than this to another party.
        minDistFromParty = 120,
        -- Minimum distance (px) the player must travel between spawns.
        minDistBetweenEncounters = 400,
        -- Player party power -> threat scaling (see computeThreat).
        powerToThreat = 0.03,
        -- Time-of-day threat bonuses.
        nightBonus = 20,
        dawnDuskBonus = 8,
        -- Day-counter ramp: +dayRamp threat per day past day 1, capped at dayRampCap.
        dayRamp = 1,
        dayRampCap = 25,
        -- Biome -> base threat. Roads halve the biome contribution.
        biomeThreat = {
            ocean = 0,
            beach = 5,
            cliff = 20,
            snow = 30,
            mountain = 30,
            hills = 15,
            desert = 18,
            plains = 5,
            forest = 25,
            marsh = 35,
            marsh_lake = 0,
            lake = 0,
            tundra = 25,
            ice = 30,
            oasis = 10,
        },
    },

    -- Ascending threat bands. The first band whose [minThreat, maxThreat] range
    -- contains the current threat is used; a weighted pool entry is picked from it.
    -- Each pool: weight, name, faction, hostile, dialogueId, enemies = {type,min,max}.
    bands = {
        {
            minThreat = 0,
            maxThreat = 12,
            pools = {
                {
                    weight = 50,
                    name = "Wolf Pack",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "wolf",
                            min = 1,
                            max = 3,
                        },
                    },
                },
                {
                    weight = 30,
                    name = "Stray Dogs",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "war_dog",
                            min = 2,
                            max = 4,
                        },
                    },
                },
                {
                    weight = 20,
                    name = "Lone Wolf",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "wolf",
                            min = 1,
                            max = 1,
                        },
                    },
                },
            },
        },
        {
            minThreat = 13,
            maxThreat = 30,
            pools = {
                {
                    weight = 35,
                    name = "Angry Bear",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "bear",
                            min = 1,
                            max = 1,
                        },
                    },
                },
                {
                    weight = 25,
                    name = "Bear and Wolves",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "bear",
                            min = 1,
                            max = 1,
                        },
                        {
                            type = "wolf",
                            min = 1,
                            max = 2,
                        },
                    },
                },
                {
                    weight = 25,
                    name = "Roadside Bandits",
                    faction = "bandits",
                    hostile = true,
                    dialogueId = "bandit_start",
                    enemies = {
                        {
                            type = "bandit",
                            min = 2,
                            max = 2,
                        },
                    },
                },
                {
                    weight = 15,
                    name = "Restless Dead",
                    faction = "undead",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "skeleton_sword",
                            min = 1,
                            max = 2,
                        },
                        {
                            type = "skeleton_spear",
                            min = 1,
                            max = 1,
                        },
                    },
                },
            },
        },
        {
            minThreat = 31,
            maxThreat = 50,
            pools = {
                {
                    weight = 35,
                    name = "Bandit Gang",
                    faction = "bandits",
                    hostile = true,
                    dialogueId = "bandit_start",
                    enemies = {
                        {
                            type = "bandit",
                            min = 3,
                            max = 5,
                        },
                    },
                },
                {
                    weight = 25,
                    name = "Skeleton Patrol",
                    faction = "undead",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "skeleton_sword",
                            min = 2,
                            max = 3,
                        },
                        {
                            type = "skeleton_spear",
                            min = 1,
                            max = 3,
                        },
                    },
                },
                {
                    weight = 20,
                    name = "Wandering Ogre",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "ogre",
                            min = 1,
                            max = 1,
                        },
                    },
                },
                {
                    weight = 20,
                    name = "Deserter Soldiers",
                    faction = "bandits",
                    hostile = true,
                    dialogueId = "bandit_start",
                    enemies = {
                        {
                            type = "soldier",
                            min = 2,
                            max = 3,
                        },
                    },
                },
            },
        },
        {
            minThreat = 51,
            maxThreat = 75,
            pools = {
                {
                    weight = 35,
                    name = "Bandit Leader's Crew",
                    faction = "bandits",
                    hostile = true,
                    dialogueId = "bandit_start",
                    enemies = {
                        {
                            type = "bandit",
                            min = 4,
                            max = 6,
                        },
                        {
                            type = "knight",
                            min = 1,
                            max = 1,
                        },
                    },
                },
                {
                    weight = 30,
                    name = "Ogre War Band",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "ogre",
                            min = 1,
                            max = 2,
                        },
                        {
                            type = "war_dog",
                            min = 1,
                            max = 2,
                        },
                    },
                },
                {
                    weight = 20,
                    name = "Undead Legion",
                    faction = "undead",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "skeleton_sword",
                            min = 3,
                            max = 5,
                        },
                        {
                            type = "skeleton_spear",
                            min = 2,
                            max = 3,
                        },
                        {
                            type = "knight",
                            min = 1,
                            max = 1,
                        },
                    },
                },
                {
                    weight = 15,
                    name = "Royal Guard Patrol",
                    faction = "bandits",
                    hostile = true,
                    dialogueId = "bandit_start",
                    enemies = {
                        {
                            type = "soldier",
                            min = 2,
                            max = 3,
                        },
                        {
                            type = "knight",
                            min = 1,
                            max = 2,
                        },
                    },
                },
            },
        },
        {
            minThreat = 76,
            maxThreat = 100,
            pools = {
                {
                    weight = 50,
                    name = "War Party",
                    faction = "bandits",
                    hostile = true,
                    dialogueId = "bandit_start",
                    enemies = {
                        {
                            type = "bandit",
                            min = 5,
                            max = 7,
                        },
                        {
                            type = "knight",
                            min = 1,
                            max = 2,
                        },
                    },
                },
                {
                    weight = 30,
                    name = "Feral Dragon",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "dragon",
                            min = 1,
                            max = 1,
                        },
                    },
                },
                {
                    weight = 20,
                    name = "Ogre Champion",
                    faction = "neutral",
                    hostile = true,
                    dialogueId = "encounter_ambush",
                    enemies = {
                        {
                            type = "ogre",
                            min = 2,
                            max = 2,
                        },
                        {
                            type = "war_dog",
                            min = 2,
                            max = 3,
                        },
                    },
                },
            },
        },
    },
}
