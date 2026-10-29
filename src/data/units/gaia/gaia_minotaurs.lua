-- Imported from Gaia gaia.dm; see README.md for stat mappings and limitations.

return {
    -- Gaia monster 5890; source sprite: minotaur_naked.
    ["gaia_minotaur_naked"] = {
        id = "gaia_minotaur_naked",
        name = "Minotaur (naked)",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_naked_idle.png",
        stats = {
            health = 25,
            attack = 8,
            defense = 8,
            strength = 16,
            speed = 16,
            battle_speed = 15,
        },
        size = 4,
        equipment = {},
    },

    -- Gaia monster 5891; source sprite: minotaur_warhammer.
    ["gaia_minotaur_warhammer"] = {
        id = "gaia_minotaur_warhammer",
        name = "Minotaur (warhammer)",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_warhammer_idle.png",
        stats = {
            health = 25,
            attack = 8,
            defense = 8,
            strength = 16,
            speed = 16,
            battle_speed = 15,
        },
        size = 4,
        equipment = {},
    },

    -- Gaia monster 5892; source sprite: minotaur_battleaxe.
    ["gaia_minotaur_battleaxe"] = {
        id = "gaia_minotaur_battleaxe",
        name = "Minotaur (battleaxe)",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_battleaxe_idle.png",
        stats = {
            health = 25,
            attack = 8,
            defense = 8,
            strength = 16,
            speed = 16,
            battle_speed = 15,
        },
        size = 4,
        equipment = {},
    },

    -- Gaia monster 5893; source sprite: minotaur_warrior_warhammer.
    ["gaia_minotaur_warrior_warhammer"] = {
        id = "gaia_minotaur_warrior_warhammer",
        name = "Minotaur Warrior (warhammer)",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_warrior_warhammer_idle.png",
        stats = {
            health = 25,
            attack = 9,
            defense = 8,
            strength = 16,
            speed = 16,
            battle_speed = 15,
        },
        size = 4,
        equipment = {},
    },

    -- Gaia monster 5894; source sprite: minotaur_warrior_battleaxe.
    ["gaia_minotaur_warrior_battleaxe"] = {
        id = "gaia_minotaur_warrior_battleaxe",
        name = "Minotaur Warrior (battleaxe)",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_warrior_battleaxe_idle.png",
        stats = {
            health = 25,
            attack = 9,
            defense = 8,
            strength = 16,
            speed = 16,
            battle_speed = 15,
        },
        size = 4,
        equipment = {},
    },

    -- Gaia monster 5907; source sprite: minotaur_commander.
    ["gaia_minotaur_commander"] = {
        id = "gaia_minotaur_commander",
        name = "Minotaur",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_commander_idle.png",
        stats = {
            health = 27,
            attack = 10,
            defense = 9,
            strength = 17,
            speed = 16,
            battle_speed = 15,
        },
        size = 4,
        equipment = {},
    },

    -- Gaia monster 5908; source sprite: minotaur_warrior_commander.
    ["gaia_minotaur_warrior_commander"] = {
        id = "gaia_minotaur_warrior_commander",
        name = "Minotaur Warrior",
        type = "gaia_minotaurs",
        injuryProfile = "humanoid",
        sprite = "src/assets/sprites/units/gaia/minotaur_warrior_commander_idle.png",
        stats = {
            health = 29,
            attack = 11,
            defense = 9,
            strength = 17,
            speed = 16,
            battle_speed = 15,
        },
        innateProtections = {
            slashing = -2,
            piercing = 1,
            blunt = 3,
        },
        size = 4,
        equipment = {},
    },
}
