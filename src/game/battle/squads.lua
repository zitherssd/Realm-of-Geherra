-- Party-owned preferences; runtime squads never enter the campaign ECS world.
local Geometry = require("src.ecs.assemblages.battle_unit")
local Squads = {}

local Troops = require("src.data.troops")

function Squads.capacity(party)
    local total = 0
    for _, actor in ipairs(party.actors or {}) do
        local definition = Troops[actor.troopType] or {}
        if (actor.hp or 1) > 0 and (definition.type == "player" or definition.type == "companion" or actor.npc) then
            local level = math.max(0, math.min(4, (actor.attributes or {}).command or 0))
            total = total + (level >= 3 and 2 or level >= 1 and 1 or 0)
        end
    end
    return total
end

local function defaultConfig()
    return {members = {}, formation = "box", x = 260, y = 273}
end

function Squads.reconcile(party)
    local capacity = Squads.capacity(party)
    party.squads = party.squads or {}
    while #party.squads > capacity do
        local excess = table.remove(party.squads)
        if party.squads[1] then
            for _, id in ipairs(excess.members or {}) do table.insert(party.squads[1].members, id) end
        end
    end
    local configs = party.squads
    -- No commander grants configuration rights; a temporary group still deploys the roster.
    if #configs == 0 then configs = {defaultConfig()} end
    local valid, assigned = {}, {}
    for _, actor in ipairs(party.actors) do
        if (actor.hp or 1) > 0 then valid[actor.id] = true end
    end
    for _, config in ipairs(configs) do
        local members = {}
        for _, id in ipairs(config.members or {}) do
            if valid[id] and not assigned[id] then
                members[#members + 1], assigned[id] = id, true
            end
        end
        config.members = members
        config.formation = config.formation == "line" and "line" or "box"
        config.x, config.y = config.x or 260, config.y or 273
    end
    for _, actor in ipairs(party.actors) do
        if valid[actor.id] and not assigned[actor.id] then table.insert(configs[1].members, actor.id) end
    end
    return configs
end

function Squads.create(party)
    Squads.reconcile(party)
    if #party.squads >= Squads.capacity(party) then return false end
    table.insert(party.squads, defaultConfig())
    return true
end

function Squads.remove(party, index)
    Squads.reconcile(party)
    if not party.squads[index] then return false end
    local removed = table.remove(party.squads, index)
    if party.squads[1] then
        for _, id in ipairs(removed.members) do table.insert(party.squads[1].members, id) end
    end
    return true
end

function Squads.transfer(party, actorId, destination)
    Squads.reconcile(party)
    if not party.squads[destination] then return false end
    local found = false
    for _, actor in ipairs(party.actors) do if actor.id == actorId and (actor.hp or 1) > 0 then found = true end end
    if not found then return false end
    for _, config in ipairs(party.squads) do
        for i = #config.members, 1, -1 do
            if config.members[i] == actorId then table.remove(config.members, i) end
        end
    end
    table.insert(party.squads[destination].members, actorId)
    return true
end

function Squads.slots(members, formation)
    local slots, radius = {}, 0
    for _, member in ipairs(members) do
        radius = math.max(radius, member.collisionRadius or Geometry.actorRadius(member))
    end
    local rows = formation == "line" and #members or math.ceil(math.sqrt(#members))
    rows = math.max(1, rows)
    for i = 1, #members do
        slots[i] = {x = -math.floor((i - 1) / rows) * (2 * radius + 2),
            y = (((i - 1) % rows) - (math.min(rows, #members) - 1) / 2) * (2 * radius + 2), radius = radius}
    end
    return slots
end

function Squads.valid(circles, bounds, others)
    for i, a in ipairs(circles) do
        if a.x ~= a.x or a.y ~= a.y or a.x - a.radius < 0 or a.y - a.radius < 0 or
            a.x + a.radius > bounds.width or a.y + a.radius > bounds.height then return false end
        for _, b in ipairs(others or {}) do
            if (a.x-b.x)^2 + (a.y-b.y)^2 < (a.radius+b.radius)^2 then return false end
        end
        for j = 1, i - 1 do
            local b = circles[j]
            if (a.x-b.x)^2 + (a.y-b.y)^2 < (a.radius+b.radius)^2 then return false end
        end
    end
    return true
end

function Squads.circles(config, members)
    local circles = Squads.slots(members, config.formation)
    for _, slot in ipairs(circles) do slot.x, slot.y = slot.x + config.x, slot.y + config.y end
    return circles
end

-- Canonical player-side layout is shared by the world editor and both battle sides.
function Squads.layout(party)
    local configs = Squads.reconcile(party)
    local byId, leader = {}, nil
    for _, actor in ipairs(party.actors) do
        byId[actor.id] = actor
        if actor.id == party.leaderId then leader = actor end
    end
    leader = leader or party.actors[1]
    if not leader then return {}, nil end
    local occupied = {{x=500, y=273, radius=Geometry.actorRadius(leader)}}
    local layouts = {}
    for _, config in ipairs(configs) do
        local members = {}
        for _, id in ipairs(config.members) do if byId[id] ~= leader then members[#members+1] = byId[id] end end
        local circles = Squads.circles(config, members)
        if not Squads.valid(circles, {width=600,height=546}, occupied) then
            local found = false
            for _, formation in ipairs({config.formation, "box"}) do
                if found then break end
                for x=40,580,20 do
                    if found then break end
                    for y=40,520,20 do
                        local candidate = Squads.circles({x=x,y=y,formation=formation}, members)
                        if Squads.valid(candidate,{width=600,height=546},occupied) then
                            config.x,config.y,config.formation,circles,found=x,y,formation,candidate,true
                            break
                        end
                    end
                end
            end
            assert(found, "Party is too large for its deployment area")
        end
        layouts[#layouts+1] = {config=config,members=members,circles=circles}
        for _, circle in ipairs(circles) do occupied[#occupied+1]=circle end
    end
    return layouts, leader
end

function Squads.place(layouts, index, leader, x, y, formation)
    local layout = layouts[index]
    if not layout then return false end
    local config = {x=x,y=y,formation=formation or layout.config.formation}
    local circles = Squads.circles(config,layout.members)
    local others = {{x=500,y=273,radius=Geometry.actorRadius(leader)}}
    for i, other in ipairs(layouts) do
        if i ~= index then for _, circle in ipairs(other.circles) do others[#others+1]=circle end end
    end
    if not Squads.valid(circles,{width=600,height=546},others) then return false end
    layout.config.x,layout.config.y,layout.config.formation=x,y,config.formation
    layout.circles=circles
    return true
end

function Squads.command(context, team, order, squadId)
    if order ~= "hold" and order ~= "charge" then return false end
    for _, squad in ipairs(context.data.squads or {}) do
        if squad.team == team and (not squadId or squad.id == squadId) then
            squad.order, squad.assignments = order, nil
            for _, member in ipairs(squad.members) do member.intent = nil end
        end
    end
    return true
end

function Squads.position(unit)
    local squad = unit.squad
    if not squad or squad.order ~= "hold" then return nil end
    local living = {}
    for _, member in ipairs(squad.members) do if member.hp > 0 then living[#living+1] = member end end
    if not squad.assignments or squad.count ~= #living then
        local slots = Squads.slots(living, squad.config.formation)
        squad.assignments, squad.count = {}, #living
        -- Nearest available member takes each slot, then keeps it until the roster/order changes.
        for _, slot in ipairs(slots) do
            local best, distance
            for _, member in ipairs(living) do
                if not squad.assignments[member.id] then
                    local x = squad.leader.x + squad.offsetX + slot.x * squad.direction
                    local d = (member.x-x)^2 + (member.y-squad.config.y-slot.y)^2
                    if not distance or d < distance then best, distance = member, d end
                end
            end
            squad.assignments[best.id] = slot
        end
    end
    local slot = squad.assignments[unit.id]
    if not slot then return nil end
    return {x = squad.leader.x + squad.offsetX + slot.x * squad.direction, y = squad.config.y + slot.y}
end
return Squads
