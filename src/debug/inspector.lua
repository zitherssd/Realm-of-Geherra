-- Readable snapshots for the debug overlay; never retain entity references.
local PartySystem = require("src.systems.parties.party_system")
local EcsWorld = require("src.ecs.world")
local Tools = require("src.debug.campaign_tools")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local KnowledgeText = require("src.ui.knowledge_text")
local Services = require("src.systems.services.service_system")
local Inspector = {}

local function actorGoalLines(actor, add, map)
    local state = actor.npc_goals
    add("Goal evaluation: " .. (state and state.evaluationMode or "unconfigured"))
    local selected = Services.selectedGoal(actor)
    add("Selected goal: " .. (selected and selected.type or "none"))
    local capabilities = {}
    for name, allowed in pairs(state and state.capabilities or {}) do if allowed then capabilities[#capabilities + 1] = name end end
    table.sort(capabilities)
    add("Service/actor capabilities: " .. table.concat(capabilities, ", "))
    add("Providing services: " .. tostring(Services.isProviding(actor, {world = actor.__world, map = map})))
    local formation = actor.caravan_formation
    if formation then
        local now = require("src.systems.services.caravan_system").now()
        add(string.format("Sponsorship cooldown: %.2f world seconds", math.max(0, formation.nextSponsorshipAt - now)))
        local prep = formation.preparation or formation.lastPreparation
        if prep then
            add("Caravan preparation: " .. prep.id .. (formation.preparation and " (active)" or " (last)"))
            add("Started / ready: " .. prep.startedAt .. " / " .. prep.readyAt)
            add(string.format("Preparation ready in: %.2f world seconds", math.max(0, prep.readyAt - now)))
            add("Destination / investment: " .. tostring(prep.destinationLocationId) .. " / " .. prep.investment)
            add("Recruitment service: " .. prep.leaderServiceId .. " / " .. tostring(prep.reason or "ready to progress"))
        end
        for _, id in ipairs(formation.expeditionServiceIds) do
            local request = Services.getRequest(id, {world = actor.__world})
            local worker = request and EcsWorld.findActorById(request.assignedActorId, actor.__world)
            local work = worker and worker.caravan_work
            add("Expedition: " .. id .. " / party " .. tostring(request and request.executionPartyId)
                .. " / " .. tostring(work and work.phase or (request and request.status)))
            if work then add("Expected return: " .. work.expectedReturnAt) end
        end
    end
    if actor.caravan_work then
        local work = actor.caravan_work
        add("Caravan party / phase: " .. work.partyId .. " / " .. work.phase)
        add("Expected return: " .. work.expectedReturnAt .. " / " .. tostring(work.reason or ""))
    end
    add("Actor personal treasury: " .. tostring(actor.treasury or 0))
    if actor.lastServiceResult then
        add("Last healing: " .. tostring(actor.lastServiceResult.healed) .. " HP / " .. tostring(actor.lastServiceResult.price) .. " gold")
    end
    for _, request in ipairs(Services.listRequests({world = actor.__world})) do
        if request.employerId == actor.id then
            add("Owned request: " .. request.id .. " / " .. request.type .. " / " .. request.status
                .. " / worker " .. tostring(request.assignedActorId or "none"))
        end
    end
    if not state then return end
    local highest
    for _, goal in ipairs(state.goals) do
        local recovering = goal.type == "rest_and_recover" and goal.recovering
        local highestRecovering = highest and highest.type == "rest_and_recover" and highest.recovering
        if goal.status ~= "satisfied" and (not highest
            or (recovering and not highestRecovering)
            or ((not not recovering) == (not not highestRecovering) and goal.priority > highest.priority)) then
            highest = goal
        end
        add(goal.type .. " | priority " .. goal.priority .. " | " .. goal.status
            .. (goal.reason and (" | " .. goal.reason) or ""))
        if goal.serviceId then add("Obligation service ID: " .. goal.serviceId) end
        local result = goal.lastHealingResult or goal.lastServiceResult
        if result then add("Recent service result: " .. tostring(result.reason or result.healed or result.success)) end
        if goal.type == "rest_and_recover" then
            add("Recovery: " .. (goal.recovering and "required / recovering" or "inactive"))
        end
    end
    add("Highest-priority goal: " .. (highest and highest.type or "none"))
end

local function label(entity)
    return (entity.name or "Unnamed") .. " [" .. tostring(entity.id) .. "]"
end

function Inspector.lines(map, kind, id)
    local entity = Tools.resolve(map, kind, id)
    if not entity then return {"This entity was removed or is no longer on this map."} end
    local lines = {label(entity), string.format("Position: %.1f, %.1f", entity.x, entity.y),
        "Faction: " .. tostring(entity.faction or "none")}
    local function add(text) lines[#lines + 1] = text end
    if kind == "unit" then
        local recovery = entity.lastRecovery
        add("Recovery (last simulation update): " .. (recovery and recovery.mode or "not evaluated")
            .. (recovery and (" | " .. recovery.context) or ""))
    end
    if kind == "party" or kind == "unit" then
        local events = Knowledge.getKnownEvents(entity, entity.__world)
        add("Memory: " .. (entity.memory and (kind == "party" and "party" or "personal") or "none")
            .. " | Known events: " .. #events)
        for _, event in ipairs(events) do
            local categories = {}
            for category in pairs(Knowledge.getKnownDetails(entity, event.id, entity.__world)) do
                categories[#categories + 1] = category
            end
            table.sort(categories)
            add(event.id .. " [" .. event.type .. "] | Details: "
                .. (#categories > 0 and table.concat(categories, ", ") or "existence only"))
            add("  " .. KnowledgeText.describe(event))
        end
        add("")
    end
    if kind == "party" then
        if entity.templateId then add("Population party template: " .. entity.templateId) end
        if entity.originLocationId then add("Initial home location: " .. entity.originLocationId) end
        local exchange = entity.lastArrivalExchange
        if exchange then
            add("Last arrival exchange: " .. tostring(exchange.locationId) .. " [" .. exchange.arrivalEventId .. "]")
            add(string.format("  NPCs: %d/%d | Event transfers: %d | Added detail flags: %d",
                exchange.participants, exchange.eligible, exchange.eventsTransferred, exchange.detailsTransferred))
        end
        local leader = PartySystem.getLeader(entity)
        add("Leader: " .. (leader and label(leader) or "none"))
        if leader then actorGoalLines(leader, add, map) end
        add("Treasury: " .. tostring(entity.treasury) .. " | Supplies: " .. tostring(entity.supplies))
        add("State: " .. tostring(entity.state) .. " | Hostile: " .. tostring(entity.hostile == true or entity.faction == "bandits"))
        add("Sight: " .. PartySystem.getPartySight(entity) .. " | Profile: " .. PartySystem.getPartyProfile(entity))
        for _, location in ipairs(map:getLocations()) do
            for _, party in ipairs(location.stationedParties or {}) do
                if party == entity then add("Stationed at: " .. label(location)) end
            end
        end
        add("Encounter: " .. tostring(entity.activeEncounterId or "none"))
        local activity = entity.world_activity or {}
        add("Activity: " .. tostring(activity.type or "none") .. " / " .. tostring(activity.status or "idle")
            .. " / " .. tostring(activity.phase or "-"))
        add("Attempt: " .. tostring(activity.sequence or 0) .. " | Goal owner: " .. tostring(activity.goalActorId or "none"))
        add("Target: " .. tostring(activity.targetId or (activity.params or {}).targetPartyId
            or (activity.params or {}).destinationLocationId or "none"))
        add(string.format("Activity retry: %.1fs", activity.retryCooldownSeconds or 0))
        if activity.reason then add("Activity reason: " .. activity.reason) end
        if activity.lastActivity then
            local last = activity.lastActivity
            add("Last activity: " .. tostring(last.type) .. " #" .. tostring(last.sequence) .. " / "
                .. tostring(last.status) .. " / " .. tostring(last.reason or "-"))
        end
        local state = leader and leader.npc_goals
        add("")
        add("LEADER GOALS")
        if not state then add("Unconfigured (legacy Raid behavior).")
        else
            local flags = {}
            for name, allowed in pairs(state.capabilities) do flags[#flags + 1] = name .. " " .. tostring(allowed) end
            table.sort(flags)
            add("Capabilities: " .. table.concat(flags, ", "))
            if #state.goals == 0 then add("Empty goal list (legacy Raid suppressed).") end
            for index, goal in ipairs(state.goals) do
                add(index .. ". " .. goal.type .. " | priority " .. goal.priority .. " | " .. goal.status)
                add("  Target: " .. tostring(goal.amount or goal.destinationLocationId))
                if goal.detectedTargetId then add("  Detected raid target: " .. tostring(goal.detectedTargetId)) end
                if goal.roam then
                    add("  Roam origin: " .. tostring(goal.roam.originLocationId
                        or (tostring(goal.roam.originX) .. ", " .. tostring(goal.roam.originY)))
                        .. " | Radius: " .. goal.roam.radius)
                end
                add(string.format("  Attempts: %d | Retry: %.1fs", goal.attempts, goal.retrySeconds))
                if goal.reason then add("  Reason: " .. goal.reason) end
                if goal.lastOutcome then
                    add("  Last outcome: " .. tostring(goal.lastOutcome.activityType or "activity") .. " / "
                        .. goal.lastOutcome.status .. " / " .. tostring(goal.lastOutcome.reason or "-"))
                end
            end
        end
        add("")
        add("ACTORS (" .. #entity.actors .. ")")
        for _, actor in ipairs(entity.actors) do
            add(label(actor) .. " | HP " .. tostring(actor.hp) .. "/" .. tostring(actor.maxHp)
                .. (actor.lastRecovery and (" | Recovery: " .. actor.lastRecovery.mode) or "")
                .. (EcsWorld.findActorById(actor.id) ~= actor and " (removed)" or ""))
        end
        add("CARGO (" .. #entity.inventory .. " stacks)")
        for _, item in ipairs(entity.inventory) do add(tostring(item.name or item.id) .. " x" .. tostring(item.quantity or 1)) end
    elseif kind == "unit" then
        add("Actor template: " .. tostring(entity.troopType))
        add("Archetype / culture: " .. tostring(entity.archetypeId or "none") .. " / " .. tostring(entity.culture or "none"))
        if entity.defaultPartyTemplate then
            add("Default personal party: " .. (type(entity.defaultPartyTemplate) == "string" and entity.defaultPartyTemplate or "inline composition"))
        end
        add("HP: " .. tostring(entity.hp) .. "/" .. tostring(entity.maxHp))
        actorGoalLines(entity, add, map)
    else
        add("Type: " .. tostring(entity.type) .. " | Owner: " .. tostring(entity.owner or "none"))
        add("Definition / culture: " .. tostring(entity.definitionId or entity.type) .. " / " .. tostring(entity.culture or "none"))
        add("Population profile: " .. tostring(entity.populationProfile or "none"))
        local definition = require("src.systems.locations.location_rules").definition(entity)
        if definition then
            add("Caravan stop: " .. tostring(definition.rules.caravanStop) .. " | Recovery stop: " .. tostring(definition.rules.recoveryStop))
            add("Location actions: " .. #definition.actions)
        end
        add("Population: " .. tostring(entity.population) .. " | Prosperity: " .. tostring(entity.prosperity))
        add("Discovered: " .. tostring(entity.discovered) .. " | Profile: " .. tostring(entity.profile))
        add("Road site: " .. tostring(entity.siteId or "none"))
        add("RESIDENTS (" .. #entity.npcs .. ")")
        for _, npc in ipairs(entity.npcs) do add(label(npc) .. " | HP " .. tostring(npc.hp)) end
        add("STATIONED PARTIES (" .. #entity.stationedParties .. ")")
        for _, party in ipairs(entity.stationedParties) do add(label(party) .. " | Actors " .. #party.actors) end
    end
    return lines
end

return Inspector
