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
local ItemData = require("data.items")
local StatSystem = require("systems.stat_system")

local BattleScene = {}
BattleScene.__index = BattleScene

function BattleScene.new(game, return_scene, config)
	local self = setmetatable({}, BattleScene)
	self.game = game
	self.return_scene = return_scene
	self.state = BattleSystem.create_state(config or {})
	self.tick_timer = 0
	self.tick_duration = 1 / 20
	self.camera = BattleCamera.new()
	self.selected_action_index = 1
	self.targeting = false
	self.target_cursor = nil
	self.player_actions = {}
	self.damage_popups = {}
	self:initialize_units(config or {})
	return self
end

function BattleScene:consume_damage_events()
	for _, event in ipairs(self.state.damage_events) do
		local unit = event.target
		local world_x = (unit.position.x - 0.5) * self.state.cell_size
		local world_y = (unit.position.y - 0.5) * self.state.cell_size
		table.insert(self.damage_popups, {
			amount = event.amount,
			x = world_x,
			y = world_y,
			age = 0,
			alpha = 1,
		})
	end
	self.state.damage_events = {}
end

function BattleScene:update_popups(dt)
	local remaining = {}
	for _, popup in ipairs(self.damage_popups) do
		popup.age = popup.age + dt
		popup.y = popup.y - (20 * dt)
		popup.alpha = math.max(0, 1 - (popup.age / 0.8))
		if popup.alpha > 0 then
			table.insert(remaining, popup)
		end
	end
	self.damage_popups = remaining
end

function BattleScene:initialize_units(config)
	local units = {}
	local player_party = nil
	for _, party in ipairs(config.parties or {}) do
		if party.is_player then
			player_party = party
		end
	end

	local function build_item_list(equipment)
		local items = {}
		local seen = {}
		for _, item_id in pairs(equipment or {}) do
			if item_id and not seen[item_id] then
				local item = ItemData.by_id[item_id]
				if item then
					seen[item_id] = true
					table.insert(items, item)
				end
			end
		end
		return items
	end


	local function add_unit_instance(unit_def, party, team, index, is_commander)
		local equipment = unit_def.starting_equipment or {}
		if party.is_player and is_commander then
			local party_equipment = party.equipment
			if party_equipment and next(party_equipment) ~= nil then
				equipment = party_equipment
			end
		end
		local items = build_item_list(equipment)
		local actions = StatSystem.aggregate_actions(unit_def, items)
		local max_hp = StatSystem.get_max_hp(unit_def.stats, items, {})
		party.unit_states = party.unit_states or {}
		local state_id = party.id .. "_" .. unit_def.id .. "_" .. index
		local state_entry = party.unit_states[state_id]
		if not state_entry then
			state_entry = { current_hp = max_hp }
			party.unit_states[state_id] = state_entry
		end

		local instance = {
			id = state_id,
			name = unit_def.name,
			unit_type = unit_def.id,
			team = team,
			size = unit_def.size or 1,
			combat_speed = unit_def.combat_speed or 13,
			base_stats = unit_def.stats,
			max_hp = max_hp,
			current_hp = state_entry.current_hp,
			actions = actions,
			items = items,
			status_effects = {},
			cooldown = 0,
			sprite = unit_def.sprite,
			party_state = state_entry,
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
				add_unit_instance(def, party, team, index, true)
				index = index + 1
			end
		end
		for _, unit_id in ipairs(party.units or {}) do
			local def = UnitData.by_id[unit_id]
			if def then
				add_unit_instance(def, party, team, index, false)
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

function BattleScene:draw_action_list()
	local width = love.graphics.getWidth()
	local start_x = width - 220
	local start_y = 16

	for index, action_id in ipairs(self.player_actions) do
		local action = BattleActions.get_action(action_id)
		local label = action and action.name or action_id
		local y = start_y + (index - 1) * 20
		if index == self.selected_action_index then
			love.graphics.setColor(0.95, 0.9, 0.2)
			love.graphics.rectangle("fill", start_x - 8, y - 2, 200, 18, 4, 4)
			love.graphics.setColor(0.1, 0.1, 0.1)
			love.graphics.print(label, start_x, y)
		else
			love.graphics.setColor(0.9, 0.9, 0.9)
			love.graphics.print(label, start_x, y)
		end
	end
end

function BattleScene:attempt_melee_action()
	local player = self.state:get_player_unit()
	if not player then
		return
	end

	local action_id = self.player_actions[self.selected_action_index]
	local action = BattleActions.get_action(action_id)
	if not action then
		return
	end

	if action.targeting.type ~= "unit" then
		return
	end

	local best_target = nil
	local best_dist = math.huge
	for _, unit in ipairs(self.state.units) do
		if unit.team ~= player.team and (unit.current_hp or 0) > 0 then
			local dist = math.abs(unit.position.x - player.position.x) + math.abs(unit.position.y - player.position.y)
			if dist <= action.targeting.range and dist < best_dist then
				best_target = unit
				best_dist = dist
			end
		end
	end

	if best_target and BattleActions.validate_target(self.state, action, player, best_target) then
		BattleActions.queue_action(self.state, player, action, best_target)
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
		self:update_popups(dt)
		for _, unit in ipairs(self.state.units) do
			if unit.hit_flash_timer and unit.hit_flash_timer > 0 then
				unit.hit_flash_timer = math.max(0, unit.hit_flash_timer - dt)
			end
		end
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
		self:consume_damage_events()
		BattleAI.update(self.state)
	end

	self:update_popups(dt)
	for _, unit in ipairs(self.state.units) do
		if unit.hit_flash_timer and unit.hit_flash_timer > 0 then
			unit.hit_flash_timer = math.max(0, unit.hit_flash_timer - dt)
		end
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
		love.graphics.print("Player HP: " .. tostring(player.current_hp) .. "/" .. tostring(player.max_hp), 16, info_y)
		info_y = info_y + 20
	end
	love.graphics.print("Tick: " .. tostring(self.state.tick), 16, info_y)
	info_y = info_y + 20
	if #self.player_actions > 0 then
		local action_id = self.player_actions[self.selected_action_index]
		local action = BattleActions.get_action(action_id)
		love.graphics.print("Action: " .. (action and action.name or action_id), 16, info_y)
	end

	self:draw_action_list()
	self:draw_damage_popups()
end

function BattleScene:draw_damage_popups()
	for _, popup in ipairs(self.damage_popups) do
		local sx, sy = BattleCamera.world_to_screen(self.camera, popup.x, popup.y)
		love.graphics.setColor(1, 0.3, 0.3, popup.alpha)
		love.graphics.print("-" .. tostring(popup.amount), sx - 6, sy - 20)
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

	if key == "tab" then
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
	elseif key == "return" or key == "enter" or key == "space" then
		self:attempt_melee_action()
	end
end

return BattleScene
