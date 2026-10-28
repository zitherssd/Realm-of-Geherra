-- Current campaign service state. History advertises it; knowledge gates discovery.
local EcsWorld = require("src.ecs.world")
local IdAllocator = require("src.core.id_allocator")
local Locations = require("src.systems.location_system")
local Inventory = require("src.systems.inventory_system")
local Recovery = require("src.systems.recovery")
local Events = require("src.systems.world_events")
local Knowledge = require("src.systems.knowledge_system")
local Time = require("src.systems.time_system")
local LocationRules = require("src.systems.location_rules")
local GoalState = require("src.systems.goal_state")
local Services = {healAmount = 40, healPrice = 10, healingRetrySeconds = 30, minimumUsefulHeal = 20}

local function copy(value, ancestors)
    if type(value) == "table" then
        assert(getmetatable(value) == nil, "Services require plain data")
        ancestors = ancestors or {}
        assert(not ancestors[value], "Cyclic service data")
        ancestors[value] = true
        local result = {}
        for key, child in pairs(value) do
            assert(type(key) == "string" or type(key) == "number", "Invalid service key")
            result[copy(key)] = copy(child, ancestors)
        end
        ancestors[value] = nil
        return result
    end
    local kind = type(value)
    assert(kind == "nil" or kind == "string" or kind == "boolean"
        or (kind == "number" and value == value and math.abs(value) < math.huge), "Invalid service data")
    return value
end

local function worldFor(context)
    return context and context.world or EcsWorld.campaign
end
local function registry(world)
    assert(world, "Services require a campaign")
    world.serviceRequests = world.serviceRequests or {}
    return world.serviceRequests
end

function Services.getParty(actor, world)
    world = world or actor.__world
    world:__flush()
    for _, party in ipairs(world:query({"party"})) do
        if EcsWorld.findPartyById(party.id, world) == party then
            for _, member in ipairs(party.actors or {}) do if member == actor then return party end end
        end
    end
end

-- Roster membership wins over stale resident references. Proximity is only used
-- for the input-controlled player, whose location screen does not station a party.
function Services.getLocation(actor, context)
    local world, map = worldFor(context), context and context.map
    if not map or not actor or actor.__world ~= world then return nil end
    local party = Services.getParty(actor, world)
    for _, location in ipairs(map:getLocations() or {}) do
        if EcsWorld.findLocationById(location.id, world) == location then
            if party then
                for _, stationed in ipairs(location.stationedParties or {}) do
                    if stationed == party then return location end
                end
                if actor.player then
                    local radius = require("src.systems.party_interaction_system").interactionRadius
                    local dx, dy = party.x - location.x, party.y - location.y
                    if dx * dx + dy * dy < radius * radius then return location end
                end
            else
                for _, resident in ipairs(location.npcs or {}) do if resident == actor then return location end end
            end
        end
    end
end

function Services.selectedGoal(actor)
    local state = actor and actor.npc_goals
    return state and state.goals[state.selectedGoalIndex]
end

function Services.hasObligation(actor, context)
    for _, request in pairs(registry(worldFor(context))) do
        if request.status == "assigned" and request.assignedActorId == actor.id then return request.id end
    end
end

local function accessible(actor, context, customer)
    local world = worldFor(context)
    if not Recovery.isLiving(actor) or actor.__world ~= world then return false, "actor_unavailable" end
    if not customer and not actor.memory then return false, "important_actor_required" end
    local party = Services.getParty(actor, world)
    if actor.activeEncounterId or (party and party.activeEncounterId) then return false, "in_encounter" end
    local activity = party and party.world_activity
    if activity and activity.status == "active" and not (customer and activity.type == "rest") then
        return false, "incompatible_activity"
    end
    if not Services.getLocation(actor, context) then return false, "not_at_location" end
    return true
end

function Services.isProviding(actor, context)
    local selected = Services.selectedGoal(actor)
    return selected ~= nil and selected.type == "provide_service" and selected.status == "active"
        and accessible(actor, context) == true and not Services.hasObligation(actor, context)
end

function Services.canPerform(provider, customer, serviceType, context)
    if serviceType ~= "heal" then return false, "unsupported_service" end
    if not Services.isProviding(provider, context) then return false, "provider_unavailable" end
    if not provider.npc_goals.capabilities.heal then return false, "capability_missing" end
    if provider == customer then return false, "self_service_not_supported" end
    local available, reason = accessible(customer, context, true)
    if not available then return false, reason end
    if Services.getLocation(provider, context) ~= Services.getLocation(customer, context) then
        return false, "not_local"
    end
    if customer.hp >= Recovery.maxHealth(customer) then return false, "healing_unnecessary" end
    if type(Services.healAmount) ~= "number" or Services.healAmount ~= Services.healAmount
        or Services.healAmount <= 0 or Services.healAmount == math.huge
        or type(Services.healPrice) ~= "number" or Services.healPrice ~= Services.healPrice
        or Services.healPrice == math.huge or Services.healPrice < 0 or Services.healPrice % 1 ~= 0 then
        return false, "invalid_healing_configuration"
    end
    local payer = Services.getParty(customer, worldFor(context)) or customer
    local payee = Services.getParty(provider, worldFor(context)) or provider
    if payer == payee then return false, "shared_treasury" end
    if type(payer.treasury) ~= "number" or payer.treasury ~= payer.treasury
        or payer.treasury == math.huge or payer.treasury < Services.healPrice then return false, "unaffordable" end
    if type(payee.treasury) ~= "number" or payee.treasury ~= payee.treasury
        or payee.treasury < 0 or payee.treasury == math.huge then return false, "invalid_payee" end
    return true
