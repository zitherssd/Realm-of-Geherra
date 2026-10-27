-- Resolves potential battle rewards into a serializable plan without applying
-- any campaign mutations.

local Items = require("src.data.items")
local LootResult = require("src.systems.loot_result")

local LootResolver = {
    DEFAULT_STOLEN_PROPORTION = 0.40,
    DEFAULT_DESTROYED_PROPORTION = 0.15
}

local function copySerializable(value, path, ancestors)
    local valueType = type(value)
    if valueType == "nil" or valueType == "string" or valueType == "boolean" then
        return value
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error(path .. " contains a non-finite number", 3)
        end
        return value
    elseif valueType ~= "table" then
        error(path .. " contains a non-serializable " .. valueType, 3)
    end

    ancestors = ancestors or {}
    if ancestors[value] then
        error(path .. " contains a cycle", 3)
    end
    ancestors[value] = true
    local copy = {}
    for key, child in pairs(value) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" then
            error(path .. " contains a non-primitive key", 3)
        end
        copy[key] = copySerializable(child, path .. "." .. tostring(key), ancestors)
    end
    ancestors[value] = nil
    return copy
end

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

local function requireQuantity(value, label)
    if type(value) ~= "number" or value < 0 or value % 1 ~= 0 or
        value ~= value or value == math.huge then
        error(label .. " must be a non-negative integer", 3)
    end
end

local function validateParties(partyA, partyB, battleResult)
    if type(partyA) ~= "table" or type(partyB) ~= "table" then
        error("LootResolver.resolve requires two campaign parties", 3)
    end
    requireStableId(partyA.id, "Party A")
    requireStableId(partyB.id, "Party B")
    if partyA.id == partyB.id then
        error("Loot parties must have different IDs", 3)
    end
    for _, party in ipairs({partyA, partyB}) do
        if type(party.actors) ~= "table" or type(party.inventory) ~= "table" then
            error("Loot parties must have actor rosters and inventory lists", 3)
        end
        local treasury = party.treasury or 0
        requireQuantity(treasury, "Party treasury")
        for index, item in ipairs(party.inventory) do
            if type(item) ~= "table" or item.id == nil then
                error("Party inventory entries must be item tables with IDs", 3)
            end
            requireQuantity(item.quantity or 1, "Party inventory quantity at index " .. index)
        end
        for _, actor in ipairs(party.actors) do
            if type(actor) ~= "table" then
                error("Party actors must be tables", 3)
            end
            requireStableId(actor.id, "Campaign actor")
        end
    end
    if type(battleResult) ~= "table" then
        error("LootResolver.resolve requires a completed battle result", 3)
    end
    if battleResult.partyAId ~= partyA.id or battleResult.partyBId ~= partyB.id then
        error("Battle result party IDs do not match the supplied parties", 3)
    end
end

local function resolveOutcome(partyA, partyB, battleResult)
    local outcome = battleResult.outcome
    if outcome ~= "victory" and outcome ~= "draw" and outcome ~= "timeout" then
        error("Battle outcome must be victory, draw, or timeout", 3)
    end
    if type(battleResult.actors) ~= "table" then
        error("Battle result actors must be a table", 3)
    end

    local actorsById = {}
    local livingByParty = {[partyA.id] = 0, [partyB.id] = 0}
    for _, party in ipairs({partyA, partyB}) do
        for _, actor in ipairs(party.actors) do
            if actorsById[actor.id] then
                error("Campaign actor IDs must be unique across both parties", 3)
            end
            local actorResult = battleResult.actors[actor.id]
            if type(actorResult) ~= "table" or actorResult.partyId ~= party.id then
                error("Battle result is missing or misassigns actor " .. tostring(actor.id), 3)
            end
            local hp = actorResult.finalHp
            if type(hp) ~= "number" or hp < 0 or hp ~= hp or
                hp == math.huge or hp == -math.huge or
                actorResult.defeated ~= (hp <= 0) then
                error("Battle result has invalid final HP for actor " .. tostring(actor.id), 3)
            end
            actorsById[actor.id] = {actor = actor, party = party, result = actorResult}
            if hp > 0 then
                livingByParty[party.id] = livingByParty[party.id] + 1
            end
        end
    end
    for actorId in pairs(battleResult.actors) do
        if not actorsById[actorId] then
            error("Battle result references unknown actor " .. tostring(actorId), 3)
        end
    end

    local winnerPartyId, loserPartyId
    if outcome == "victory" then
        winnerPartyId = battleResult.winnerPartyId
        if winnerPartyId ~= partyA.id and winnerPartyId ~= partyB.id then
            error("Victory result must identify a participating winner", 3)
        end
        loserPartyId = winnerPartyId == partyA.id and partyB.id or partyA.id
        if livingByParty[winnerPartyId] == 0 then
            error("Victory result does not match the actors' final HP", 3)
        end
        if battleResult.loserPartyId ~= nil and battleResult.loserPartyId ~= loserPartyId then
            error("Victory result has an invalid loser party ID", 3)
        end
    else
        if battleResult.winnerPartyId ~= nil then
            error(outcome .. " result cannot identify a winner", 3)
        end
        if outcome == "draw" then
            if livingByParty[partyA.id] ~= 0 or livingByParty[partyB.id] ~= 0 then
                error("Draw result must leave no surviving actors", 3)
            end
        elseif livingByParty[partyA.id] == 0 or livingByParty[partyB.id] == 0 then
            error("Timeout result must leave survivors in both parties", 3)
        end
    end

    return actorsById, winnerPartyId, loserPartyId, livingByParty
