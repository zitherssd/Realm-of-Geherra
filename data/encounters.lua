-- data/encounters.lua
-- Encounter/combat scenarios

return {
    ["bandits_on_road"] = {
        id = "bandits_on_road",
        name = "Ambush on the Road",
        type = "ambush",
        description = "A group of bandits blocks your path",
        enemies = {"bandit", "bandit", "bandit"},
        rewards = {gold = 100, items = {}}
    },
    
    ["castle_defense"] = {
        id = "castle_defense",
        name = "Defend the Castle",
        type = "defense",
        description = "Protect the castle from invasion",
        enemies = {"soldier", "soldier", "knight"},
        rewards = {gold = 500, reputation = {kingdom = 50}}
    }
}
