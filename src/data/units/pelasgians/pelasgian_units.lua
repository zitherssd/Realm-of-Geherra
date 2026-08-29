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
            attack = 20,
            defense = 22,
            speed = 6,
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
            health = 24,
            attack = 22,
            defense = 24,
            speed = 7,
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
            health = 28,
            attack = 24,
            defense = 23,
            speed = 8,
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
    }
}
