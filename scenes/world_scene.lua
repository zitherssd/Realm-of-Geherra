-- scenes/world_scene.lua
--
-- Manages the main world map scene.

local WorldGenerator = require("systems.world_generator")
local MovementSystem = require("systems.movement_system")
local AISystem = require("systems.ai_system")
local BattleScene = require("scenes.battle_scene")
local Math = require("util.math")
local LocationData = require("data.locations")
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
local function new_party(id, name, x, y, color, is_player)
	return {
		id = id,
		name = name,
		position = { x = x, y = y },
		velocity = { x = 0, y = 0 },
		speed = is_player and 180 or 120,
		radius = is_player and 14 or 11,
		color = color,
		is_player = is_player or false,
	}
end

function WorldScene.new(game)
	local self = setmetatable({}, WorldScene)
	self.game = game
	self.world = WorldGenerator.generate(love.math.random(1, 9999), 2048, 2048)

	self.player_party = new_party("player_party", "Player", self.world.width * 0.5, self.world.height * 0.5, { 0.95, 0.9, 0.2 }, true)
	self.parties = {
		self.player_party,
		new_party("ai_patrol_1", "Patrol", self.world.width * 0.35, self.world.height * 0.45, { 0.85, 0.3, 0.3 }, false),
		new_party("ai_patrol_2", "Patrol", self.world.width * 0.65, self.world.height * 0.4, { 0.3, 0.7, 0.9 }, false),
		new_party("ai_raiders", "Raiders", self.world.width * 0.55, self.world.height * 0.62, { 0.8, 0.4, 0.75 }, false),
	}

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
	if self.encounter then
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

	if vx ~= 0 or vy ~= 0 then
		self.time:advance(dt)
	end

	AISystem.update(self.parties, dt, self.world)
	MovementSystem.update(self.parties, dt, self.world)

	local cam_speed = math.min(dt * 5, 1)
	self.camera.x = Math.lerp(self.camera.x, self.player_party.position.x, cam_speed)
	self.camera.y = Math.lerp(self.camera.y, self.player_party.position.y, cam_speed)

	local view_w = love.graphics.getWidth() / self.camera.zoom
	local view_h = love.graphics.getHeight() / self.camera.zoom
	self.camera.x = Math.clamp(self.camera.x, view_w * 0.5, self.world.width - view_w * 0.5)
	self.camera.y = Math.clamp(self.camera.y, view_h * 0.5, self.world.height - view_h * 0.5)

	self:check_encounters()
end

function WorldScene:check_encounters()
	local encounter = EncounterSystem.detect(self.player_party, self.parties, self.locations, self.world)
	if encounter then
		encounter.options = InteractionSystem.build_interactions(encounter)
		self.encounter = encounter
		self.encounter_selection = 1
	end
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
	local title = self.encounter.type == "party" and ("Encounter: " .. self.encounter.target.name) or ("Location: " .. self.encounter.target.name)
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
end

function WorldScene:keypressed(key)
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
				if result and result.transition and result.transition.scene == "battle" then
					self.game:change_scene(BattleScene.new(self.game, self))
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
		self.time:advance_hours(6)
	elseif key == "escape" then
		self.game:change_scene(require("scenes.title_scene").new(self.game))
	end
end

return WorldScene
