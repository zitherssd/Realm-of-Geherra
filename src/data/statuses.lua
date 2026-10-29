-- data/statuses.lua
-- Status effect definitions

return {
    ["stoneskin"] = {
        battleLong = true,
        category = "buff",
        effects = { protection_slashing = 3, protection_piercing = 3, protection_blunt = 3 },
        visual = { saturation = 0.3 },
    },

    ["mistform"] = {
        battleLong = true,
        category = "buff",
        effects = { incomingDamageMax = 1 },
        expiresOn = { event = "onHitReceived", chance = 0.2 },
        visual = { alpha = 0.6 },
    },

    ["immolation"] = {
        battleLong = true,
        category = "buff",
        reactions = { onHitReceived = { damage = 3, damageType = "fire", meleeOnly = true } },
    },

    ["charge_body"] = {
        battleLong = true,
        category = "buff",
        reactions = { onHitReceived = { damage = 3, damageType = "shock", meleeOnly = true } },
    },

    ["air_shield"] = {
        battleLong = true,
        category = "buff",
        effects = { projectileDefense = 4 },
    },

    ["resist_cold"] = {
        battleLong = true,
        category = "buff",
        effects = { incomingDamage_iceMultiplier = 0.5 },
    },

    ["rage"] = {
        battleLong = true,
        category = "buff",
        effects = { strength = 4 },
        visual = { tint = { 1, 0.2, 0.2, 0.4 }, priority = 10 },
    },

    ["poisoned_weapon"] = {
        battleLong = true,
        category = "buff",
        reactions = { onHitDealt = { apply = { poison = true } } },
    },

    ["harassed"] = {
        category = "debuff",
        lifetime = "battle-only",
        policy = "stack",
        decayEvery = 10,
        effects = { defense = -1 },
    },

    ["immobilize"] = {
        category = "debuff",
        duration = 40,
        blocks = { move = true },
    },

    ["burn"] = {
        duration = 120,
        damagePerTick = 1,
        damageType = "fire",
        category = "debuff",
        visual = { tint = { 1, 0.35, 0.1, 0.2 } },
        tickEvery = 20,
        description = "Takes damage over time from fire",
    },

    ["stun"] = {
        duration = 30,
        canAct = false,
        category = "debuff",
        description = "Cannot act",
    },

    ["paralyze"] = {
        duration = 40,
        canAct = false,
        category = "debuff",
        description = "Paralyzed by a shock, cannot act",
    },

    ["freeze"] = {
        duration = 45,
        damagePerTick = 0,
        category = "debuff",
        description = "Slowed movement and action speed",
    },

    ["poison"] = {
        duration = 90,
        damagePerTick = 2,
        damageType = "poison",
        category = "debuff",
        categories = { poison = true },
        visual = { tint = { 0.3, 1, 0.3, 0.2 } },
        policy = "stack",
        stackPeriodicDamage = true,
        tickEvery = 20,
        description = "Toxic damage over time",
    },
}
