-- Caravan commissioning and service execution. Travel, encounters and money stay
-- with the existing campaign systems; this module never moves a party itself.
local Ecs = require("src.ecs.world")
local Services = require("src.systems.services.service_system")
local Locations = require("src.systems.locations.location_system")
local Parties = require("src.systems.parties.party_system")
local Inventory = require("src.systems.items.inventory_system")
local Activities = require("src.systems.world_activities.world_activity_system")
local Navigation = require("src.world.world_navigation")
local Travel = require("src.systems.world_activities.travel_activity")
local Recovery = require("src.systems.actors.recovery")
local Time = require("src.systems.campaign.time_system")
local Events = require("src.systems.campaign.world_events")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local LocationRules = require("src.systems.locations.location_rules")
local Ids = require("src.core.id_allocator")
local ResidentTravel = require("src.systems.parties.resident_travel")
local Caravans = {investment = 500, profitRate = 0.25, preparationDays = 3,
    cooldownDays = 30, tradingHours = 6, recruitmentIntervalSeconds = 2}

function Caravans.now()
    return Time.worldHoursToSeconds((Time.getDay() - 1) * 24 + Time.getHour())
end
local function days(value) return Time.worldHoursToSeconds(value * 24) end
local function owner(actor, context) return Services.getParty(actor, context.world) or actor end
local function settlement(location)
    return LocationRules.canHostCaravan(location)
end
local function stationed(party, location)
    if not location or (party.x - location.x)^2 + (party.y - location.y)^2
        > require("src.systems.parties.party_interaction_system").interactionRadius^2 then return false end
    for _, p in ipairs(location and location.stationedParties or {}) do if p == party then return true end end
    return false
end
local function onMap(party, map)
    for _, p in ipairs(map:getParties()) do if p == party then return true end end
    for _, location in ipairs(map:getLocations()) do if stationed(party, location) then return true end end
    return false
end

-- Estimate the actual navigation route, sampling terrain at movement-sized steps.
function Caravans.estimateTravel(map, ax, ay, bx, by, party)
    local path, reason = Navigation.findPath(map, ax, ay, bx, by)
    if not path then return nil, reason end
    local speed = Parties.getPartySpeed(party, Travel.speed)
    if speed <= 0 then return nil, "party_cannot_move" end
    local duration = 0
    for _, point in ipairs(path) do
        local dx, dy = point.x - ax, point.y - ay
        local length = math.sqrt(dx * dx + dy * dy)
        local steps = math.max(1, math.ceil(length / 4))
        for i = 0, steps - 1 do
            local modifier = map:getTravelSpeedMod(ax + dx * i / steps, ay + dy * i / steps)
            duration = duration + length / steps / (speed * math.max(0.01, modifier))
        end
        ax, ay = point.x, point.y
    end
    return duration
end

function Caravans.begin(sponsor, context)
    local goal = Services.selectedGoal(sponsor)
    if not Recovery.isLiving(sponsor) or not sponsor.memory or sponsor.player
        or not goal or goal.type ~= "acquire_gold"
        or not sponsor.npc_goals.capabilities.caravanFormation then return false, "sponsor_ineligible" end
    sponsor:ensure("caravan_formation")
    local state, now = sponsor.caravan_formation, Caravans.now()
    if state.preparation then return true end
    if now < state.nextSponsorshipAt then return false, "sponsorship_cooldown" end
    local origin = Services.getLocation(sponsor, context)
    if not settlement(origin) then return false, "settlement_required" end
    if owner(sponsor, context).treasury < Caravans.investment then return false, "insufficient_investment" end
    local destination
    for _, location in ipairs(context.map:getLocations()) do
        if location ~= origin and settlement(location) and Ecs.findLocationById(location.id, context.world) == location
            and Caravans.estimateTravel(context.map, origin.x, origin.y, location.x, location.y)
            and Caravans.estimateTravel(context.map, location.x, location.y, origin.x, origin.y) then
            destination = location; break
        end
    end
    if not destination then return false, "no_reachable_destination" end
    local preparation = {id = Ids.forWorld(context.world):allocate("preparation"), startedAt = now,
        readyAt = now + days(Caravans.preparationDays), originLocationId = origin.id,
        destinationLocationId = destination.id, investment = Caravans.investment}
    local request, reason = Services.createRequest(sponsor, {type = "lead_caravan", requiredCapability = "leadCaravan",
        data = {preparationId = preparation.id, destinationLocationId = destination.id,
            plannedDepartureAt = preparation.readyAt}}, context)
    if not request then return false, reason end
    preparation.leaderServiceId = request.id
    state.preparation = preparation
    state.nextSponsorshipAt = now + days(Caravans.cooldownDays)
    return true
