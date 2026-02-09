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
    }
}
