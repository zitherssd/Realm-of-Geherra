-- battle/battle_state.lua
--
-- Defines battle state container.

local BattleState = {}
BattleState.__index = BattleState

function BattleState.new(config)
	local self = setmetatable({}, BattleState)
	self.width = config.width
	self.height = config.height
	self.cell_size = config.cell_size
	self.tick = 0
	self.units = config.units or {}
	self.player_unit_id = config.player_unit_id
	self.grid = config.grid
	self.parties = config.parties or {}
	self.stage = config.stage or "field_stage"
	self.deployment = config.deployment or {}
	self.cooldowns = {}
	self.pending_actions = {}
	self.damage_events = {}
	return self
end

function BattleState:get_player_unit()
	for _, unit in ipairs(self.units) do
		if unit.id == self.player_unit_id then
			return unit
		end
	end
	return nil
end

return BattleState
