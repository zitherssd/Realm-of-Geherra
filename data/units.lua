-- data/units.lua
--
-- Data for all unit types.

local Unit = require("core.unit")

local unit_definitions = {
	{
		id = "human_infantry",
		name = "Infantry",
		description = "Basic human foot soldier",
		size = 3,
		combat_speed = 13,
		sprite = {
			image = "sprites/units/infantry.png",
			scale = 1.0,
			offset = { x = 0, y = 0 },
		},
		stats = {
			hp = 30,
			attack = 10,
			defense = 8,
			strength = 9,
			protection = 5,
		},
		equipment_slots = {
			helmet = { type = "head" },
			armor = { type = "body" },
			boots = { type = "feet" },
			mainhand = { type = "weapon" },
			offhand = { type = "weapon" },
		},
		starting_equipment = {
			mainhand = "iron_spear",
		},
		actions = {},
	},
	{
		id = "human_swordsman",
		name = "Swordsman",
		description = "Trained human warrior with a blade",
		size = 3,
		combat_speed = 13,
		sprite = {
			image = "sprites/units/swordsman.png",
			scale = 1.0,
			offset = { x = 0, y = 0 },
		},
		stats = {
			hp = 34,
			attack = 11,
			defense = 9,
			strength = 10,
			protection = 6,
		},
		equipment_slots = {
			helmet = { type = "head" },
			armor = { type = "body" },
			boots = { type = "feet" },
			mainhand = { type = "weapon" },
			offhand = { type = "weapon" },
		},
		starting_equipment = {
			mainhand = "iron_sword",
		},
		actions = {},
	},
	{
		id = "forest_wolf",
		name = "Forest Wolf",
		description = "Fast predator with a vicious bite",
		size = 3,
		combat_speed = 16,
		sprite = {
			image = "sprites/units/forest_wolf.png",
			scale = 1.0,
			offset = { x = 0, y = 0 },
		},
		stats = {
			hp = 26,
			attack = 9,
			defense = 10,
			strength = 8,
			protection = 3,
		},
		equipment_slots = {},
		actions = {
			"bite",
		},
	},
	{
		id = "cave_bear",
		name = "Cave Bear",
		description = "Massive beast with crushing power",
		size = 5,
		combat_speed = 10,
		sprite = {
			image = "sprites/units/cave_bear.png",
			scale = 1.0,
			offset = { x = 0, y = 0 },
		},
		stats = {
			hp = 45,
			attack = 12,
			defense = 6,
			strength = 14,
			protection = 7,
		},
		equipment_slots = {},
		actions = {
			"claw_attack",
		},
	},
	{
		id = "human_commander",
		name = "Commander",
		description = "Veteran leader with battlefield authority",
		size = 3,
		combat_speed = 13,
		sprite = {
			image = "sprites/units/commander.png",
			scale = 1.0,
			offset = { x = 0, y = 0 },
		},
		stats = {
			hp = 38,
			attack = 12,
			defense = 10,
			strength = 11,
			protection = 7,
		},
		equipment_slots = {
			helmet = { type = "head" },
			armor = { type = "body" },
			boots = { type = "feet" },
			mainhand = { type = "weapon" },
			offhand = { type = "weapon" },
			accessory = { type = "trinket" },
		},
		starting_equipment = {
			mainhand = "iron_sword",
		},
		actions = {
		},
	},
}

local unit_index, errors = Unit.build_index(unit_definitions)

return {
	list = unit_definitions,
	by_id = unit_index,
	errors = errors,
}
