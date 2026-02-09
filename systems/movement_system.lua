-- systems/movement_system.lua
-- Handle actor position, velocity, and pathfinding

local MovementSystem = {}

function MovementSystem.updatePosition(actor, dt)
    if actor.velocity then
        actor.x = (actor.x or 0) + actor.velocity.x * dt
        actor.y = (actor.y or 0) + actor.velocity.y * dt
    end
end

function MovementSystem.setVelocity(actor, vx, vy)
    actor.velocity = {x = vx, y = vy}
end

function MovementSystem.stop(actor)
    actor.velocity = {x = 0, y = 0}
end

return MovementSystem
