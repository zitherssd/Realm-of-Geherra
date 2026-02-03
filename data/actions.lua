-- data/actions.lua
--
-- Data for all battle actions.

local Action = require("core.action")

local action_definitions = {
	{
		action_id = "move_step",
		name = "Step",
		description = "Move to an adjacent cell.",
		tags = { "move" },
		windup_ticks = 0,
		cooldown_ticks = 1,
		targeting = {
			type = "cell",
			range = 1,
		},
		execution = {
			effects = {
				{ type = "move" },
			},
		},
	},
	{
		action_id = "melee_slash",
		name = "Melee Slash",
		description = "A quick slash at close range.",
		tags = { "melee" },
		windup_ticks = 2,
		cooldown_ticks = 3,
		targeting = {
			type = "unit",
			range = 1,
		},
		execution = {
			effects = {
				{ type = "damage", stat = "attack", formula = "attack + strength", damage_bonus = 2 },
			},
		},
	},
	{
		action_id = "thrust",
		name = "Spear Thrust",
		description = "A piercing strike with a spear.",
		tags = { "melee" },
		windup_ticks = 1,
		cooldown_ticks = 3,
		targeting = {
			type = "unit",
			range = 1,
		},
		execution = {
			effects = {
				{ type = "damage", stat = "attack", formula = "attack + strength", damage_bonus = 1 },
			},
		},
	},
	{
		action_id = "bite",
		name = "Bite",
		description = "A vicious bite.",
		tags = { "melee" },
		windup_ticks = 1,
		cooldown_ticks = 2,
		targeting = {
			type = "unit",
			range = 1,
		},
		execution = {
			effects = {
				{ type = "damage", stat = "attack", formula = "attack + strength", damage_bonus = 0 },
			},
		},
	},
	{
		action_id = "claw_attack",
		name = "Claw Attack",
		description = "Rending claws rake the target.",
		tags = { "melee" },
		windup_ticks = 2,
		cooldown_ticks = 3,
		targeting = {
			type = "unit",
			range = 1,
		},
		execution = {
			effects = {
				{ type = "damage", stat = "attack", formula = "attack + strength", damage_bonus = 0 },
			},
		},
	},
	{
		action_id = "rally",
		name = "Rally",
		description = "Bolster nearby allies.",
		tags = { "support" },
		windup_ticks = 1,
		cooldown_ticks = 4,
		targeting = {
			type = "self",
			range = 0,
		},
		execution = {
			effects = {
				{ type = "status", stat = "morale", formula = "5" },
			},
		},
	},
	{
		action_id = "arrow_shot",
		name = "Arrow Shot",
		description = "Loose a ranged shot.",
		tags = { "ranged" },
		windup_ticks = 3,
		cooldown_ticks = 4,
		targeting = {
			type = "unit",
			range = 6,
		},
		execution = {
			effects = {
				{ type = "damage", stat = "attack", formula = "attack", damage_bonus = 0 },
			},
		},
	},
	{
		action_id = "fireball",
		name = "Fireball",
		description = "Explosive magical blast.",
		tags = { "magic" },
		windup_ticks = 4,
		cooldown_ticks = 5,
		targeting = {
			type = "cell",
			range = 6,
		},
		execution = {
			aoe = {
				pattern = "radius",
				params = {
					radius = 2,
				},
			},
			effects = {
				{ type = "damage", stat = "magic", formula = "magic * 1.5" },
			},
		},
	},
}

local action_index, errors = Action.build_index(action_definitions)

return {
	list = action_definitions,
	by_id = action_index,
	errors = errors,
}
