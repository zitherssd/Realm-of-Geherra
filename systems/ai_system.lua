-- systems/ai_system.lua
--
-- System for controlling AI party behavior.

local Math = require("util.math")

local AISystem = {}

local function random_direction()
	local angle = love.math.random() * math.pi * 2
	return math.cos(angle), math.sin(angle)
end

function AISystem.update(parties, dt, world)
	for _, party in ipairs(parties) do
		if not party.is_player then
			party.ai = party.ai or {
				timer = 0,
				dir = { x = 0, y = 0 },
			}

			party.ai.timer = party.ai.timer - dt
			if party.ai.timer <= 0 then
				local dx, dy = random_direction()
				party.ai.dir.x = dx
				party.ai.dir.y = dy
				party.ai.timer = love.math.random(2, 6)
			end

			local edge_buffer = 120
			if party.position.x < edge_buffer then
				party.ai.dir.x = math.abs(party.ai.dir.x)
			elseif party.position.x > world.width - edge_buffer then
				party.ai.dir.x = -math.abs(party.ai.dir.x)
			end

			if party.position.y < edge_buffer then
				party.ai.dir.y = math.abs(party.ai.dir.y)
			elseif party.position.y > world.height - edge_buffer then
				party.ai.dir.y = -math.abs(party.ai.dir.y)
			end

			local nx, ny = Math.normalize(party.ai.dir.x, party.ai.dir.y)
			party.velocity = party.velocity or { x = 0, y = 0 }
			party.velocity.x = nx
			party.velocity.y = ny
		end
	end
end

return AISystem
