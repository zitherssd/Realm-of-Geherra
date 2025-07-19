-- This file will be renamed to src/data/party_defs.lua
local parties = {
    {x = 600, y = 400, army = {"soldier", "archer", "soldier"}, party_type = "enemy"},
    {x = 1200, y = 800, army = {"knight", "soldier", "archer", "soldier"}, party_type = "enemy"},
    {x = 400, y = 1200, army = {"peasant", "soldier"}, party_type = "enemy"},
    {x = 1000, y = 1000, army = {"peasant", "soldier", "archer"}, party_type = "bandit"},
    {x = 1500, y = 1500, army = {"soldier", "archer"}, party_type = "bandit"}
}

return parties