end

-- The initial NPC transition is intentionally limited to independent residents.
-- Never commandeer or disband another party to hire its leader or followers.
function Caravans.canLead(worker, context)
    if worker.player then
        local Game = require("src.game.game_context")
        local party = Services.getParty(worker, context.world)
        return party ~= nil and party == Game.data.playerParty and Game.data.player == worker
            and Parties.getLeader(party) == worker and not worker.caravan_work
    end
    return not Services.getParty(worker, context.world) and not worker.caravan_work
end

-- Caravan applications use the generic contract API only after workflow eligibility.
function Caravans.assign(id, worker, context)
    Services.learnCurrentStatus(id, worker, context)
    local request = Services.getRequest(id, context)
    if not request or request.type ~= "lead_caravan" then return false, "caravan_request_required" end
    if not worker or not Caravans.canLead(worker, context) then return false, "independent_leader_required" end
    return Services.assign(id, worker, context)
end

-- Physical dispatch has succeeded; replace the offer without rewriting its history.
local function acceptVolunteer(id, worker, context)
    local request = assert(Services.getRequest(id, context))
    local employer = Ecs.findActorById(request.employerId, context.world)
    assert(Services.cancel(id, context, "player_volunteered"))
    local replacement = assert(Services.createRequest(employer, {type = request.type,
        requiredCapability = request.requiredCapability, data = request.data}, context))
    local ok, assigned = Services.accept(replacement.id, worker, context)
    assert(ok, "Validated player commissioning must succeed")
    return assigned
end

local function preflight(sponsor, worker, context, volunteer)
    local preparation = sponsor and sponsor.caravan_formation and sponsor.caravan_formation.preparation
    if not preparation then return nil, "preparation_missing" end
    local request = Services.getRequest(preparation.leaderServiceId, context)
    if not request or (request.status ~= "open" and request.status ~= "assigned") then return nil, "request_closed" end
    if not worker then return nil, "leader_unavailable" end
    if not volunteer and (Caravans.now() < preparation.readyAt or request.status ~= "assigned"
        or request.assignedActorId ~= worker.id) then return nil, "not_ready_or_assigned" end
    if not Recovery.isLiving(sponsor) or not Recovery.isLiving(worker) or sponsor == worker
        or not Caravans.canLead(worker, context)
        or (not volunteer and not worker.npc_goals.capabilities.leadCaravan) then return nil, "leader_unavailable" end
    local origin = Ecs.findLocationById(preparation.originLocationId, context.world)
    if Services.getLocation(sponsor, context) ~= origin or Services.getLocation(worker, context) ~= origin
        or not origin then return nil, "participants_not_at_origin" end
    local party = Services.getParty(worker, context.world)
    if sponsor.activeEncounterId or worker.activeEncounterId or (party and (party.activeEncounterId
        or party.world_activity.status ~= "idle" or (party.world_activity.retryCooldownSeconds or 0) > 0)) then
        return nil, "participants_busy"
    end
    local sponsorParty = Services.getParty(sponsor, context.world)
    if sponsorParty and (sponsorParty.activeEncounterId or sponsorParty.world_activity.status == "active") then
        return nil, "sponsor_busy"
    end
    if owner(sponsor, context) == party or owner(sponsor, context).treasury < preparation.investment then
        return nil, "insufficient_or_shared_funds"
    end
    local destination = Ecs.findLocationById(preparation.destinationLocationId, context.world)
    if not destination then return nil, "destination_missing" end
    local travelingParty = party or {actors = {worker}}
    local outbound, reason = Caravans.estimateTravel(context.map, origin.x, origin.y, destination.x, destination.y, travelingParty)
    if not outbound then return nil, reason end
    local inbound = Caravans.estimateTravel(context.map, destination.x, destination.y, origin.x, origin.y, travelingParty)
    if not inbound then return nil, "return_route_missing" end
    return {preparation = preparation, request = request, origin = origin, party = party,
        expectedReturnAt = Caravans.now() + (outbound + inbound) * 1.20 + Time.worldHoursToSeconds(Caravans.tradingHours)}