end

local function resolveRandom(randomSource)
    local value = randomSource()
    if type(value) ~= "number" or value < 0 or value >= 1 or value ~= value then
        error("Random source must return a number in [0, 1)", 3)
    end
    return value
end

local function roundedShare(quantity, proportion, randomSource)
    local exact = quantity * proportion
    local whole = math.floor(exact)
    local fraction = exact - whole
    if fraction > 0 and resolveRandom(randomSource) < fraction then
        whole = whole + 1
    end
    return math.min(quantity, whole)
end

local function copyItem(item, quantity)
    local copy = copySerializable(item, "Item instance")
    copy.quantity = quantity
    return copy
end

local function appendResource(
    list,
    sourcePartyId,
    item,
    sourceActorId,
    sourceKind,
    sourceSlot,
    sourceInventoryIndex
)
    list[#list + 1] = {
        sourcePartyId = sourcePartyId,
        sourceActorId = sourceActorId,
        sourceKind = sourceKind,
        sourceSlot = sourceSlot,
        sourceInventoryIndex = sourceInventoryIndex,
        item = item
    }
end

local function actorItemSnapshot(itemId, quantity, actor, sourceKind, sourceSlot)
    local item = Items[itemId] and copySerializable(Items[itemId], "Item definition") or {id = itemId}
    item.quantity = quantity
    local durabilityRemaining
    if sourceKind == "equipment" and actor.itemDurability then
        durabilityRemaining = actor.itemDurability[itemId]
    end
    return item, durabilityRemaining
end

