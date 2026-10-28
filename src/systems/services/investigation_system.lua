-- Assignment-specific work; goals choose employment, services own contracts,
-- activities own movement, and visibility alone discovers battlefield evidence.
local Ecs = require("src.ecs.world")
local Services = require("src.systems.services.service_system")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local Goals = require("src.systems.goals.goal_state")
local Activities = require("src.systems.world_activities.world_activity_system")
local Navigation = require("src.world.world_navigation")
local Parties = require("src.systems.parties.party_system")
local ResidentTravel = require("src.systems.parties.resident_travel")
local Recovery = require("src.systems.actors.recovery")
local Clock = require("src.systems.services.caravan_system")
local Time = require("src.systems.campaign.time_system")
local Events = require("src.systems.campaign.world_events")
local Inventory = require("src.systems.items.inventory_system")
local Radius = require("src.systems.parties.party_interaction_system").interactionRadius
local Investigations = {retryHours = 24, assignmentHours = 480, searchHours = 3,
    searchRadius = 80, centerSpacing = 120, maxCenters = 12}

local function query(id, departureAt)
    return {type = "acquire_knowledge", subject = {type = "party", id = id},
        requiredDetails = {outcome = true, time = departureAt and true or nil},
        caravanFate = true, caravanDepartureAt = departureAt}
end

-- Only the sponsor's filtered departure memory and local return/report knowledge.
function Investigations.recognize(actor, context)
    if not actor.memory or not actor.npc_goals or not actor.caravan_formation then return end
    for _, departure in ipairs(Knowledge.getKnownEvents(actor, nil, "party_departed")) do
        if departure.sponsorId == actor.id and departure.partyId and departure.expectedReturnAt
            and departure.originLocationId and departure.destinationLocationId
            and Clock.now() > departure.expectedReturnAt
            and not Knowledge.findKnownInformation(actor, query(departure.partyId, departure.departureAt)) then
            actor:ensure("caravan_formation")
            local formation = actor.caravan_formation
            formation.investigations = formation.investigations or {}
            local attempt = formation.investigations[departure.partyId]
            if not attempt then
                attempt = {targetPartyId = departure.partyId, departureEventId = departure.id,
                    originLocationId = departure.originLocationId, destinationLocationId = departure.destinationLocationId,
                    expectedReturnAt = departure.expectedReturnAt, retryAt = 0}
                attempt.departureAt = departure.departureAt
                formation.investigations[departure.partyId] = attempt
            end
            if departure.departureAt and departure.departureAt > (attempt.departureAt or 0) then
                attempt.departureAt, attempt.departureEventId = departure.departureAt, departure.id
                attempt.originLocationId, attempt.destinationLocationId = departure.originLocationId, departure.destinationLocationId
                attempt.expectedReturnAt = departure.expectedReturnAt
            end
            local objective
            for _, goal in ipairs(actor.npc_goals.goals) do
                if goal.type == "acquire_knowledge" and goal.caravanFate and goal.subject
                    and goal.subject.type == "party" and goal.subject.id == departure.partyId
                    and goal.caravanDepartureAt == departure.departureAt then objective = goal; break end
            end
            objective = objective or Goals.add(actor, query(departure.partyId, departure.departureAt))
            objective.investigation = attempt
        end
    end
end

-- Called only as AcquireKnowledge's selected way of obtaining missing information.
function Investigations.commission(actor, goal, context)
    local attempt, now = goal.investigation, Clock.now()
    if not attempt then return false, "awaiting_knowledge" end
    if Knowledge.findKnownInformation(actor, goal) then return false, "already_known" end
    local request = attempt.serviceId and Services.getRequest(attempt.serviceId, context)
    if request then
        if request.assignedAt then attempt.deadlineAt = request.assignedAt + request.data.assignmentSeconds end
        local closureKnown = request.closureEventId and Knowledge.knows(actor, request.closureEventId)
        if request.status == "open" then return false, "awaiting_investigator" end
        if not closureKnown and now < attempt.deadlineAt then return false, "awaiting_report" end
        if not closureKnown then
            -- A missed report is a timeout, never evidence of the worker's death.
            if request.status == "assigned" then
                local cancelled, closure = Services.cancel(request.id, context, "report_deadline_elapsed")
                if cancelled then Knowledge.learn(actor, closure.closureEventId, Knowledge.getDetailCategories(closure.closureEventId, context.world)) end
            end
            attempt.retryAt = now + Time.worldHoursToSeconds(Investigations.retryHours)
        elseif not attempt.closedAt then
            attempt.retryAt = math.max(attempt.retryAt, now + Time.worldHoursToSeconds(Investigations.retryHours))
        end
        attempt.closedAt = attempt.closedAt or now
        attempt.serviceId = nil
    end
    if now < attempt.retryAt then return false, "investigation_retry" end
    local deadline = now + Time.worldHoursToSeconds(Investigations.assignmentHours)
    local offered, reason = Services.createRequest(actor, {type = "investigate", requiredCapability = "investigate",
        data = {targetPartyId = attempt.targetPartyId, originLocationId = attempt.originLocationId,
            destinationLocationId = attempt.destinationLocationId, departureEventId = attempt.departureEventId,
            expectedReturnAt = attempt.expectedReturnAt, deadlineAt = deadline,
            departureAt = attempt.departureAt,
            assignmentSeconds = Time.worldHoursToSeconds(Investigations.assignmentHours),
            searchRadius = Investigations.searchRadius, searchSeconds = Time.worldHoursToSeconds(Investigations.searchHours)}}, context)
    if not offered then return false, reason end
    attempt.serviceId, attempt.lastAttemptAt, attempt.deadlineAt, attempt.closedAt = offered.id, now, deadline, nil
    return false, "awaiting_investigator"
