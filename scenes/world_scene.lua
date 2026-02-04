-- scenes/world_scene.lua
--
-- Manages the main world map scene.

local WorldGenerator = require("systems.world_generator")
local MovementSystem = require("systems.movement_system")
 local PartyAISystem = require("systems.party_ai_system")
local BattleScene = require("scenes.battle_scene")
local Math = require("util.math")
local LocationData = require("data.locations")
local PartyData = require("data.parties")
local ItemData = require("data.items")
local UnitData = require("data.units")
local InventoryView = require("ui.inventory_view")
local Time = require("core.time")
local EncounterSystem = require("systems.encounter_system")
local InteractionSystem = require("systems.interaction_system")

local WorldScene = {}
WorldScene.__index = WorldScene

local REGION_COLORS = {
	water = { 0.12, 0.22, 0.48 },
	plains = { 0.2, 0.55, 0.25 },
	forest = { 0.1, 0.4, 0.16 },
	mountain = { 0.55, 0.55, 0.6 },
}
local function hydrate_party(definition)
	return {
		id = definition.id,
		name = definition.name,
		faction = definition.faction,
		position = { x = definition.position.x, y = definition.position.y },
		velocity = { x = 0, y = 0 },
		speed = definition.speed,
		radius = definition.radius or (definition.is_player and 14 or 11),
		color = definition.color or (definition.is_player and { 0.95, 0.9, 0.2 } or { 0.7, 0.7, 0.7 }),
		is_player = definition.is_player or false,
		commanders = definition.commanders or {},
		units = definition.units or {},
		inventory = definition.inventory or {},
		gold = definition.gold or 0,
	}
end

local function build_battle_config(world, encounter, player_party)
	local config = {
		parties = { player_party },
		deployment = {},
		stage = "field_stage",
	}

	if encounter and encounter.type == "party" then
		table.insert(config.parties, encounter.target)
		local sample = world:sample(player_party.position.x, player_party.position.y)
		config.stage = (sample.region or "field") .. "_stage"
	elseif encounter and encounter.type == "location" then
		config.stage = (encounter.target.data and encounter.target.data.battle_stage) or "field_stage"
	end

	return config
end

function WorldScene.new(game)
	local self = setmetatable({}, WorldScene)
	self.game = game
	self.world = WorldGenerator.generate(love.math.random(1, 9999), 2048, 2048)

	self.parties = {}
	for _, party in ipairs(PartyData.list or {}) do
		local instance = hydrate_party(party)
		if instance.is_player then
			self.player_party = instance
		end
		table.insert(self.parties, instance)
	end
	if not self.player_party then
		self.player_party = hydrate_party({
			id = "player_party",
			name = "Player",
			position = { x = self.world.width * 0.5, y = self.world.height * 0.5 },
			speed = 180,
			is_player = true,
		})
		table.insert(self.parties, 1, self.player_party)
	end

	self.locations = {}
	for _, location in ipairs(LocationData.list or {}) do
		local radius = 22
		if location.type == "town" then
			radius = 28
		elseif location.type == "village" then
			radius = 24
		end
		table.insert(self.locations, {
			id = location.id,
			name = location.name,
			type = location.type,
			position = { x = location.position.x, y = location.position.y },
			radius = radius,
			data = location,
		})
	end

	self.camera = {
		x = self.player_party.position.x,
		y = self.player_party.position.y,
		zoom = 1.0,
	}

	self.encounter = nil
	self.encounter_selection = 1
	self.active_view = nil
	self.view_return_encounter = nil
	self.inventory_view = nil
	self.resting = false
	self.encounter_cooldowns = {}
	self.time = Time.new(18)

	return self
end

local function world_to_screen(camera, world_x, world_y)
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	local screen_x = (world_x - camera.x) * camera.zoom + width * 0.5
	local screen_y = (world_y - camera.y) * camera.zoom + height * 0.5
	return screen_x, screen_y
end

