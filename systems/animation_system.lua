-- systems/animation_system.lua
-- Handle sprite and model animation

local AnimationSystem = {}

function AnimationSystem.playAnimation(actor, animationName)
    if not actor.animation then
        actor.animation = {}
    end
    actor.animation.current = animationName
    actor.animation.elapsed = 0
end

function AnimationSystem.updateAnimation(actor, dt)
    if not actor.animation or not actor.animation.current then return end
    
    actor.animation.elapsed = (actor.animation.elapsed or 0) + dt
end

function AnimationSystem.getCurrentFrame(actor)
    if not actor.animation then return 0 end
    return actor.animation.current
end

return AnimationSystem
