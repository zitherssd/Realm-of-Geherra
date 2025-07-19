-- This file will be renamed to src/data/party_defs.lua
local parties = {
    {x = 600, y = 400, size = 3, types = {"soldier", "archer", "soldier"}, party_type = "enemy"},
    {x = 1200, y = 800, size = 4, types = {"knight", "soldier", "archer", "soldier"}, party_type = "enemy"},
    {x = 400, y = 1200, size = 2, types = {"peasant", "soldier"}, party_type = "enemy"},
    {x = 1000, y = 1000, size = 3, types = {"peasant", "soldier", "archer"}, party_type = "bandit"},
    {x = 1500, y = 1500, size = 2, types = {"soldier", "archer"}, party_type = "bandit"}
}

return parties