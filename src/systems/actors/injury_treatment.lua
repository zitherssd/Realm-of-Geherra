local Conditions = require("src.systems.actors.conditions")
local Ecs = require("src.ecs.world")
local Injury = require("src.systems.actors.injury_system")
local Inventory = require("src.systems.items.inventory_system")
local Recovery = require("src.systems.actors.recovery")
local Services = require("src.systems.services.service_system")
local Treatment = {herbId = "healing_herbs", durationHours = 12, successProbability = 0.5}

local function registry(world)
    world.injuryTreatments = world.injuryTreatments or {}
    return world.injuryTreatments
end

function Treatment.forHealer(actor)
    return actor and actor.__world and (actor.__world.injuryTreatments or {})[actor.id]
end

function Treatment.forPatient(actor)
    for _, treatment in pairs(actor and actor.__world and actor.__world.injuryTreatments or {}) do
        if treatment.patientId == actor.id then return treatment end
    end
end

local function findInjury(patient, injury)
    for index, entry in ipairs(patient.injuries or {}) do
        if injury and entry.id == injury.id and entry.bodyPart == injury.bodyPart
            and Injury.definition(patient, entry) then return index, entry end
    end
end

local function inCombat(actor, reserved)
    local party = Services.getParty(actor, actor.__world)
    return actor.activeEncounterId or (party and party.activeEncounterId) or (reserved and reserved[actor])
end

-- Requesters own access/resource policy. The process has no party, goal or payment requirement.
function Treatment.start(healer, patient, injury, inventory)
    if not Recovery.isLiving(healer) or not Recovery.isLiving(patient)
        or healer.__world ~= patient.__world then return nil, "participant_unavailable" end
    if not (healer.npc_goals and healer.npc_goals.capabilities.heal) then return nil, "capability_missing" end
    if Treatment.forHealer(healer) or Treatment.forPatient(patient) then return nil, "treatment_busy" end
    if inCombat(healer) or inCombat(patient) then return nil, "in_encounter" end
    if not findInjury(patient, injury) then return nil, "injury_missing" end
    if not Inventory.hasItem(inventory, Treatment.herbId) then return nil, "no_herbs" end
    if not Inventory.removeItem(inventory, Treatment.herbId, 1) then return nil, "invalid_inventory" end
    local treatment = {healerId = healer.id, patientId = patient.id,
        injuryId = injury.id, bodyPart = injury.bodyPart,
        elapsedHours = 0, durationHours = Treatment.durationHours, status = "active"}
    registry(healer.__world)[healer.id] = treatment
    return treatment
end

local function finish(treatment, world, status, reason)
    if registry(world)[treatment.healerId] ~= treatment then return false end
    treatment.status, treatment.reason = status, reason
    registry(world)[treatment.healerId] = nil
    for _, id in ipairs({treatment.healerId, treatment.patientId}) do
        local actor = Ecs.findActorById(id, world)
        if actor then actor.lastTreatment = Inventory.deepClone(treatment) end
    end
    return true
end

function Treatment.cancel(treatment, world, reason)
    return finish(treatment, world, "cancelled", reason or "cancelled")
end

-- Returns unused hours only on completion, so automatic retries keep large updates consistent.
function Treatment.advance(treatment, elapsedWorldHours, world, reserved, rng)
    assert(type(elapsedWorldHours) == "number" and elapsedWorldHours >= 0
        and elapsedWorldHours < math.huge, "Treatment requires finite non-negative world hours")
    if registry(world)[treatment.healerId] ~= treatment then return 0 end
    local healer, patient = Ecs.findActorById(treatment.healerId, world), Ecs.findActorById(treatment.patientId, world)
    local index = patient and findInjury(patient, {id = treatment.injuryId, bodyPart = treatment.bodyPart})
    if not Recovery.isLiving(healer) or not Recovery.isLiving(patient) or not index
        or not (healer.npc_goals and healer.npc_goals.capabilities.heal) then
        Treatment.cancel(treatment, world, "participant_or_injury_unavailable")
        return 0
    end
    if treatment.automatic then
        local healerParty, patientParty = Services.getParty(healer, world), Services.getParty(patient, world)
        if (treatment.partyId and (not healerParty or healerParty.id ~= treatment.partyId or patientParty ~= healerParty))
            or (not treatment.partyId and healer ~= patient) then
            Treatment.cancel(treatment, world, "separated")
            return 0
        end
    end
    if inCombat(healer, reserved) or inCombat(patient, reserved) then return 0 end
    local used = math.min(elapsedWorldHours, treatment.durationHours - treatment.elapsedHours)
    treatment.elapsedHours = treatment.elapsedHours + used
    -- Accumulated fractional hours can land a few floating-point bits below the boundary.
    if treatment.elapsedHours + 1e-9 < treatment.durationHours then return 0 end
    treatment.elapsedHours = treatment.durationHours
    local success = (rng or math.random)() < Treatment.successProbability
    if success then Conditions.remove(patient, patient.injuries[index].id, patient.injuries[index].bodyPart) end
    finish(treatment, world, success and "success" or "failure")
    local remaining = elapsedWorldHours - used
    return remaining > 1e-9 and remaining or 0
end

