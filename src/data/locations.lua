-- src/data/locations.lua
local locations = {
    {
        name = "Iron Fort",
        x = 400, y = 400, size = 50, color = {0.5, 0.5, 0.5},
        type = "Fort", population = 200,
        description = "A heavily fortified stronghold."
    },
    {
        name = "Green Village",
        x = 900, y = 300, size = 35, color = {0.8, 0.6, 0.2},
        type = "Village", population = 120,
        description = "A peaceful farming village."
    },
    {
        name = "Eagle Tower",
        x = 1200, y = 700, size = 40, color = {0.3, 0.7, 0.3},
        type = "Tower", population = 60,
        description = "A tall watchtower overlooking the land."
    },
    {
        name = "Bandit Hideout",
        x = 1600, y = 1000, size = 30, color = {0.6, 0.4, 0.2},
        type = "Hideout", population = 40,
        description = "A secretive hideout for bandits."
    },
    {
        name = "Shadow Dungeon",
        x = 700, y = 1500, size = 45, color = {0.2, 0.2, 0.2},
        type = "Dungeon", population = 0,
        description = "A dark and dangerous dungeon."
    }
}
return locations