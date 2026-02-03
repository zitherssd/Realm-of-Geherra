-- data/items.lua
--
-- Data for all item types.

local Item = require("core.item")

local item_definitions = {
	{
		id = "iron_spear",
		name = "Iron Spear",
		description = "A sturdy spear for militia",
		category = "weapon",
		slots = { "mainhand" },
		stat_modifiers = {
			attack = 1,
			strength = 1,
		},
		actions = {
			"thrust",
		},
	},
	{
		id = "iron_sword",
		name = "Iron Sword",
		description = "A simple iron blade",
		category = "weapon",
		slots = { "mainhand" },
		stat_modifiers = {
			attack = 2,
			strength = 1,
		},
		actions = {
			"melee_slash",
		},
	},
	{
		id = "wooden_shield",
		name = "Wooden Shield",
		description = "Basic wooden shield",
		category = "shield",
		slots = { "offhand" },
		stat_modifiers = {
			defense = 2,
			protection = 1,
		},
		actions = {},
	},
	{
		id = "leather_armor",
		name = "Leather Armor",
		description = "Light armor for travelers",
		category = "armor",
		slots = { "armor" },
		stat_modifiers = {
			protection = 2,
		},
		actions = {},
	},
	{
		id = "iron_helmet",
		name = "Iron Helmet",
		description = "Reinforced iron helmet",
		category = "armor",
		slots = { "helmet" },
		stat_modifiers = {
			protection = 1,
		},
		actions = {},
	},
	{
		id = "leather_boots",
		name = "Leather Boots",
		description = "Worn but serviceable boots",
		category = "armor",
		slots = { "boots" },
		stat_modifiers = {
			defense = 1,
		},
		actions = {},
	},
}

local item_index, errors = Item.build_index(item_definitions)

return {
	list = item_definitions,
	by_id = item_index,
	errors = errors,
}
