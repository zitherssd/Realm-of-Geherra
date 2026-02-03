-- scenes/battle_scene.lua
--
-- Manages the tactical battle scene.

local BattleSystem = require("battle.battle_system")
local BattleCamera = require("battle.battle_camera")
local BattleRenderer = require("battle.battle_renderer")
local BattleAI = require("battle.battle_ai")
local BattleActions = require("battle.battle_actions")
local BattleInput = require("battle.battle_input")
local UnitData = require("data.units")

local BattleScene = {}
BattleScene.__index = BattleScene

function BattleScene.new(game, return_scene, config)
	local self = setmetatable({}, BattleScene)
	self.game = game
	self.return_scene = return_scene
	self.state = BattleSystem.create_state(config or {})
	self.tick_timer = 0
	self.tick_duration = 0.2
	self.camera = BattleCamera.new()
	self.selected_action_index = 1
	self.targeting = false
	self.target_cursor = nil
	self.player_actions = {}
	self:initialize_units(config or {})
	return self
end

function BattleScene:initialize_units(config)
	local units = {}
	local player_party = nil
	for _, party in ipairs(config.parties or {}) do
		if party.is_player then
			player_party = party
		end
	end

	local function add_unit_instance(unit_def, party, team, index)
		local instance = {
			id = party.id .. "_" .. unit_def.id .. "_" .. index,
			name = unit_def.name,
			unit_type = unit_def.id,
			team = team,
			size = unit_def.size or 1,
			base_stats = unit_def.stats,
			current_hp = unit_def.stats.hp,
			actions = unit_def.actions or {},
			items = {},
			status_effects = {},
			cooldown = 0,
			sprite = unit_def.sprite,
		}
		table.insert(units, instance)
		return instance
	end

	for _, party in ipairs(config.parties or {}) do
		local team = party.is_player and "player" or "enemy"
		local index = 1
		for _, commander_id in ipairs(party.commanders or {}) do
			local def = UnitData.by_id[commander_id]
			if def then
				add_unit_instance(def, party, team, index)
				index = index + 1
			end
		end
		for _, unit_id in ipairs(party.units or {}) do
			local def = UnitData.by_id[unit_id]
			if def then
				add_unit_instance(def, party, team, index)
				index = index + 1
			end
		end
	end

	self.state.units = units

	local player_unit_id = nil
	if player_party and #player_party.commanders > 0 then
		player_unit_id = player_party.id .. "_" .. player_party.commanders[1] .. "_1"
	elseif units[1] then
		player_unit_id = units[1].id
	end
	self.state.player_unit_id = player_unit_id

	self:deploy_units()
	self:refresh_player_actions()
end

function BattleScene:deploy_units()
	local grid = self.state.grid
	local player_x = 1
	local enemy_x = self.state.width
	local player_row = 2
	local enemy_row = 2

	for _, unit in ipairs(self.state.units) do
		if unit.team == "player" then
			local placed = BattleSystem.place_unit(grid, unit, player_x, player_row)
			if not placed then
				player_row = player_row + 1
				BattleSystem.place_unit(grid, unit, player_x, player_row)
			else
				player_row = player_row + 1
			end
		else
			local placed = BattleSystem.place_unit(grid, unit, enemy_x, enemy_row)
			if not placed then
				enemy_row = enemy_row + 1
				BattleSystem.place_unit(grid, unit, enemy_x, enemy_row)
			else
				enemy_row = enemy_row + 1
			end
		end
	end
end

function BattleScene:refresh_player_actions()
	local player = self.state:get_player_unit()
	if not player then
		self.player_actions = {}
		return
	end
	self.player_actions = BattleActions.unit_actions(player)
	if self.selected_action_index > #self.player_actions then
		self.selected_action_index = 1
	end
end

function BattleScene:player_can_act()
	local player = self.state:get_player_unit()
	if not player then
		return false
	end
	return (player.cooldown or 0) <= 0
end

