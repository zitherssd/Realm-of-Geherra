local Conditions = require("src.systems.actors.conditions")
-- Applies a completed battle result to campaign parties. The caller owns the
-- encounter lifecycle and supplies its encounter handle for duplicate checks.

local EventBus = require("src.core.event_bus")
local PartySystem = require("src.systems.parties.party_system")
local InventorySystem = require("src.systems.items.inventory_system")

local CampaignBattleResultApplier = {}
local Injury = require("src.systems.actors.injury_system")

local function requireStableId(value, label)
    local valueType = type(value)
    if valueType ~= "string" and valueType ~= "number" then
        error(label .. " must be a string or number ID", 3)
    end
    if valueType == "number" and
        (value ~= value or value == math.huge or value == -math.huge) then
        error(label .. " must be a finite number", 3)
    end
end

local function getContextParties(context)
    local map = context.map
    if (map == nil and context.parties == nil) or (map ~= nil and
        (type(map) ~= "table" or type(map.getParties) ~= "function" or
        type(map.removeParty) ~= "function")) then
        error("Campaign context must include a map with getParties() and removeParty()", 3)
    end

    if context.parties ~= nil then
        if type(context.parties) ~= "table" then
            error("Campaign context parties must be a table", 3)
        end
        return context.parties
    end
    return map:getParties()
end

