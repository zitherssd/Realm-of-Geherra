-- data/statuses.lua
-- Status effect definitions

return {
    ["burn"] = {
        duration = 120,
        damagePerTick = 1,
        tickEvery = 20,
        description = "Takes damage over time from fire",
    },

    ["stun"] = {
        duration = 30,
        canAct = false,
        description = "Cannot act",
    },

    ["paralyze"] = {
        duration = 40,
        canAct = false,
        description = "Paralyzed by a shock, cannot act",
    },

    ["freeze"] = {
        duration = 45,
        damagePerTick = 0,
        description = "Slowed movement and action speed",
    },

    ["poison"] = {
        duration = 90,
        damagePerTick = 2,
        tickEvery = 20,
        description = "Toxic damage over time",
    },
}