function WorldScene:update(dt)
	for target_id, remaining in pairs(self.encounter_cooldowns) do
		local updated = remaining - dt
		if updated <= 0 then
			self.encounter_cooldowns[target_id] = nil
		else
			self.encounter_cooldowns[target_id] = updated
		end
	end

	if self.encounter or self.active_view then
		return
	end

	local vx, vy = 0, 0
	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
		vy = vy - 1
	end
	if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
		vy = vy + 1
	end
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
		vx = vx - 1
	end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
		vx = vx + 1
	end

	self.player_party.velocity.x = vx
	self.player_party.velocity.y = vy

	local player_moving = (vx ~= 0 or vy ~= 0)
	MovementSystem.update_party(self.player_party, dt, self.world)
	if self.resting and player_moving then
		self.resting = false
	end
	local time_advancing = player_moving or self.resting
	if time_advancing then
		self.time:advance(dt)
		PartyAISystem.update(self.parties, dt, self.world)
		for _, party in ipairs(self.parties) do
			if not party.is_player then
				MovementSystem.update_party(party, dt, self.world)
			end
		end
	else
		for _, party in ipairs(self.parties) do
			if not party.is_player and party.velocity then
				party.velocity.x = 0
				party.velocity.y = 0
			end
		end
	end

	local cam_speed = math.min(dt * 5, 1)
	self.camera.x = Math.lerp(self.camera.x, self.player_party.position.x, cam_speed)
	self.camera.y = Math.lerp(self.camera.y, self.player_party.position.y, cam_speed)

	local view_w = love.graphics.getWidth() / self.camera.zoom
	local view_h = love.graphics.getHeight() / self.camera.zoom
	self.camera.x = Math.clamp(self.camera.x, view_w * 0.5, self.world.width - view_w * 0.5)
	self.camera.y = Math.clamp(self.camera.y, view_h * 0.5, self.world.height - view_h * 0.5)

	if not self.resting then
		self:check_encounters()
	end
end

function WorldScene:check_encounters()
	local encounter = EncounterSystem.detect(self.player_party, self.parties, self.locations, self.world)
	if encounter then
		local target_id = encounter.target and encounter.target.id
		if target_id and self.encounter_cooldowns[target_id] then
			return
		end
		encounter.options = InteractionSystem.build_interactions(encounter)
		self.encounter = encounter
		self.encounter_selection = 1
	end
end

function WorldScene:open_camp_menu()
	self.encounter = {
		type = "camp",
		target = self.player_party,
		options = InteractionSystem.build_interactions({ type = "camp", target = self.player_party }),
	}
	self.encounter_selection = 1
end

function WorldScene:draw_terrain()
	local cell_size = 48
	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()
	local view_w = width / self.camera.zoom
	local view_h = height / self.camera.zoom

	local start_x = math.floor((self.camera.x - view_w * 0.5) / cell_size) * cell_size
	local start_y = math.floor((self.camera.y - view_h * 0.5) / cell_size) * cell_size
	local end_x = self.camera.x + view_w * 0.5
	local end_y = self.camera.y + view_h * 0.5

	for y = start_y, end_y, cell_size do
		for x = start_x, end_x, cell_size do
			local sample = self.world:sample(x, y)
			local color = REGION_COLORS[sample.region] or { 0.2, 0.2, 0.2 }
			love.graphics.setColor(color)
			local screen_x, screen_y = world_to_screen(self.camera, x, y)
			love.graphics.rectangle("fill", screen_x, screen_y, cell_size * self.camera.zoom, cell_size * self.camera.zoom)
		end
	end
end

function WorldScene:draw_locations()
	for _, location in ipairs(self.locations) do
		local screen_x, screen_y = world_to_screen(self.camera, location.position.x, location.position.y)
		local radius = location.radius * self.camera.zoom

		love.graphics.setColor(0.95, 0.85, 0.6)
		love.graphics.circle("fill", screen_x, screen_y, radius)
		love.graphics.setColor(0.15, 0.1, 0.05)
		love.graphics.circle("line", screen_x, screen_y, radius)
		love.graphics.print(location.name, screen_x + radius + 6, screen_y - 6)
	end
end

function WorldScene:draw_parties()
	for _, party in ipairs(self.parties) do
		local screen_x, screen_y = world_to_screen(self.camera, party.position.x, party.position.y)
		local radius = party.radius * self.camera.zoom
		love.graphics.setColor(party.color)
		love.graphics.circle("fill", screen_x, screen_y, radius)
		if party.is_player then
			love.graphics.setColor(1, 1, 1)
			love.graphics.circle("line", screen_x, screen_y, radius + 4)
		end
	end
end

function WorldScene:draw_ui()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("World Map", 16, 16)
	local hour = self.time:get_hour()
	local day = self.time:get_day()
	love.graphics.print("Day " .. day .. " - " .. self.time:get_period_label(), 16, 36)
	love.graphics.print("Hour: " .. string.format("%.1f", hour), 16, 56)
	love.graphics.print("Zoom: " .. string.format("%.2f", self.camera.zoom), 16, 76)
	if self.resting then
		love.graphics.print("Resting... (move or Esc to stop)", 16, 96)
	end