function Treatment.resourceOwner(healer, party)
    if party and Inventory.hasItem(party, Treatment.herbId) then return party end
    if Inventory.hasItem(healer, Treatment.herbId) then return healer end
end

local function automaticHealer(healer, reserved)
    return healer.npc_goals and healer.npc_goals.capabilities.heal and Recovery.isLiving(healer)
        and not Services.hasObligation(healer, {world = healer.__world})
        and not inCombat(healer, reserved)
end

local function patients(healer, party, reserved)
    local result = {}
    for _, actor in ipairs(party and party.actors or {healer}) do
        if Recovery.isLiving(actor) and not Treatment.forPatient(actor) and not inCombat(actor, reserved) then
            local injuries = {}
            for _, entry in ipairs(actor.injuries or {}) do
                if Injury.definition(actor, entry) then injuries[#injuries + 1] = entry end
            end
            if #injuries > 0 then result[#result + 1] = {actor = actor, injuries = injuries} end
        end
    end
    return result
end

-- Recovery motivation remains positive; background care never requires a RestActivity.
function Treatment.recoveryState(actor, party)
    party = party or Services.getParty(actor, actor.__world)
    for _, patient in ipairs(party and party.actors or {actor}) do
        if Treatment.forPatient(patient) then return "injury_treatment_in_progress" end
    end
    for _, healer in ipairs(party and party.actors or {actor}) do
        if automaticHealer(healer) and not Treatment.forHealer(healer)
            and Treatment.resourceOwner(healer, party) and #patients(healer, party) > 0 then
            return "injury_treatment_pending"
        end
    end
    return "injury_treatment_unavailable"
end

function Treatment.update(elapsedWorldHours, world, reserved)
    if not world then return end
    assert(type(elapsedWorldHours) == "number" and elapsedWorldHours >= 0
        and elapsedWorldHours < math.huge, "Treatment requires finite non-negative world hours")
    if elapsedWorldHours == 0 and not next(world.injuryTreatments or {}) then return end
    world:__flush()
    -- Revalidate even at zero time, including records whose healer has been removed.
    local active = {}
    for _, treatment in pairs(registry(world)) do active[#active + 1] = treatment end
    for _, treatment in ipairs(active) do Treatment.advance(treatment, 0, world, reserved) end
    if elapsedWorldHours == 0 then return end
    local remaining = elapsedWorldHours
    repeat
        for _, healer in ipairs(world:query({"unit", "npc_goals"})) do
            if not Treatment.forHealer(healer) and automaticHealer(healer, reserved) then
                local party = Services.getParty(healer, world)
                local owner = Treatment.resourceOwner(healer, party)
                -- Check stock before selecting or attempting a debit; no failing per-tick remove.
                local eligible = owner and patients(healer, party, reserved) or {}
                if #eligible > 0 then
                    local target = eligible[math.random(#eligible)]
                    local treatment = Treatment.start(healer, target.actor, target.injuries[math.random(#target.injuries)], owner)
                    if treatment then treatment.automatic, treatment.partyId = true, party and party.id end
                end
            end
        end
        -- Advance simultaneous work to the next completion before selecting more patients.
        local step = remaining
        active = {}
        for _, treatment in pairs(registry(world)) do
            local healer = Ecs.findActorById(treatment.healerId, world)
            local patient = Ecs.findActorById(treatment.patientId, world)
            if not inCombat(healer, reserved) and not inCombat(patient, reserved) then
                active[#active + 1] = treatment
                step = math.min(step, treatment.durationHours - treatment.elapsedHours)
            end
        end
        if #active == 0 then return end
        table.sort(active, function(a, b) return tostring(a.healerId) < tostring(b.healerId) end)
        for _, treatment in ipairs(active) do Treatment.advance(treatment, step, world, reserved) end
        remaining = remaining - step
        -- At an exact boundary the next attempt starts on the next world update.
    until remaining <= 1e-9
end

function Treatment.lines(actor)
    local lines = {}
    local treatment = Treatment.forHealer(actor) or Treatment.forPatient(actor)
    local party = actor.__world and Services.getParty(actor, actor.__world)
    lines[#lines + 1] = string.format("Healing Herbs: shared %d / personal %d",
        Inventory.getItemCount(party, Treatment.herbId), Inventory.getItemCount(actor, Treatment.herbId))
    if treatment then
        local healer = Ecs.findActorById(treatment.healerId, actor.__world)
        local patient = Ecs.findActorById(treatment.patientId, actor.__world)
        lines[#lines + 1] = string.format("Treatment: %s (%s) -> %s (%s) | %s / %s | %.2f / %g world hours%s",
            healer and healer.name or "removed", tostring(treatment.healerId), patient and patient.name or "removed",
            tostring(treatment.patientId), treatment.injuryId, treatment.bodyPart,
            treatment.elapsedHours, treatment.durationHours,
            healer and patient and (inCombat(healer) or inCombat(patient)) and " (paused: combat)" or "")
    end
    if actor.lastTreatment then
        lines[#lines + 1] = "Last treatment: " .. actor.lastTreatment.status .. " / " .. actor.lastTreatment.injuryId
            .. (actor.lastTreatment.reason and (" / " .. actor.lastTreatment.reason) or "")
    end
    return lines
end

return Treatment
