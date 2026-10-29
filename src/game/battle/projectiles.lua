local Projectile = {
    lateralError = 30, depthError = 30, referenceDistance = 300,
    referencePrecision = 10, launchHeight = 0.90, aimHeight = 0.80,
    speed = 24, arc = 0, radius = 2, maxRange = 1200, maxLifetime = 200,
    sweepStep = 8, nearShooter = 100, meleeDistance = 70, exposureRadius = 80,
}

function Projectile.height(unit)
    return unit.height or (unit.collisionRadius or 18) * (unit.heightMultiplier or 4)
end

function Projectile.aim(unit, x, y, rng)
    rng = rng or math.random
    local dx, dy = x-unit.x, y-unit.y
    local distance = math.sqrt(dx*dx+dy*dy)
    local nx, ny = 1, 0
    if distance > 0 then nx, ny = dx/distance, dy/distance end
    local scale = Projectile.referencePrecision / math.max(1, (unit.stats or {}).precision or 10)
        * distance / Projectile.referenceDistance
    local lateral = (rng()*2-1) * Projectile.lateralError * scale
    local depth = (rng()*2-1) * Projectile.depthError * scale
    return x-ny*lateral+nx*depth, y+nx*lateral+ny*depth
end

function Projectile.launch(unit, skill, x, y, target, rng)
    local config = skill.projectile
    x, y = Projectile.aim(unit, x, y, rng)
    local dx, dy = x-unit.x, y-unit.y
    local distance = math.max(0.001, math.sqrt(dx*dx+dy*dy))
    local z = Projectile.height(unit)*Projectile.launchHeight
    return {x=unit.x, y=unit.y, z=z, startX=unit.x, startY=unit.y, startZ=z,
        visualX=unit.x, visualY=unit.y-z, targetX=x, targetY=y,
        endZ=target and Projectile.height(target)*Projectile.aimHeight or z,
        nx=dx/distance, ny=dy/distance, distance=distance, traveled=0, physicalDistance=0, age=0,
        attackerUnit=unit, skillId=skill.id, skillData=skill, style=config.style, sprite=config.sprite,
        speed=config.speed or Projectile.speed, arc=config.arc or Projectile.arc,
        radius=config.radius or Projectile.radius, maxRange=config.maxRange or Projectile.maxRange,
        maxLifetime=config.maxLifetime or Projectile.maxLifetime, progress=0}
end

function Projectile.position(p, distance)
    local t = distance/p.distance
    return p.startX+p.nx*distance, p.startY+p.ny*distance,
        p.startZ+(p.endZ-p.startZ)*t+4*p.arc*t*(1-t)
end

-- Swept sphere against an upright cylinder (expanded by projectile radius).
function Projectile.intersect(p, x, y, z, unit)
    local dx, dy, dz = x-p.x, y-p.y, z-p.z
    local ox, oy = p.x-unit.x, p.y-unit.y
    local radius = (unit.collisionRadius or 18)+p.radius
    local a, b, c = dx*dx+dy*dy, 2*(ox*dx+oy*dy), ox*ox+oy*oy-radius*radius
    local lo, hi = 0, 1
    if a < 1e-12 then
        if c > 0 then return end
    else
        local d = b*b-4*a*c
        if d < 0 then return end
        lo, hi = math.max(lo,(-b-math.sqrt(d))/(2*a)), math.min(hi,(-b+math.sqrt(d))/(2*a))
    end
    local bottom, top = -p.radius, Projectile.height(unit)+p.radius
    if math.abs(dz) < 1e-12 then
        if p.z < bottom or p.z > top then return end
    else
        local t1, t2 = (bottom-p.z)/dz, (top-p.z)/dz
        lo, hi = math.max(lo,math.min(t1,t2)), math.min(hi,math.max(t1,t2))
    end
    if lo <= hi then return lo end
end

function Projectile.advance(p, context)
    p.age = p.age+1
    local bounds = context.data.bounds or {width=1260,height=546}
    local steps = math.max(1, math.ceil(p.speed/Projectile.sweepStep))
    -- shortcut: piecewise linear sweeps bound arc error to small flight steps; use analytic curves if tuning demands it.
    for _ = 1, steps do
        local travel = p.speed/steps
        local x,y,z = Projectile.position(p,p.traveled+travel)
        local dx,dy,dz = x-p.x,y-p.y,z-p.z
        local length = math.sqrt(dx*dx+dy*dy+dz*dz)
        local stop, reason = 1, nil
        local function limit(t, why)
            if t >= 0 and t <= stop then stop,reason = t,why end
        end
        if z <= 0 and dz < 0 then limit(-p.z/dz,"ground") end
        if x < 0 then limit(-p.x/dx,"bounds") elseif x > bounds.width then limit((bounds.width-p.x)/dx,"bounds") end
        if y < 0 then limit(-p.y/dy,"bounds") elseif y > bounds.height then limit((bounds.height-p.y)/dy,"bounds") end
        if p.physicalDistance+length >= p.maxRange then limit((p.maxRange-p.physicalDistance)/length,"range") end
        local target
        for _, unit in ipairs(context.data.unitList) do
            if not p.visualOnly and (unit ~= p.attackerUnit or p.traveled > (unit.collisionRadius or 18)+p.radius)
                and unit.hp > 0 and not unit.escaped then
                local t = Projectile.intersect(p,x,y,z,unit)
                if t and t < stop then stop,reason,target = t,"unit",unit end
            end
        end
        p.x,p.y,p.z = p.x+dx*stop,p.y+dy*stop,p.z+dz*stop
        p.traveled,p.physicalDistance = p.traveled+travel*stop,p.physicalDistance+length*stop
        p.progress = p.traveled/p.distance
        if reason then return reason,target end
    end
    if p.age >= p.maxLifetime then return "lifetime" end
end

-- Expected path only: nearby launch obstructions veto; melee exposure is a soft cost.
function Projectile.friendlyRisk(unit, target, skill, context)
    local dx,dy = target.x-unit.x,target.y-unit.y
    local distance = math.sqrt(dx*dx+dy*dy)
    if distance < 0.001 then return 0 end
    local risk, arc = 0, skill.projectile.arc or Projectile.arc
    for _, ally in ipairs(context.data.unitList) do
        if ally ~= unit and ally.team == unit.team and ally.hp > 0 and not ally.escaped then
            local t = ((ally.x-unit.x)*dx+(ally.y-unit.y)*dy)/(distance*distance)
            local lateral = math.abs((ally.x-unit.x)*dy-(ally.y-unit.y)*dx)/distance
            if t > 0 and t < 1 and lateral < (ally.collisionRadius or 18)+(skill.projectile.radius or Projectile.radius) then
                local z = Projectile.height(unit)*Projectile.launchHeight*(1-t)
                    +Projectile.height(target)*Projectile.aimHeight*t+4*arc*t*(1-t)
                if z <= Projectile.height(ally)+(skill.projectile.radius or Projectile.radius) then
                    if t*distance < Projectile.nearShooter and (1-t)*distance > Projectile.meleeDistance then return nil end
                    risk = risk+2
                end
            end
            if (ally.x-target.x)^2+(ally.y-target.y)^2 < Projectile.exposureRadius^2 then risk = risk+1 end
        end
    end
    return risk
end

return Projectile