end

function WorldScene:draw_inventory_view()
	if self.inventory_view then
		self.inventory_view:draw()
	end
end

function WorldScene:draw_encounter()
	if not self.encounter then
		return
	end

	local width = love.graphics.getWidth()
	local height = love.graphics.getHeight()

	love.graphics.setColor(0, 0, 0, 0.6)
	love.graphics.rectangle("fill", 0, height * 0.65, width, height * 0.35)

	love.graphics.setColor(1, 1, 1)
	local title
	if self.encounter.type == "party" then
		title = "Encounter: " .. self.encounter.target.name
	elseif self.encounter.type == "camp" then
		title = "Camp Menu"
	else
		title = "Location: " .. self.encounter.target.name
	end
	love.graphics.print(title, 24, height * 0.68)

	for index, option in ipairs(self.encounter.options) do
		local y = height * 0.72 + (index - 1) * 24
		if index == self.encounter_selection then
			love.graphics.setColor(0.95, 0.9, 0.2)
		else
			love.graphics.setColor(0.9, 0.9, 0.9)
		end
		love.graphics.print(option.label, 36, y)
	end
end

function WorldScene:draw()
	love.graphics.clear(0.08, 0.1, 0.12)

	self:draw_terrain()
	self:draw_locations()
	self:draw_parties()

	local tint_alpha = self.time:get_night_tint_alpha(0.6)
	if tint_alpha > 0 then
		love.graphics.setColor(0.05, 0.08, 0.18, tint_alpha)
		love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	end

	self:draw_ui()
	self:draw_encounter()
	if self.active_view == "inventory" then
		self:draw_inventory_view()
	end
end

function WorldScene:keypressed(key)
	if self.active_view then
		if self.active_view == "inventory" and self.inventory_view then
			local result = self.inventory_view:handle_key(key)
			if result == "close" then
				self.active_view = nil
				self.inventory_view = nil
				if self.view_return_encounter then
					self.encounter = self.view_return_encounter
					self.view_return_encounter = nil
				end
			end
		end
		if key == "escape" then
			self.active_view = nil
			self.inventory_view = nil
			if self.view_return_encounter then
				self.encounter = self.view_return_encounter
				self.view_return_encounter = nil
			end
		end
		return
	end

	if self.encounter then
		if key == "up" or key == "w" then
			self.encounter_selection = self.encounter_selection - 1
			if self.encounter_selection < 1 then
				self.encounter_selection = #self.encounter.options
			end
		elseif key == "down" or key == "s" then
			self.encounter_selection = self.encounter_selection + 1
			if self.encounter_selection > #self.encounter.options then
				self.encounter_selection = 1
			end
		elseif key == "return" or key == "enter" then
			local selected = self.encounter.options[self.encounter_selection]
			if selected then
				local result = InteractionSystem.resolve(selected, { time = self.time })
				if selected.id == "ignore" or selected.id == "leave" then
					local target_id = self.encounter and self.encounter.target and self.encounter.target.id
					if target_id then
						self.encounter_cooldowns[target_id] = 2.0
					end
				end
				if result and result.transition and result.transition.scene == "battle" then
					local config = build_battle_config(self.world, self.encounter, self.player_party)
					self.game:change_scene(BattleScene.new(self.game, self, config))
				end
				if result and result.open_camp then
					self.encounter = nil
					self:open_camp_menu()
					return
				end
				if result and result.open_inventory then
					self.view_return_encounter = self.encounter
					self.encounter = nil
					self.active_view = "inventory"
					local commander_id = self.player_party.commanders and self.player_party.commanders[1]
					local unit_def = commander_id and UnitData.by_id[commander_id] or nil
					if unit_def then
						self.inventory_view = InventoryView.new(self.player_party, unit_def, ItemData)
					end
					return
				end
				if result and result.start_rest then
					self.resting = true
				end
				if not result or result.close_encounter then
					self.encounter = nil
				end
			end
		elseif key == "escape" then
			self.encounter = nil
		end
		return
	end

	if key == "=" or key == "+" then
		self.camera.zoom = Math.clamp(self.camera.zoom + 0.1, 0.6, 2.2)
	elseif key == "-" then
		self.camera.zoom = Math.clamp(self.camera.zoom - 0.1, 0.6, 2.2)
	elseif key == "c" then
		self:open_camp_menu()
	elseif key == "escape" then
		if self.resting then
			self.resting = false
		else
			self.game:change_scene(require("scenes.title_scene").new(self.game))
		end
	end
end

return WorldScene
