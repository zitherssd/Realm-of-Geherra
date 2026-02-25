-- data/quests.lua
-- Quest definitions

return {
    ["retrieve_amulet"] = {
        id = "retrieve_amulet",
        title = "Retrieve the Lost Amulet",
        giver = "elder",
        description = "The elder requests you find the amulet lost in the cave",
        objectives = {
            {type = "travel", target = "mountain_cave"},
            {type = "collect", item = "ancient_amulet", required = 1},
            {type = "deliver", npc = "elder"}
        },
        rewards = {gold = 200, reputation = {kingdom = 25}}
    },
    
    ["join_army"] = {
        id = "join_army",
        title = "Join the Army",
        giver = "commander",
        description = "The commander needs soldiers for the upcoming battle",
        objectives = {
            {type = "talk", npc = "recruiter"},
            {type = "reach", location = "barracks"}
        },
        rewards = {gold = 100, unlock = "join_army"}
    },

    ["hunt_dogs"] = {
        id = "hunt_dogs",
        title = "The Wild Pack",
        giver = nil, -- Assigned dynamically by the NPC
        description = "Hunt down the pack of wild dogs terrorizing the village.",
        objectives = {
            {type = "kill_party", target = "wild_dog_pack", required = 1, description = "Defeat the Wild Dog Pack"},
            {type = "report_to_giver", required = 1, description = "Report back to the Village Elder"}
        },
        rewards = {gold = 50, reputation = {menari = 5}},
        onStart = {
            type = "spawn_party",
            partyId = "wild_dog_pack",
            name = "Wild Dog Pack",
            faction = "bandits",
            troops = {"war_dog", "war_dog", "war_dog", "war_dog", "war_dog"},
            offset = {x = 100, y = 0}
        }
    }
}