end

function Services.perform(provider, customer, serviceType, context)
    local ok, reason = Services.canPerform(provider, customer, serviceType, context)
    if not ok then return false, reason end
    local payer = Services.getParty(customer, worldFor(context)) or customer
    local payee = Services.getParty(provider, worldFor(context)) or provider
    if Services.healPrice > 0 and not Inventory.transferGold(payer, payee, Services.healPrice) then
        return false, "payment_failed"
    end
    local amount = math.min(Services.healAmount, Recovery.maxHealth(customer) - customer.hp)
    customer.hp = customer.hp + amount
    local result = {serviceType = serviceType, providerId = provider.id, healed = amount, price = Services.healPrice}
    customer.lastServiceResult = copy(result)
    return true, result
end

function Services.findLocalProviders(customer, serviceType, context)
    local result, location = {}, Services.getLocation(customer, context)
    for _, actor in ipairs(Locations.getAvailableNpcs(location)) do
        if Services.canPerform(actor, customer, serviceType, context) then result[#result + 1] = actor end
    end
    table.sort(result, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return result
end

-- Called only by selected recovery at a real settlement; retry is world time.
function Services.tryRecoveryHealing(actor, goal, context)
    if (goal.healingRetrySeconds or 0) > 0 then return end
    local location = Services.getLocation(actor, context)
    if not LocationRules.canRecover(location) then return end
    goal.healingRetrySeconds = Services.healingRetrySeconds
    if math.min(Services.healAmount, Recovery.maxHealth(actor) - actor.hp) < Services.minimumUsefulHeal then return end
    local providers = Services.findLocalProviders(actor, "heal", context)
    local ok, result = false, "no_affordable_provider"
    if providers[1] then ok, result = Services.perform(providers[1], actor, "heal", context) end
    goal.lastHealingResult = ok and result or {reason = result}
end

local function record(request, eventType, world)
    local employer = EcsWorld.findActorById(request.employerId, world)
    local worker = EcsWorld.findActorById(request.assignedActorId, world)
    local location = EcsWorld.findLocationById(request.locationId, world)
    local event = Events.record(world, eventType, {
        time = {day = Time.getDay(), hour = Time.getHour()}, serviceId = request.id,
        employerId = request.employerId, employerName = request.employerName,
        assignedActorId = request.assignedActorId, workerName = worker and worker.name,
        locationId = request.locationId, locationName = location and location.name,
        serviceType = request.type, requiredCapability = request.requiredCapability,
        preparationId = request.data.preparationId,
        status = request.status, reason = request.reason,
        subjectIds = {request.id, request.employerId, request.locationId, request.assignedActorId}
    }, request.id .. ":" .. eventType)
    -- Direct participants know the occurrence; no distant automatic broadcast.
    for _, actor in ipairs({employer or false, worker or false}) do
        local remoteEmployer = actor == employer and request.executionPartyId
            and eventType == "service_cancelled"
        if actor and actor.memory and not remoteEmployer then
            Knowledge.learn(actor, event.id, Knowledge.getDetailCategories(event.id, world), world)
        end
    end
    return event.id
end

function Services.createRequest(employer, data, context)
    local available, reason = accessible(employer, context)
    if not available then return nil, reason end
    local definition = copy(data)
    if type(definition) ~= "table" then return nil, "invalid_request" end
    if type(definition.type) ~= "string" or definition.type == "" or type(definition.requiredCapability) ~= "string"
        or definition.requiredCapability == "" then return nil, "invalid_request" end
    -- 7B has no profession handlers or arbitrary constraint callbacks.
    if definition.constraints ~= nil then return nil, "unsupported_constraints" end
    local location, world = Services.getLocation(employer, context), worldFor(context)
    if definition.locationId and definition.locationId ~= location.id then return nil, "employer_not_local" end
    local allocator, id = IdAllocator.forWorld(world)
    repeat id = allocator:allocate("service") until not registry(world)[id]
    local request = {id = id, type = definition.type,
        employerId = employer.id, employerName = employer.name, locationId = location.id,
        requiredCapability = definition.requiredCapability, status = "open", data = definition.data == nil and {} or definition.data}
    if type(request.data) ~= "table" then return nil, "invalid_request_data" end
    registry(world)[request.id] = request
    request.offerEventId = record(request, "service_offered", world)
    return copy(request)
end

function Services.getRequest(id, context) return copy(registry(worldFor(context))[id]) end
function Services.listRequests(context)
    local result = {}
    for _, request in pairs(registry(worldFor(context))) do result[#result + 1] = copy(request) end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end
function Services.isAvailable(id, context)
    local request, world = registry(worldFor(context))[id], worldFor(context)
    if not request or request.status ~= "open" then return false, "request_not_open" end
    local employer = EcsWorld.findActorById(request.employerId, world)
    local available, reason = accessible(employer, context)
    if not available then return false, reason end
    if Services.getLocation(employer, context).id ~= request.locationId then return false, "employer_moved" end
    return true
end

-- Contact exposes the current closure even to an applicant carrying an old offer.
function Services.learnCurrentStatus(id, worker, context)
    local request, world = registry(worldFor(context))[id], worldFor(context)
    if not request then return end
    local employer = EcsWorld.findActorById(request.employerId, world)
    local location = Services.getLocation(worker, context)
    if not location or location ~= Services.getLocation(employer, context) then return end
    local eventId = request.closureEventId or request.filledEventId or request.offerEventId
    Knowledge.learn(worker, eventId, Knowledge.getDetailCategories(eventId, world), world)
end

-- Low-level contract acceptance; the caller owns profession/participation policy.
function Services.accept(id, worker, context)
    local request = registry(worldFor(context))[id]
    local available, reason = Services.isAvailable(id, context)
    if not available then return false, reason end
    if not Recovery.isLiving(worker) or worker.__world ~= worldFor(context) then return false, "worker_unavailable" end
    if worker.id == request.employerId then return false, "self_assignment" end
    if Services.hasObligation(worker, context) then return false, "conflicting_obligation" end
    request.status, request.assignedActorId = "assigned", worker.id
    request.filledEventId = record(request, "service_filled", worldFor(context))
    GoalState.add(worker,
        {type = "fulfill_obligation", serviceId = request.id, priority = 80})
    return true, copy(request)
end

function Services.assign(id, worker, context)
    local request = registry(worldFor(context))[id]
    Services.learnCurrentStatus(id, worker, context)
    local available, reason = Services.isAvailable(id, context)
    if not available then return false, reason end
    if not Services.isProviding(worker, context) then return false, "worker_unavailable" end
    if worker.id == request.employerId then return false, "self_assignment" end
    if not worker.npc_goals.capabilities[request.requiredCapability] then return false, "capability_missing" end
    if Services.getLocation(worker, context).id ~= request.locationId then return false, "not_local" end
    if Services.hasObligation(worker, context) then return false, "conflicting_obligation" end
    return Services.accept(id, worker, context)
end

-- Execution may outlive the employer's presence at the commissioning location.
function Services.start(id, partyId, context)
    local request = assert(registry(worldFor(context))[id])
    assert(request.status == "assigned" and not request.executionPartyId)
    assert(EcsWorld.findPartyById(partyId, worldFor(context)), "Execution party missing")
    request.executionPartyId = partyId
end

local function close(id, status, context, reason)
    local world, request = worldFor(context), registry(worldFor(context))[id]
    if not request then return false, "request_missing" end
    if request.status == status then return true, copy(request) end
    if request.status == "completed" or request.status == "cancelled"
        or (status == "completed" and request.status ~= "assigned") then return false, "invalid_transition" end
    request.status, request.reason = status, reason
    request.closureEventId = record(request, "service_" .. status, world)
    local worker = EcsWorld.findActorById(request.assignedActorId, world)
    GoalState.closeObligation(worker, id, status)
    return true, copy(request)
end
function Services.complete(id, context) return close(id, "completed", context) end
function Services.cancel(id, context, reason)
    if reason ~= nil and type(reason) ~= "string" then return false, "invalid_reason" end
    return close(id, "cancelled", context, reason)
end

function Services.update(context)
    local world = worldFor(context)
    for id, request in pairs(registry(world)) do
        if request.status == "open" or request.status == "assigned" then
            local employer = EcsWorld.findActorById(request.employerId, world)
            local worker = EcsWorld.findActorById(request.assignedActorId, world)
            if (not request.executionPartyId and (not Recovery.isLiving(employer)
                or not EcsWorld.findLocationById(request.locationId, world)))
                or (request.status == "assigned" and not Recovery.isLiving(worker)) then
                Services.cancel(id, context, "participant_or_location_removed")
            end
        end
    end
end

-- Debug-only global derived view. NPC decision logic never calls this.
function Services.listProviders(context)
    local result, seen = {}, {}
    for _, location in ipairs(context.map:getLocations() or {}) do
        for _, actor in ipairs(Locations.getAvailableNpcs(location)) do
            if not seen[actor.id] and Services.isProviding(actor, context) and actor.npc_goals.capabilities.heal then
                seen[actor.id] = true
                local actual = Services.getLocation(actor, context)
                result[#result + 1] = {id = actor.id, name = actor.name, locationId = actual.id,
                    locationName = actual.name, selectedGoal = "provide_service", services = {"heal"},
                    capabilities = copy(actor.npc_goals.capabilities), price = Services.healPrice, amount = Services.healAmount}
            end
        end
    end
    table.sort(result, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return result
end

return Services
