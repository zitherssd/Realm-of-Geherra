-- data/units/pelasgians/troops.lua
-- Pelasgian troop definitions

return {
    ["pelas_youth"] = {
        id = "pelas_youth",
        name = "Pelas Youth",
        type = "pelasgian",
        sprite = {
            "src/assets/sprites/units/dacian_youth.png",
        },
        stats = {
            health = 20,
            attack = 9,
            defense = 8,
            speed = 9,
            battle_speed = 8
        },
        size = 3,
        equipment = {
            mainHand = "club",
            body = "furs_armor"
        },
        loot = {
            {currency = "gold", chance = 0.3, min = 1, max = 8}
        }
    },

    ["pelas_tribesman"] = {
        id = "pelas_tribesman",
        name = "Pelas Tribesman",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/dacian_tribesman.png",
        stats = {
            health = 22,
            attack = 10,
            defense = 10,
            speed = 9,
            battle_speed = 9
        },
        size = 3,
        equipment = {
            mainHand = {"spear", "club"},
            body = "furs_armor",
            feet = "fur_shoes",
            head = "bronze_cap"
        },
        loot = {
            {currency = "gold", chance = 0.35, min = 3, max = 12}
        }
    },

    ["pelas_skirmisher"] = {
        id = "pelas_skirmisher",
        name = "Pelas Skirmisher",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/dacian_skirmisher.png",
        stats = {
            health = 24,
            attack = 11,
            defense = 9,
            speed = 9,
            battle_speed = 12
        },
        size = 3,
        equipment = {
            mainHand = "spear",
            offHand = "wooden_shield",
            rangedWeapon = "single_throw_javelin",
            feet = "fur_shoes"
        },
        loot = {
            {currency = "gold", chance = 0.4, min = 4, max = 14}
        }
    },

    -- Pealasgia monster 5893; see README.md for import mappings.
    ["pelas_slinger"] = {
        id = "pelas_slinger",
        name = "Pelas Slinger",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/slinger_idle.png",
        stats = {
            health = 22,
            attack = 10,
            defense = 10,
            strength = 10,
            speed = 16,
            battle_speed = 13,
        },
        size = 3,
        equipment = {
            rangedWeapon = "sling"
        },
    },

    -- Pealasgia monster 5894; see README.md for import mappings.
    ["pelas_warrior"] = {
        id = "pelas_warrior",
        name = "Pelas Warrior",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/warrior_idle.png",
        stats = {
            health = 11,
            attack = 11,
            defense = 11,
            strength = 10,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5895; see README.md for import mappings.
    ["pelas_comatzi"] = {
        id = "pelas_comatzi",
        name = "Pelas Comatzi",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/comatzi_idle.png",
        stats = {
            health = 12,
            attack = 12,
            defense = 12,
            strength = 11,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5896; see README.md for import mappings.
    ["hutzu_rider"] = {
        id = "hutzu_rider",
        name = "Hutzu Rider",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/rider_idle.png",
        stats = {
            health = 11,
            attack = 11,
            defense = 11,
            strength = 10,
            speed = 20,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5897; see README.md for import mappings.
    ["pelas_gaete"] = {
        id = "pelas_gaete",
        name = "Pelas Gaete",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/gaete_idle.png",
        stats = {
            health = 12,
            attack = 12,
            defense = 10,
            strength = 12,
            speed = 16,
            battle_speed = 13,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5898; see README.md for import mappings.
    ["pelas_tarabostes"] = {
        id = "pelas_tarabostes",
        name = "Pelas Tarabostes",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/tarabostes_idle.png",
        stats = {
            health = 12,
            attack = 13,
            defense = 13,
            strength = 11,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5899; see README.md for import mappings.
    ["blue_river_guard"] = {
        id = "blue_river_guard",
        name = "Blue River Guard",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/river_guard_idle.png",
        stats = {
            health = 11,
            attack = 11,
            defense = 10,
            strength = 10,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5900; see README.md for import mappings.
    ["wolf_oath_warrior"] = {
        id = "wolf_oath_warrior",
        name = "Wolf-Oath Warrior",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/wolf_oath_idle.png",
        stats = {
            health = 13,
            attack = 12,
            defense = 11,
            strength = 12,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5901; see README.md for import mappings.
    ["cara_scout"] = {
        id = "cara_scout",
        name = "Cara Scout",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/scout_idle.png",
        stats = {
            health = 10,
            attack = 10,
            defense = 10,
            strength = 10,
            speed = 18,
            battle_speed = 14,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5902; see README.md for import mappings.
    ["pelas_chieftain"] = {
        id = "pelas_chieftain",
        name = "Pelas Chieftain",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/chieftain_idle.png",
        stats = {
            health = 13,
            attack = 12,
            defense = 12,
            strength = 11,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5903; see README.md for import mappings.
    ["tarabostes_lord"] = {
        id = "tarabostes_lord",
        name = "Tarabostes Lord",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/lord_idle.png",
        stats = {
            health = 15,
            attack = 14,
            defense = 13,
            strength = 12,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5904; see README.md for import mappings.
    ["pelas_druid"] = {
        id = "pelas_druid",
        name = "Pelas Druid",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/druid_idle.png",
        stats = {
            health = 10,
            attack = 8,
            defense = 8,
            strength = 9,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5905; see README.md for import mappings.
    ["blue_river_astrologer"] = {
        id = "blue_river_astrologer",
        name = "Blue River Astrologer",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/astrologer_idle.png",
        stats = {
            health = 10,
            attack = 8,
            defense = 8,
            strength = 9,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5906; see README.md for import mappings.
    ["elder_of_cara"] = {
        id = "elder_of_cara",
        name = "Elder of Cara",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/elder_idle.png",
        stats = {
            health = 10,
            attack = 8,
            defense = 8,
            strength = 9,
            speed = 14,
            battle_speed = 12,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5907; see README.md for import mappings.
    ["wolf_of_the_first_pact"] = {
        id = "wolf_of_the_first_pact",
        name = "Wolf of the First Pact",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/wolf_idle.png",
        stats = {
            health = 12,
            attack = 12,
            defense = 12,
            strength = 11,
            speed = 20,
            battle_speed = 26,
        },
        size = 3,
        equipment = {},
    },

    -- Pealasgia monster 5908; see README.md for import mappings.
    ["hutzu_pony"] = {
        id = "hutzu_pony",
        name = "Hutzu Pony",
        type = "pelasgian",
        sprite = "src/assets/sprites/units/pelasgians/pony_idle.png",
        stats = {
            health = 16,
            attack = 8,
            defense = 10,
            strength = 12,
            speed = 20,
            battle_speed = 24,
        },
        size = 5,
        equipment = {},
    },
}