local function appendActorPossessions(result, party, actor, disposition, recipientPartyId, actorResult)
    local target = disposition == "combatLoot" and result.combatLoot or result.retainedResources.items
    local inventory = actor.inventory or {}
    if type(inventory) ~= "table" then
        error("Actor inventory must use the item-ID-to-quantity map", 3)
    end
    for itemId, quantity in pairs(inventory) do
        requireStableId(itemId, "Actor inventory item")
        requireQuantity(quantity, "Actor inventory quantity")
        if quantity > 0 then
            local item = actorItemSnapshot(itemId, quantity, actor, "inventory")
            appendResource(target, party.id, item, actor.id, "inventory")
            if disposition == "combatLoot" then
                target[#target].recipientPartyId = recipientPartyId
            end
        end
    end

    local equipment = actor.equipment or {}
    if type(equipment) ~= "table" then
        error("Actor equipment must use the slot-to-item-ID map", 3)
    end
    for slot, itemId in pairs(equipment) do
        requireStableId(itemId, "Equipped item")
        local snapshot = actorResult and actorResult.equipment and actorResult or actor
        local item, durabilityRemaining = actorItemSnapshot(itemId, 1, snapshot, "equipment", slot)
        local broken = actorResult and actorResult.equipment and not actorResult.equipment[slot]
        local equipmentTarget = broken and result.destroyedResources.items or target
        appendResource(equipmentTarget, party.id, item, actor.id, "equipment", slot)
        local entry = equipmentTarget[#equipmentTarget]
        if durabilityRemaining ~= nil then
            entry.durabilityRemaining = durabilityRemaining
        end
        if disposition == "combatLoot" and not broken then
            entry.recipientPartyId = recipientPartyId
        end
    end
end

local function addRetainedPartyInventory(result, party)
    for index, item in ipairs(party.inventory) do
        appendResource(
            result.retainedResources.items,
            party.id,
            copyItem(item, item.quantity or 1),
            nil,
            "party_inventory",
            nil,
            index
        )
    end
    local gold = party.treasury or 0
    result.retainedResources.gold[#result.retainedResources.gold + 1] = {
        sourcePartyId = party.id,
        amount = gold
    }
end

local function validatePolicy(policy)
    if type(policy) ~= "table" or type(policy.plunderAllowed) ~= "boolean" then
        error("Loot policy must explicitly set plunderAllowed", 3)
    end
    local stolen = policy.stolenProportion
    if stolen == nil then stolen = LootResolver.DEFAULT_STOLEN_PROPORTION end
    local destroyed = policy.destroyedProportion
    if destroyed == nil then destroyed = LootResolver.DEFAULT_DESTROYED_PROPORTION end
    for label, value in pairs({stolen = stolen, destroyed = destroyed}) do
        if type(value) ~= "number" or value < 0 or value > 1 or value ~= value or
            value == math.huge then
            error("Loot policy " .. label .. " proportion must be between 0 and 1", 3)
        end
    end
    if stolen + destroyed > 1 then
        error("Loot policy stolen and destroyed proportions cannot exceed 1", 3)
    end
    return stolen, destroyed
end

local function resolvePlunder(result, sourceParty, recipientParty, partyEliminated, policy, randomSource)
    result.plunder.sourcePartyId = sourceParty.id
    result.plunder.recipientPartyId = recipientParty.id
    result.plunder.sourcePartyEliminated = partyEliminated
    result.plunder.eligible = policy.plunderAllowed

    for index, item in ipairs(sourceParty.inventory) do
        local quantity = item.quantity or 1
        if policy.plunderAllowed then
            local stolen = roundedShare(quantity, policy.stolenProportion, randomSource)
            local destroyed = roundedShare(quantity, policy.destroyedProportion, randomSource)
            destroyed = math.min(quantity - stolen, destroyed)
            local retained = quantity - stolen - destroyed
            if stolen > 0 then
                result.plunder.itemAllocations[#result.plunder.itemAllocations + 1] = {
                    sourcePartyId = sourceParty.id,
                    recipientPartyId = recipientParty.id,
                    sourceKind = "party_inventory",
                    sourceInventoryIndex = index,
                    item = copyItem(item, stolen)
                }
            end
            if destroyed > 0 then
                appendResource(result.destroyedResources.items, sourceParty.id,
                    copyItem(item, destroyed), nil, "party_inventory", nil, index)
            end
            if retained > 0 then
                appendResource(result.retainedResources.items, sourceParty.id,
                    copyItem(item, retained), nil, "party_inventory", nil, index)
            end
        else
            appendResource(result.retainedResources.items, sourceParty.id,
                copyItem(item, quantity), nil, "party_inventory", nil, index)
        end
    end

    local gold = sourceParty.treasury or 0
    local stolenGold = policy.plunderAllowed
        and roundedShare(gold, policy.stolenProportion, randomSource) or 0
    result.plunder.goldAllocations[1] = {
        sourcePartyId = sourceParty.id,
        recipientPartyId = recipientParty.id,
        amount = stolenGold
    }
    result.retainedResources.gold[#result.retainedResources.gold + 1] = {
        sourcePartyId = sourceParty.id,
        amount = gold - stolenGold
    }
end

function LootResolver.resolve(partyA, partyB, battleResult, policy, randomSource)
    validateParties(partyA, partyB, battleResult)
    local stolenProportion, destroyedProportion = validatePolicy(policy)
    randomSource = randomSource or math.random
    if type(randomSource) ~= "function" then
        error("LootResolver random source must be a function", 2)
    end

    local actorsById, winnerPartyId, loserPartyId, livingByParty =
        resolveOutcome(partyA, partyB, battleResult)
    local result = LootResult.new(
        battleResult.outcome,
        winnerPartyId,
        loserPartyId,
        partyA.id,
        partyB.id
    )
    for _, party in ipairs({partyA, partyB}) do
        local survivors = livingByParty[party.id]
        result.partyStates[party.id] = {
            survivingActors = survivors,
            eliminated = survivors == 0
        }
    end
    local policyValues = {
        plunderAllowed = policy.plunderAllowed,
        stolenProportion = stolenProportion,
        destroyedProportion = destroyedProportion
    }

    for _, entry in pairs(actorsById) do
        if entry.result.defeated then
            local isWinningParty = winnerPartyId ~= nil and entry.party.id == winnerPartyId
            appendActorPossessions(
                result,
                entry.party,
                entry.actor,
                isWinningParty and "retained" or (winnerPartyId and "combatLoot" or "retained"),
                winnerPartyId,
                entry.result
            )
        end
    end

    if winnerPartyId then
        local sourceParty = winnerPartyId == partyA.id and partyB or partyA
        local recipientParty = winnerPartyId == partyA.id and partyA or partyB
        resolvePlunder(
            result,
            sourceParty,
            recipientParty,
            livingByParty[sourceParty.id] == 0,
            policyValues,
            randomSource
        )
        local winnerParty = recipientParty
        for _, party in ipairs({partyA, partyB}) do
            if party.id == winnerParty.id then
                addRetainedPartyInventory(result, party)
                break
            end
        end
    else
        addRetainedPartyInventory(result, partyA)
        addRetainedPartyInventory(result, partyB)
    end

    result.policy = {
        plunderAllowed = policyValues.plunderAllowed,
        stolenProportion = policyValues.stolenProportion,
        destroyedProportion = policyValues.destroyedProportion
    }
    return result
end

return LootResolver