function BattleScene:update(dt)
	local player = self.state:get_player_unit()
	if player then
		BattleCamera.update(
			self.camera,
			(player.position.x - 0.5) * self.state.cell_size,
			(player.position.y - 0.5) * self.state.cell_size,
			self.state.width,
			self.state.height,
			self.state.cell_size,
			dt
		)
	end

	if self:player_can_act() then
		return
	end

	self.tick_timer = self.tick_timer + dt
	while self.tick_timer >= self.tick_duration do
		self.tick_timer = self.tick_timer - self.tick_duration
		BattleSystem.update_ticks(self.state, 1)
		for _, unit in ipairs(self.state.units) do
			if (unit.cooldown or 0) > 0 then
				unit.cooldown = unit.cooldown - 1
			end
		end
		BattleActions.execute_pending(self.state)
		BattleAI.update(self.state)
	end
end

function BattleScene:draw()
	love.graphics.clear(0.08, 0.06, 0.08)

	BattleRenderer.draw_grid(self.state, self.camera)
	BattleRenderer.draw_units(self.state, self.camera)
	if self.targeting then
		BattleRenderer.draw_target_cursor(self.state, self.camera, self.target_cursor)
	end

	local player = self.state:get_player_unit()
	local info_y = 16
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Battle", 16, info_y)
	info_y = info_y + 20
	if player then
		love.graphics.print("Player HP: " .. tostring(player.current_hp), 16, info_y)
		info_y = info_y + 20
	end
	if #self.player_actions > 0 then
		local action_id = self.player_actions[self.selected_action_index]
		local action = BattleActions.get_action(action_id)
		love.graphics.print("Action: " .. (action and action.name or action_id), 16, info_y)
	end
end

function BattleScene:keypressed(key)
	if key == "escape" then
		if self.return_scene then
			self.game:change_scene(self.return_scene)
		end
		return
	end

	local player = self.state:get_player_unit()
	if not player then
		return
	end

	if self.targeting then
		if key == "up" then
			self.target_cursor.y = math.max(1, self.target_cursor.y - 1)
		elseif key == "down" then
			self.target_cursor.y = math.min(self.state.height, self.target_cursor.y + 1)
		elseif key == "left" then
			self.target_cursor.x = math.max(1, self.target_cursor.x - 1)
		elseif key == "right" then
			self.target_cursor.x = math.min(self.state.width, self.target_cursor.x + 1)
		elseif key == "return" or key == "enter" then
			local action_id = self.player_actions[self.selected_action_index]
			local action = BattleActions.get_action(action_id)
			if action then
				local target = nil
				if action.targeting.type == "unit" then
					target = BattleActions.find_unit_at(self.state, self.target_cursor.x, self.target_cursor.y)
				elseif action.targeting.type == "cell" then
					target = { x = self.target_cursor.x, y = self.target_cursor.y }
				end
				if BattleActions.validate_target(self.state, action, player, target) then
					BattleActions.queue_action(self.state, player, action, target)
					self.targeting = false
					self.target_cursor = nil
				end
			end
		elseif key == "escape" then
			self.targeting = false
			self.target_cursor = nil
		end
		return
	end

	if not self:player_can_act() then
		return
	end

	if key == "q" then
		self.selected_action_index = self.selected_action_index - 1
		if self.selected_action_index < 1 then
			self.selected_action_index = #self.player_actions
		end
	elseif key == "e" then
		self.selected_action_index = self.selected_action_index + 1
		if self.selected_action_index > #self.player_actions then
			self.selected_action_index = 1
		end
	elseif key == "w" or key == "up" then
		BattleInput.move_player(self.state, player, 0, -1)
	elseif key == "s" or key == "down" then
		BattleInput.move_player(self.state, player, 0, 1)
	elseif key == "a" or key == "left" then
		BattleInput.move_player(self.state, player, -1, 0)
	elseif key == "d" or key == "right" then
		BattleInput.move_player(self.state, player, 1, 0)
	elseif key == "return" or key == "enter" then
		local action_id = self.player_actions[self.selected_action_index]
		local action = BattleActions.get_action(action_id)
		if action then
			if action.targeting.type == "self" then
				BattleActions.queue_action(self.state, player, action, player)
			else
				self.targeting = true
				self.target_cursor = { x = player.position.x, y = player.position.y }
			end
		end
	end
end

return BattleScene