end

local function validData(data)
    for _, key in ipairs({"targetPartyId", "departureEventId", "originLocationId", "destinationLocationId"}) do
        local value = data[key]
        if not ((type(value) == "string" and value ~= "") or (type(value) == "number" and value == value
            and math.abs(value) < math.huge)) then return false end
    end
    for _, key in ipairs({"assignmentSeconds", "searchRadius", "searchSeconds"}) do
        local value = data[key]
        if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
            return false
        end
    end
    return true
end

function Investigations.assign(id, worker, context)
    local request = Services.getRequest(id, context)
    if not request or request.type ~= "investigate" then return false, "investigation_required" end
    if not validData(request.data) then return false, "invalid_investigation_data" end
    if not worker or worker.player or worker.caravan_work or worker.investigation_work then return false, "worker_busy" end
    local party = Services.getParty(worker, context.world)
    if party and Parties.getLeader(party) ~= worker then return false, "party_command_required" end
    local offer = Knowledge.getKnownEvent(worker, request.offerEventId)
    if not offer or not offer.serviceId or not offer.employerId or not offer.locationId or not offer.requiredCapability then
        return false, "opportunity_unknown"
    end
    return Services.assign(id, worker, context)
end

-- shortcut: maxCenters caps route coverage; revisit if long expeditions need denser searches.
function Investigations.route(map, origin, destination)
    local path, reason = Navigation.findPath(map, origin.x, origin.y, destination.x, destination.y)
    if not path then return nil, reason end
    local segments, total, x, y = {}, 0, origin.x, origin.y
    for _, point in ipairs(path) do
        local length = math.sqrt((point.x - x)^2 + (point.y - y)^2)
        segments[#segments + 1] = {x = x, y = y, dx = point.x - x, dy = point.y - y, length = length}
        total, x, y = total + length, point.x, point.y
    end
    local centers, count = {}, math.min(Investigations.maxCenters, math.max(1, math.ceil(total / Investigations.centerSpacing)))
    for i = 1, count do
        local distance = total * i / count
        for index, segment in ipairs(segments) do
            if distance <= segment.length or index == #segments then
                local fraction = segment.length > 0 and math.min(1, distance / segment.length) or 0
                centers[#centers + 1] = {x = segment.x + segment.dx * fraction, y = segment.y + segment.dy * fraction}
                break
            end
            distance = distance - segment.length
        end
    end
    return centers
end

local function begin(worker, request, context)
    if not validData(request.data) then return end
    local home = Services.getLocation(worker, context)
    local employer = Ecs.findActorById(request.employerId, context.world)
    if not home or home.id ~= request.locationId or Services.getLocation(employer, context) ~= home
        or not Recovery.isLiving(employer) then return end
    local origin = Ecs.findLocationById(request.data.originLocationId, context.world)
    local destination = Ecs.findLocationById(request.data.destinationLocationId, context.world)
    if not origin or not destination then return end
    local centers, reason = Investigations.route(context.map, origin, destination)
    if not centers then return end
    local party = Services.getParty(worker, context.world)
    if party and (Parties.getLeader(party) ~= worker or party.activeEncounterId
        or party.world_activity.status ~= "idle" or party.world_activity.retryCooldownSeconds > 0) then return end
    local created = party == nil
    if created then party, reason = ResidentTravel.create(worker, home, worker.name .. "'s investigation", context) end
    if not party then return end
    worker:ensure("investigation_work")
    local work = worker.investigation_work
    work.serviceId, work.employerId, work.targetPartyId, work.partyId = request.id, request.employerId, request.data.targetPartyId, party.id
    work.originLocationId, work.destinationLocationId, work.homeLocationId = origin.id, destination.id, home.id
    work.centers, work.centerIndex, work.phase, work.createdParty = centers, 1, "traveling", created
    work.deadlineAt = request.assignedAt + request.data.assignmentSeconds
    work.departureAt = request.data.departureAt
    work.searchRadius, work.searchSeconds = request.data.searchRadius, request.data.searchSeconds
    Services.start(request.id, party.id, context)
end

local function ownActivity(worker, goal, party, work, kind, params, context)
    local started, reason = Activities.start(party, kind, params, context.map)
    if started then
        party.world_activity.goalActorId = worker.id
        work.activitySequence, work.activityType = party.world_activity.sequence, kind
        goal.activity = {partyId = party.id, sequence = work.activitySequence}
        work.reason = nil
    else work.reason = reason end
    return started
end

local function contact(worker, party, work, context)
    -- Lookup is restricted to a real visible close contact, never remote target state.
    for _, other in ipairs(context.map:getParties()) do
        if other.id == work.targetPartyId and not other.activeEncounterId
            and (party.x - other.x)^2 + (party.y - other.y)^2 <= Radius^2
            and require("src.systems.parties.visibility_system").canSee(party, other) then
            if Ecs.findPartyById(other.id, context.world) ~= other then return end
            local living = false
            for _, actor in ipairs(other.actors) do if Recovery.isLiving(actor) then living = true; break end end
            if not living then return end
            local event = Events.record(context.world, "party_encounter", {
                time = {day = Time.getDay(), hour = Time.getHour()}, partyId = other.id, partyName = other.name,
                observerPartyId = party.id, x = party.x, y = party.y, outcome = "alive",
                subjectIds = {party.id, other.id}}, work.serviceId .. ":contact")
            for _, group in ipairs({party, other}) do
                Knowledge.learn(group, event.id, Knowledge.getDetailCategories(event.id, context.world))
                for _, actor in ipairs(group.actors) do
                    if Recovery.isLiving(actor) and actor.memory then Knowledge.share(group, actor, event.id) end
                end
            end
            return
        end
    end
end

local function archive(worker, work)
    worker.lastInvestigationWork = Inventory.deepClone(work:serialize())
    worker:remove("investigation_work")
end

local function fulfill(worker, goal, party, work, request, context)
    local activity = party.world_activity
    contact(worker, party, work, context)
    local found = Knowledge.findKnownInformation(worker, query(work.targetPartyId, work.departureAt))
    if (found or Clock.now() >= work.deadlineAt) and work.phase ~= "reporting" and work.phase ~= "returning" then
        work.phase, work.knownEventId = "returning", found
        if activity.goalActorId == worker.id and activity.sequence == work.activitySequence then
            Activities.cancel(party, found and "evidence_acquired" or "search_deadline_elapsed")
        end
    end
    if work.activitySequence then
        local outcome = activity.sequence == work.activitySequence and activity.status ~= "idle" and activity or activity.lastActivity
        if outcome and outcome.sequence == work.activitySequence and outcome.status == "active" then return end
        if outcome and outcome.sequence == work.activitySequence then
            if outcome.status == "completed" then
                if work.phase == "traveling" then work.phase = "searching"
                elseif work.phase == "searching" then
                    work.centerIndex, work.searchElapsed = work.centerIndex + 1, 0
                    work.phase = work.centerIndex > #work.centers and "returning" or "traveling"
                elseif work.phase == "returning" and work.activityType == "travel" then work.phase = "reporting" end
            elseif (outcome.reason == "recovery_required" or outcome.reason == "goal_interrupted") then
                if work.phase == "searching" then work.phase = "traveling" end
            elseif work.phase ~= "returning" and work.phase ~= "reporting" then
                work.phase, work.reason = "returning", outcome.reason
            end
        end
        work.activitySequence, work.activityType, goal.activity = nil, nil, nil
    end
    if activity.status ~= "idle" or (activity.retryCooldownSeconds or 0) > 0 then return end
    local home = Ecs.findLocationById(work.homeLocationId, context.world)
    if work.phase == "reporting" then
        if not home or Services.getLocation(worker, context) ~= home then work.phase = "returning"; return end
        work.returned = true
        local employer = Ecs.findActorById(work.employerId, context.world)
        if not Recovery.isLiving(employer) or employer.activeEncounterId or Services.getLocation(employer, context) ~= home then
            work.reason = "awaiting_employer_at_home"; return
        end
        local employerParty = Services.getParty(employer, context.world)
        if employerParty and employerParty.activeEncounterId then return end
        for _, view in ipairs(Knowledge.getKnownEvents(worker)) do
            if Knowledge.isAbout(view, {type = "party", id = work.targetPartyId}) then Knowledge.share(worker, employer, view.id) end
        end
        work.reported, work.returned, work.phase = true, true, "completed"
        if request.status == "assigned" then Services.complete(work.serviceId, context) end
        Goals.closeObligation(worker, work.serviceId, request.status == "cancelled" and "cancelled" or "completed")
        goal.activity = nil
        local attempts = employer.caravan_formation and employer.caravan_formation.investigations
        local attempt = attempts and attempts[work.targetPartyId]
        if attempt and attempt.serviceId == work.serviceId then
            attempt.closedAt, attempt.retryAt = Clock.now(), Clock.now() + Time.worldHoursToSeconds(Investigations.retryHours)
        end
        for _, objective in ipairs(employer.npc_goals and employer.npc_goals.goals or {}) do
            if objective.type == "acquire_knowledge" then
                local eventId = Knowledge.findKnownInformation(employer, objective)
                if eventId then objective.status, objective.reason, objective.knownEventId = "satisfied", nil, eventId end
            end
        end
        if work.createdParty then ResidentTravel.restore(worker, party, home, context) end
        archive(worker, work)
    elseif work.phase == "returning" then
        if home then ownActivity(worker, goal, party, work, "travel", {destinationLocationId = home.id}, context)
        else work.reason = "home_missing" end
    else
        local center = work.centers[work.centerIndex]
        if work.phase == "traveling" then
            ownActivity(worker, goal, party, work, "travel", {destinationX = center.x, destinationY = center.y}, context)
        else
            local remaining = math.max(0.01, work.searchSeconds - (work.searchElapsed or 0))
            if ownActivity(worker, goal, party, work, "search", {originX = center.x, originY = center.y,
                radius = work.searchRadius, durationSeconds = remaining}, context) then
                work.searchBase = work.searchElapsed or 0
            else work.phase = "returning" end
        end
    end
end

function Investigations.updateWork(context)
    for _, worker in ipairs(context.world:query({"unit", "npc_goals"})) do
        local goal = Services.selectedGoal(worker)
        local request = goal and goal.serviceId and Services.getRequest(goal.serviceId, context)
        if not worker.investigation_work and Recovery.isLiving(worker) and not worker.activeEncounterId
            and goal and goal.type == "fulfill_obligation" and request and request.type == "investigate"
            and request.status == "assigned" then begin(worker, request, context) end
        local work = worker.investigation_work
        if work then
            local assignment = Services.getRequest(work.serviceId, context)
            local party = Ecs.findPartyById(work.partyId, context.world)
            local onMap = false
            for _, candidate in ipairs(context.map:getParties()) do if candidate == party then onMap = true end end
            for _, place in ipairs(context.map:getLocations()) do
                for _, candidate in ipairs(place.stationedParties or {}) do if candidate == party then onMap = true end end
            end
            if not party or not onMap or not Recovery.isLiving(worker) or Parties.getLeader(party) ~= worker then
                if not party or not party.activeEncounterId then
                    if party and party.world_activity.goalActorId == worker.id
                        and party.world_activity.sequence == work.activitySequence then Activities.cancel(party, "worker_unavailable") end
                    Services.cancel(work.serviceId, context, "investigator_unavailable")
                    work.phase = "failed"
                    archive(worker, work)
                end
            elseif not party.activeEncounterId and not worker.activeEncounterId
                and (not assignment or assignment.status ~= "assigned") then
                local activity = party.world_activity
                if activity.goalActorId == worker.id and activity.sequence == work.activitySequence then
                    Activities.cancel(party, "assignment_ended")
                end
                work.phase, work.reason = assignment and assignment.status or "cancelled", "assignment_ended"
                Goals.closeObligation(worker, work.serviceId, work.phase)
                archive(worker, work)
            elseif not party.activeEncounterId and not worker.activeEncounterId then
                local activity = party.world_activity
                if work.activityType == "search" and activity.sequence == work.activitySequence and activity.elapsedSeconds then
                    work.searchElapsed = (work.searchBase or 0) + activity.elapsedSeconds
                end
                if goal and goal.type == "fulfill_obligation" and goal.serviceId == work.serviceId then
                    fulfill(worker, goal, party, work, Services.getRequest(work.serviceId, context), context)
                end
            end
        end
    end
end

return Investigations