local function validateAndResolve(result, context)
    if type(result) ~= "table" then
        error("EncounterResult must be a table", 3)
    end
    if type(context) ~= "table" then
        error("Campaign context must be a table", 3)
    end
    if type(context.encounter) ~= "table" then
        error("Campaign context must include the owning encounter", 3)
    end
    if context.encounter.state ~= "completed" then
        error("Campaign battle result can only be applied after encounter completion", 3)
    end
    if context.encounter.resultApplied then
        error("Encounter result has already been applied", 3)
    end

    requireStableId(result.partyAId, "Party A")
    requireStableId(result.partyBId, "Party B")
    if result.partyAId == result.partyBId then
        error("Encounter parties must have different IDs", 3)
    end
    if result.routedPartyIds ~= nil then
        assert(type(result.routedPartyIds) == "table", "Routed party IDs must be a list")
        local seen, count = {}, 0
        for key, id in pairs(result.routedPartyIds) do
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and
                (id == result.partyAId or id == result.partyBId) and not seen[id],
                "Invalid or duplicate routed party ID")
            seen[id], count = true, count + 1
        end
        assert(count == #result.routedPartyIds, "Routed party IDs must be contiguous")
    end
    if result.outcome ~= "victory" and result.outcome ~= "draw" and result.outcome ~= "timeout" then
        error("Encounter outcome must be victory, draw, or timeout", 3)
    end
    if type(result.actors) ~= "table" then
        error("EncounterResult actors must be a table", 3)
    end

    local partiesById = {}
    for _, party in ipairs(getContextParties(context)) do
        if type(party) ~= "table" or party.id == nil or type(party.actors) ~= "table" then
            error("Campaign parties must have IDs and actor rosters", 3)
        end
        if partiesById[party.id] then
            error("Campaign party IDs must be unique", 3)
        end
        partiesById[party.id] = party
    end

    local partyA = partiesById[result.partyAId]
    local partyB = partiesById[result.partyBId]
    if not partyA or not partyB then
        error("EncounterResult party IDs were not found in the campaign context", 3)
    end
    local actorsById = {}
    local livingByPartyId = {[partyA.id] = 0, [partyB.id] = 0}
    local survivingByParty = {[partyA.id] = 0, [partyB.id] = 0}
    for _, party in ipairs({partyA, partyB}) do
        for _, actor in ipairs(party.actors) do
            if type(actor) ~= "table" then
                error("Campaign actor entries must be tables", 3)
            end
            requireStableId(actor.id, "Campaign actor")
            if actorsById[actor.id] then
                error("Campaign actor IDs must be unique across both parties", 3)
            end
            local actorResult = result.actors[actor.id]
            if type(actorResult) ~= "table" then
                error("EncounterResult is missing actor " .. tostring(actor.id), 3)
            end
            if actorResult.partyId ~= party.id then
                error("EncounterResult party does not match actor " .. tostring(actor.id), 3)
            end
            if type(actorResult.finalHp) ~= "number" or actorResult.finalHp ~= actorResult.finalHp or
                actorResult.finalHp == math.huge or actorResult.finalHp == -math.huge or
                actorResult.finalHp < 0 then
                error("EncounterResult has invalid final HP for actor " .. tostring(actor.id), 3)
            end
            if actorResult.defeated ~= (actorResult.finalHp <= 0) then
                error("EncounterResult has inconsistent defeated status for actor " .. tostring(actor.id), 3)
            end
            if actorResult.escaped ~= nil and type(actorResult.escaped) ~= "boolean" then
                error("EncounterResult escaped must be boolean", 3)
            end
            if actorResult.escaped and actorResult.defeated then
                error("Defeated actors cannot escape", 3)
            end
            if actorResult.state ~= nil then
                local state = actorResult.state
                if (state ~= "active" and state ~= "fleeing" and state ~= "escaped" and state ~= "defeated") or
                    ((state == "defeated") ~= actorResult.defeated) or
                    ((state == "escaped") ~= (actorResult.escaped == true)) then
                    error("EncounterResult has inconsistent unit state", 3)
                end
            end
            if actorResult.maxHp ~= nil and
                (type(actorResult.maxHp) ~= "number" or actorResult.maxHp ~= actorResult.maxHp or
                actorResult.maxHp <= 0 or actorResult.maxHp == math.huge) then
                error("EncounterResult has invalid max HP", 3)
            end
            if actorResult.statusEffects ~= nil and type(actorResult.statusEffects) ~= "table" then
                error("EncounterResult status effects must be a table", 3)
            end
            if actorResult.equipment ~= nil then
                if type(actorResult.equipment) ~= "table" or type(actorResult.itemDurability) ~= "table" then
                    error("EncounterResult requires equipment and durability maps", 3)
                end
                for slot, itemId in pairs(actorResult.equipment) do
                    if type(slot) ~= "string" or type(itemId) ~= "string" or
                        (not actorResult.defeated and (actor.equipment or {})[slot] ~= itemId) then
                        error("EncounterResult changed an equipped item", 3)
                    end
                end
                for itemId, remaining in pairs(actorResult.itemDurability) do
                    if type(itemId) ~= "string" or type(remaining) ~= "number" or
                        remaining ~= remaining or remaining <= 0 or remaining == math.huge then
                        error("EncounterResult has invalid equipment durability", 3)
                    end
                end
            elseif actorResult.itemDurability ~= nil then
                error("EncounterResult durability requires equipment", 3)
            end
            actorsById[actor.id] = {actor = actor, party = party, result = actorResult}
            if actorResult.injuries ~= nil then Injury.validate(actor, actorResult.injuries) end
            local tacticalHp = actorResult.tacticalHp or actorResult.finalHp
            local tacticalEscaped = actorResult.escaped
            if actorResult.tacticalHp ~= nil then
                assert(type(tacticalHp) == "number" and tacticalHp == tacticalHp and tacticalHp >= 0 and tacticalHp < math.huge,
                    "Invalid tactical HP")
                assert(type(actorResult.tacticalEscaped) == "boolean", "Invalid tactical escape status")
                assert(tacticalHp > 0 or actorResult.finalHp == 0, "Settlement cannot revive casualties")
                tacticalEscaped = actorResult.tacticalEscaped
            end
            if tacticalHp > 0 then survivingByParty[party.id] = survivingByParty[party.id] + 1 end
            if tacticalHp > 0 and not tacticalEscaped then
                livingByPartyId[party.id] = livingByPartyId[party.id] + 1
            end
        end
    end

    for actorId in pairs(result.actors) do
        if not actorsById[actorId] then
            error("EncounterResult references unknown actor " .. tostring(actorId), 3)
        end
    end

    if result.outcome == "victory" then
        if result.winnerPartyId ~= partyA.id and result.winnerPartyId ~= partyB.id then
            error("Victory result must identify a participating winner", 3)
        end
        local loserId = result.winnerPartyId == partyA.id and partyB.id or partyA.id
        if result.loserPartyId ~= nil and result.loserPartyId ~= loserId then
            error("Victory result has an invalid loser party ID", 3)
        end
        if livingByPartyId[result.winnerPartyId] == 0 or livingByPartyId[loserId] ~= 0 then
            error("Victory result does not match the actors' final HP", 3)
        end
    elseif result.winnerPartyId ~= nil or result.loserPartyId ~= nil then
        error(result.outcome .. " result cannot identify a winner", 3)
    elseif result.outcome == "draw" then
        if livingByPartyId[partyA.id] ~= 0 or livingByPartyId[partyB.id] ~= 0 then
            error("Draw result must leave no surviving actors", 3)
        end
    elseif survivingByParty[partyA.id] == 0 or survivingByParty[partyB.id] == 0 then
        error("Timeout result must leave survivors in both parties", 3)
    end

    return {partyA, partyB}, actorsById, context.map
end

function CampaignBattleResultApplier.apply(result, context)
    local parties, actorsById, map = validateAndResolve(result, context)

    for actorId, entry in pairs(actorsById) do
        entry.actor.hp = entry.result.finalHp
        if entry.result.maxHp then entry.actor.maxHp = entry.result.maxHp end
        if entry.result.statusEffects then
            entry.actor.statusEffects = Conditions.persistentStatuses(entry.result)
        end
        if entry.result.defeated then
            PartySystem.removeFromParty(entry.party, actorId)
        else
            for _, injury in ipairs(entry.result.injuries or {}) do Injury.apply(entry.actor, injury) end
            if entry.result.equipment then
                entry.actor.equipment = InventorySystem.deepClone(entry.result.equipment)
                entry.actor.itemDurability = InventorySystem.deepClone(entry.result.itemDurability)
                for slot in pairs(entry.actor.equipmentItems or {}) do
                    if not entry.actor.equipment[slot] then entry.actor.equipmentItems[slot] = nil end
                end
            end
        end
    end

    local eliminated = {}
    for _, party in ipairs(parties) do
        if #party.actors == 0 then
            eliminated[#eliminated + 1] = party
        end
    end

    for _, party in ipairs(eliminated) do
        if map then
            map:removeParty(party.id)
        end
    end

    if parties[1].__world and parties[1].__world.injuryTreatments then
        require("src.systems.actors.injury_treatment").update(0, parties[1].__world)
    end
    context.encounter.resultApplied = true
    for _, party in ipairs(eliminated) do
        EventBus.emit("party_killed", party.id)
    end

    local eliminatedPartyIds = {}
    for i, party in ipairs(eliminated) do
        eliminatedPartyIds[i] = party.id
    end
    return {eliminatedPartyIds = eliminatedPartyIds}
end

function CampaignBattleResultApplier.validate(result, context)
    validateAndResolve(result, context)
    return true
end

return CampaignBattleResultApplier