end

function Caravans.canVolunteer(sponsor, worker, context)
    if not worker or not worker.player or Services.hasObligation(worker, context) then return false end
    return preflight(sponsor, worker, context, true) ~= nil
end

function Caravans.dispatch(sponsor, worker, context, volunteer)
    if volunteer and not Caravans.canVolunteer(sponsor, worker, context) then return false, "cannot_volunteer" end
    local plan, reason = preflight(sponsor, worker, context, volunteer)
    if not plan then return false, reason end
    local prep, party = plan.preparation, plan.party
    local created = not party
    local playerWasTraveling = party and not stationed(party, plan.origin)
    if created then
        party, reason = ResidentTravel.create(worker, plan.origin, sponsor.name .. "'s caravan", context)
        if not party then return false, reason end
        party.faction = sponsor.faction
    elseif playerWasTraveling and not context.map:stationParty(plan.origin, party) then
        return false, "player_stationing_failed"
    end
    -- Validate Travel's preparation before touching either balance or replacing a worker.
    local prepared, travelReason = Travel.prepare(party, {destinationLocationId = prep.destinationLocationId}, context.map)
    if not prepared then
        if created then
            context.map:removeParty(party.id); Parties.removeActor(party, worker)
            Locations.addNPC(plan.origin, worker); context.world:removeEntity(party)
        elseif playerWasTraveling then context.map:addParty(party) end
        return false, travelReason
    end
    if not Inventory.transferGold(owner(sponsor, context), party, prep.investment) then
        if created then
            context.map:removeParty(party.id); Parties.removeActor(party, worker)
            Locations.addNPC(plan.origin, worker); context.world:removeEntity(party)
        elseif playerWasTraveling then context.map:addParty(party) end
        return false, "payment_failed"
    end
    local previousTraderFlag = party.isTraderParty
    party.isTraderParty = true -- Existing RaidActivity trader-target classification.
    worker:ensure("caravan_work")
    local work = worker.caravan_work
    work.serviceId, work.partyId, work.sponsorId = prep.leaderServiceId, party.id, sponsor.id
    work.originLocationId, work.destinationLocationId = prep.originLocationId, prep.destinationLocationId
    work.expectedReturnAt, work.phase, work.playerLed = plan.expectedReturnAt, "outbound", volunteer == true
    work.departureAt, work.investment = Caravans.now(), prep.investment
    work.previousTraderFlag = previousTraderFlag
    party.caravanDeparture = {sponsorId = sponsor.id, sponsorName = sponsor.name,
        expectedReturnAt = work.expectedReturnAt, departureAt = work.departureAt, preparationId = prep.id}
    local started, startReason = Activities.start(party, "travel", {destinationLocationId = prep.destinationLocationId}, context.map)
    party.caravanDeparture = nil
    if not started then
        Inventory.transferGold(party, owner(sponsor, context), prep.investment)
        worker:remove("caravan_work")
        party.isTraderParty = previousTraderFlag
        if created then
            context.map:removeParty(party.id); Parties.removeActor(party, worker)
            Locations.addNPC(plan.origin, worker); context.world:removeEntity(party)
        elseif playerWasTraveling then context.map:addParty(party) end
        return false, startReason
    end
    -- All fallible physical operations have succeeded. Player replacement uses
    -- service cancellation + a new commission, retaining immutable old history.
    if volunteer then
        local replacement = acceptVolunteer(prep.leaderServiceId, worker, context)
        assert(replacement, "Validated player commissioning must succeed")
        work.serviceId, prep.leaderServiceId = replacement.id, replacement.id
    end
    Services.start(work.serviceId, party.id, context)
    party.world_activity.goalActorId = worker.id
    work.activitySequence = party.world_activity.sequence
    for _, goal in ipairs(worker.npc_goals.goals) do
        if goal.serviceId == work.serviceId then goal.activity = {partyId = party.id, sequence = work.activitySequence} end
    end
    local state = sponsor.caravan_formation
    state.expeditionServiceIds[#state.expeditionServiceIds + 1] = work.serviceId
    state.lastPreparation, state.preparation = prep, nil
    return true, party.id
end

local function fail(worker, work, context, reason)
    local party = Ecs.findPartyById(work.partyId, context.world)
    if party and party.activeEncounterId then
        work.reason = reason
        return -- Release only after the encounter applies its real outcome.
    end
    if party and not party.activeEncounterId and party.world_activity.goalActorId == worker.id
        and party.world_activity.sequence == work.activitySequence then Activities.cancel(party, reason) end
    Services.cancel(work.serviceId, context, reason)
    for _, goal in ipairs(worker.npc_goals and worker.npc_goals.goals or {}) do
        if goal.serviceId == work.serviceId then goal.activity = nil end
    end
    work.phase, work.reason = "failed", reason
    worker.lastCaravanWork = Inventory.deepClone(work:serialize())
    worker:remove("caravan_work")
    -- Surviving parties retain their real resources and location. Never refund
    -- or delete cargo here: encounter resolution owns eliminated-party cleanup.
end

-- CampaignRuntime advances selected obligations after goal selection.
function Caravans.fulfill(worker, goal, context)
    local work = worker.caravan_work
    if not work or work.serviceId ~= goal.serviceId then goal.reason = "awaiting_dispatch"; return end
    local party = Ecs.findPartyById(work.partyId, context.world)
    if not party or party.activeEncounterId then return end
    local activity = party.world_activity
    if work.activitySequence then
        local sequence = work.activitySequence
        local outcome = activity.sequence == sequence and activity.status ~= "idle" and activity or activity.lastActivity
        if outcome and outcome.sequence == sequence and outcome.status == "active" then return end
        work.activitySequence = nil
        if outcome and outcome.sequence == sequence and outcome.status == "completed" and outcome.reason == "arrived" then
            local destinationId = work.phase == "outbound" and work.destinationLocationId or work.originLocationId
            local destination = Ecs.findLocationById(destinationId, context.world)
            if stationed(party, destination) then
                if work.phase == "outbound" then
                    work.phase, work.tradeReadyAt = "trading", Caravans.now() + Time.worldHoursToSeconds(Caravans.tradingHours)
                elseif work.phase == "returning" then work.phase = "delivery" end
            end
        end
    end
    if activity.status ~= "idle" or (activity.retryCooldownSeconds or 0) > 0 then return end
    if work.phase == "trading" then
        if not stationed(party, Ecs.findLocationById(work.destinationLocationId, context.world)) then
            work.phase, work.tradeReadyAt = "outbound", nil
            return -- Recovery may have moved the party: return by real Travel.
        end
        if Caravans.now() < work.tradeReadyAt then return end
        local profit = math.floor(party.treasury * Caravans.profitRate)
        Parties.addTreasury(party, profit)
        work.profit, work.phase = profit, "returning"
        local event = Events.record(context.world, "caravan_traded", {time = {day = Time.getDay(), hour = Time.getHour()},
            partyId = party.id, partyName = party.name, profit = profit, locationId = work.destinationLocationId,
            subjectIds = {party.id, worker.id}}, work.serviceId .. ":trade")
        Knowledge.learn(worker, event.id, Knowledge.getDetailCategories(event.id, context.world), context.world)
    end
    if work.phase == "delivery" then
        local sponsor = Ecs.findActorById(work.sponsorId, context.world)
        local origin = Ecs.findLocationById(work.originLocationId, context.world)
        if not stationed(party, origin) or not Recovery.isLiving(sponsor)
            or Services.getLocation(sponsor, context) ~= origin then
            work.reason = "awaiting_sponsor_at_origin"; return
        end
        local payee = owner(sponsor, context)
        if payee == party then work.reason = "shared_delivery_treasury"; return end
        -- A player volunteers the existing party and its shared treasury. No
        -- shadow wallet can reimburse stolen expedition capital.
        local amount = party.treasury
        if amount > 0 and not Inventory.transferGold(party, payee, amount) then return end
        work.delivered, work.phase, work.reason = amount, "completed", nil
        local returned = Events.record(context.world, "caravan_returned", {
            time = {day = Time.getDay(), hour = Time.getHour()}, partyId = party.id, partyName = party.name,
            locationId = origin.id, sponsorId = sponsor.id, outcome = "returned",
            subjectIds = {party.id, sponsor.id}}, work.serviceId .. ":returned")
        for _, participant in ipairs({sponsor, worker, party}) do
            Knowledge.learn(participant, returned.id, Knowledge.getDetailCategories(returned.id, context.world))
        end
        worker.lastCaravanWork = Inventory.deepClone(work:serialize())
        Services.complete(work.serviceId, context)
        goal.activity = nil
        party.isTraderParty = work.previousTraderFlag
        if work.playerLed then
            context.map:addParty(party) -- Restore normal input-controlled map membership.
        else
            -- Preserve unexpected cargo by repurposing the stationed party.
            if #party.inventory == 0 and #party.actors == 1 then
                context.map:removeParty(party.id); Parties.removeActor(party, worker)
                Locations.addNPC(origin, worker); context.world:removeEntity(party)
            else party.isTraderParty = nil end
        end
        worker:remove("caravan_work")
        return
    end
    if work.phase ~= "outbound" and work.phase ~= "returning" then return end
    local destination = work.phase == "outbound" and work.destinationLocationId or work.originLocationId
    local started, reason = Activities.start(party, "travel", {destinationLocationId = destination}, context.map)
    if started then
        party.world_activity.goalActorId = worker.id
        work.activitySequence = party.world_activity.sequence
        goal.activity = {partyId = party.id, sequence = work.activitySequence}
    else work.reason = reason end
end

-- Called after goal selection; player work also advances without NPC evaluation.
function Caravans.updateWork(context)
    for _, worker in ipairs(context.world:query({"unit", "caravan_work"})) do
        local work = worker.caravan_work
        local party = Ecs.findPartyById(work.partyId, context.world)
        local request = Services.getRequest(work.serviceId, context)
        if work.phase ~= "failed" and (not Recovery.isLiving(worker) or not party or not onMap(party, context.map)
            or Parties.getLeader(party) ~= worker or not request or request.status ~= "assigned") then
            fail(worker, work, context, "caravan_lost_or_assignment_ended")
        end
        local selected = Services.selectedGoal(worker)
        if worker.caravan_work and work.phase ~= "failed" and (worker.player
            or (selected and selected.type == "fulfill_obligation" and selected.serviceId == work.serviceId)) then
            for _, goal in ipairs(worker.npc_goals.goals) do
                if goal.serviceId == work.serviceId then Caravans.fulfill(worker, goal, context); break end
            end
        end
    end
end

-- Preparation and recruitment retain their pre-evaluation ordering.
function Caravans.update(context)
    local now = Caravans.now()
    for _, sponsor in ipairs(context.world:query({"unit", "caravan_formation"})) do
        local state, prep = sponsor.caravan_formation, sponsor.caravan_formation.preparation
        if prep then
            local request = Services.getRequest(prep.leaderServiceId, context)
            if not request or request.status == "cancelled" or request.status == "completed" then
                state.lastPreparation, state.preparation = prep, nil
            elseif request.status == "open" and now >= (prep.nextRecruitmentAt or 0) then
                prep.nextRecruitmentAt = now + Caravans.recruitmentIntervalSeconds
                local origin = Ecs.findLocationById(prep.originLocationId, context.world)
                if Services.getLocation(sponsor, context) == origin then
                    for _, candidate in ipairs(Locations.getAvailableNpcs(origin)) do
                        if Caravans.assign(request.id, candidate, context) then break end
                    end
                end
            elseif request.status == "assigned" and now >= prep.readyAt then
                local worker = Ecs.findActorById(request.assignedActorId, context.world)
                local selected = Services.selectedGoal(worker)
                if worker and (worker.player or (selected and selected.type == "fulfill_obligation"
                    and selected.serviceId == request.id)) then
                    local ok, reason = Caravans.dispatch(sponsor, worker, context)
                    prep.reason = not ok and reason or nil
                else prep.reason = "worker_pursuing_other_goal" end
            end
        end
    end
end

return Caravans
