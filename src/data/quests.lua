-- data/quests.lua
-- Quest definitions

local Registry = require("src.data.definition_registry")
local quests = {
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

    ["pilgrimage"] = {
        id = "pilgrimage",
        title = "A Sacred Pilgrimage",
        giver = nil, -- assigned dynamically
        procedural = true,
        repeatable = false,
        description = "Carry the sacred offerings to a nearby shrine on behalf of the village.",
        objectives = {
            {
                type = "travel",
                -- target is resolved at activation time by pickTarget
                pickTarget = { locationType = "shrine" },
                required = 1,
                description = "Deliver the offerings to a shrine"
            },
            {
                type = "report_to_giver",
                required = 1,
                description = "Return to the Village Elder"
            }
        },
        rewards = { gold = 30, favor = 60, reputation = { menari = 10 } }
    },

    ["hunt_dogs"] = {
        id = "hunt_dogs",
        title = "The Wild Pack",
        giver = nil, -- Assigned dynamically by the NPC
        procedural = true,
        repeatable = true,
        description = "Hunt down the pack of wild dogs terrorizing the village.",
        objectives = {
            {type = "kill_party", target = "wild_dog_pack", required = 1, description = "Defeat the Wild Dog Pack"},
            {type = "report_to_giver", required = 1, description = "Report back to the Village Elder"}
        },
        rewards = {gold = 50, favor = 40, reputation = {menari = 5}},
        onStart = {
            type = "spawn_party",
            partyId = "wild_dog_pack",
            name = "Wild Dog Pack",
            faction = "bandits",
            troops = {"war_dog", "war_dog", "war_dog", "war_dog", "war_dog"},
            offset = {x = 100, y = 0}
        }
    },

    ["deliver_message"] = {
        id = "deliver_message",
        title = "Urgent Dispatch",
        giver = nil,
        procedural = true,
        repeatable = true,
        description = "The elder entrusts you with a sealed message for a nearby settlement.",
        objectives = {
            {
                type = "travel",
                pickTarget = { locationType = "village" },
                required = 1,
                description = "Deliver the message to a nearby village"
            },
            {
                type = "report_to_giver",
                required = 1,
                description = "Return to the elder"
            }
        },
        rewards = {gold = 25, favor = 25, reputation = {menari = 3}},
        onStart = {
            type = "give_item",
            itemId = "sealed_message",
            quantity = 1
        }
    },

    ["deliver_item"] = {
        id = "deliver_item",
        title = "Barter Bundle",
        giver = nil,
        procedural = true,
        repeatable = true,
        description = "The elder sends trade goods to a neighbouring village. The bundle must arrive intact.",
        objectives = {
            {
                type = "travel",
                pickTarget = { locationType = "village" },
                required = 1,
                description = "Deliver the trade goods to a nearby village"
            },
            {
                type = "report_to_giver",
                required = 1,
                description = "Return to the elder"
            }
        },
        rewards = {gold = 40, favor = 35, reputation = {menari = 5}},
        onStart = {
            type = "give_item",
            itemId = "bundled_goods",
            quantity = 1
        }
    },

    ["rescue_daughter"] = {
        id = "rescue_daughter",
        title = "Stolen Child",
        giver = nil,
        procedural = true,
        repeatable = false,
        description = "Bandits have taken a young girl from the village. The elder begs you to bring her back.",
        objectives = {
            {
                type = "travel",
                pickTarget = { locationType = "bandit_camp" },
                required = 1,
                description = "Track the bandits to their camp"
            },
            {
                type = "kill_party",
                target = "bandit_raiders",
                required = 1,
                description = "Defeat the bandit raiders"
            },
            {
                type = "report_to_giver",
                required = 1,
                description = "Return the girl to the elder"
            }
        },
        rewards = {gold = 80, favor = 80, reputation = {menari = 15}},
        onStart = {
            type = "spawn_party",
            partyId = "bandit_raiders",
            name = "Bandit Raiders",
            faction = "bandits",
            troops = {"bandit", "bandit", "bandit", "bandit", "bandit"},
            offset = {x = 120, y = 40}
        }
    }
}

for id, quest in pairs(quests) do Registry.checkId("quest", id, quest) end
return quests
