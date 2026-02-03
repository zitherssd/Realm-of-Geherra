-- systems/movement_system.lua
--
-- System for handling party movement on the world map.

local Math = require("util.math")

local MovementSystem = {}

function MovementSystem.update_party(party, dt, world)
	if not party.velocity then
		return
	end

	local vx, vy = party.velocity.x or 0, party.velocity.y or 0
	if vx == 0 and vy == 0 then
		return
	end

	local speed = party.speed or 0
	local nx, ny = Math.normalize(vx, vy)
	party.position.x = party.position.x + nx * speed * dt
	party.position.y = party.position.y + ny * speed * dt

	party.position.x = Math.clamp(party.position.x, 0, world.width)
	party.position.y = Math.clamp(party.position.y, 0, world.height)
end

function MovementSystem.update(parties, dt, world)
	for _, party in ipairs(parties) do
		MovementSystem.update_party(party, dt, world)
	end
end

return MovementSystem
