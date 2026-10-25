-- Applies a prepared LootResult to campaign inventories and battlefield remains.

local BattlefieldRemainsSystem = require("src.systems.battlefield_remains_system")

local LootApplication = {}

local function copyTable(value, path, ancestors)
    local valueType = type(value)
    if valueType == "nil" or valueType == "string" or valueType == "boolean" or
        valueType == "number" then
        return value
    end
    if valueType ~= "table" then error(path .. " is not serializable", 3) end
    ancestors = ancestors or {}
    if ancestors[value] then error(path .. " contains a cycle", 3) end
    ancestors[value] = true
    local result = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then
            error(path .. " contains a non-primitive key", 3)
        end
        result[key] = copyTable(child, path .. "." .. tostring(key), ancestors)
    end
    ancestors[value] = nil
    return result
end

local function requireAmount(value, label)
    if type(value) ~= "number" or value < 0 or value ~= value or
        value == math.huge or value == -math.huge then
        error(label .. " must be a finite non-negative amount", 3)
    end
end

local function requireQuantity(value, label)
    requireAmount(value, label)
    if value % 1 ~= 0 then
        error(label .. " must be a whole item quantity", 3)
    end
end

local function appendItem(inventory, item, durabilityRemaining)
    local copy = copyTable(item, "Loot item")
    if durabilityRemaining ~= nil then
        copy.durabilityRemaining = durabilityRemaining
    end
    inventory[#inventory + 1] = copy
end

local function validateResource(resource, partyIds, label)
    if type(resource) ~= "table" or not partyIds[resource.sourcePartyId] then
        error(label .. " references an unknown source party", 3)
    end
    if type(resource.item) ~= "table" or resource.item.id == nil then
        error(label .. " must include an item instance with an ID", 3)
    end
    requireQuantity(resource.item.quantity or 1, label .. " quantity")
end

local function sameItemData(first, second)
    local a = copyTable(first, "Item comparison")
    local b = copyTable(second, "Item comparison")
    a.quantity, b.quantity = nil, nil

    local function equal(left, right)
        if type(left) ~= type(right) then return false end
        if type(left) ~= "table" then return left == right end
        for key, value in pairs(left) do
            if not equal(value, right[key]) then return false end
        end
        for key in pairs(right) do
            if left[key] == nil then return false end
        end
        return true
    end

    return equal(a, b)
end

local function collectActorResourceTotals(resources, totals, partiesByActorId, battleResult)
    for _, resource in ipairs(resources) do
        if resource.sourceActorId ~= nil then
            local source = partiesByActorId[resource.sourceActorId]
            if not source or not battleResult.actors[resource.sourceActorId] or
                not battleResult.actors[resource.sourceActorId].defeated or
                resource.sourcePartyId ~= source.party.id then
                error("Loot references a non-casualty actor or the wrong party", 3)
            end
            local actorTotals = totals[resource.sourceActorId]
            if not actorTotals then
                actorTotals = {inventory = {}, equipment = {}}
                totals[resource.sourceActorId] = actorTotals
            end
            local kind = resource.sourceKind
            if kind == "inventory" then
                local itemId = resource.item.id
                actorTotals.inventory[itemId] = (actorTotals.inventory[itemId] or 0) +
                    (resource.item.quantity or 1)
            elseif kind == "equipment" then
                if type(resource.sourceSlot) ~= "string" or
                    actorTotals.equipment[resource.sourceSlot] then
                    error("Loot has duplicate or invalid equipment slot data", 3)
                end
                actorTotals.equipment[resource.sourceSlot] = resource.item.id
            else
                error("Actor loot has an invalid source kind", 3)
            end
        end
    end
end

local function validateResourceAccounting(lootResult, partiesById, battleResult, partiesByActorId)
    local cargoTotals = {}
    local actorTotals = {}
    local resources = {}
    for _, resource in ipairs(lootResult.retainedResources.items) do
        resources[#resources + 1] = resource
    end
    for _, resource in ipairs(lootResult.destroyedResources.items) do
        resources[#resources + 1] = resource
    end
    for _, resource in ipairs(lootResult.combatLoot) do
        resources[#resources + 1] = resource
    end
    for _, resource in ipairs(lootResult.plunder.itemAllocations) do
        resources[#resources + 1] = resource
    end

    for _, resource in ipairs(resources) do
        validateResource(resource, partiesById, "Loot resource")
        if resource.sourceActorId ~= nil then
            collectActorResourceTotals({resource}, actorTotals, partiesByActorId, battleResult)
        elseif resource.sourceKind == "party_inventory" then
            local index = resource.sourceInventoryIndex
            if type(index) ~= "number" or index < 1 or index % 1 ~= 0 then
                error("Party cargo loot is missing its source inventory index", 3)
            end
            local sourceParty = partiesById[resource.sourcePartyId]
            local original = sourceParty.inventory[index]
            if not original or not sameItemData(original, resource.item) then
                error("Party cargo loot metadata does not match its source item", 3)
            end
            local totalsForParty = cargoTotals[resource.sourcePartyId]
            if not totalsForParty then
                totalsForParty = {}
                cargoTotals[resource.sourcePartyId] = totalsForParty
            end
            totalsForParty[index] = (totalsForParty[index] or 0) + (resource.item.quantity or 1)
        else
            error("Loot resource has no recognized source", 3)
        end
    end

    for partyId, party in pairs(partiesById) do
        local totalsForParty = cargoTotals[partyId] or {}
        for index, item in ipairs(party.inventory) do
            if totalsForParty[index] ~= (item.quantity or 1) then
                error("Loot does not conserve party cargo at inventory index " .. index, 3)
            end
        end
        for index in pairs(totalsForParty) do
            if not party.inventory[index] then
                error("Loot references a missing source cargo item", 3)
            end
        end
    end

    for actorId, source in pairs(partiesByActorId) do
        local actorResult = battleResult.actors[actorId]
        if actorResult and actorResult.defeated then
            local actual = actorTotals[actorId] or {inventory = {}, equipment = {}}
            for itemId, quantity in pairs(source.actor.inventory or {}) do
                if quantity > 0 and actual.inventory[itemId] ~= quantity then
                    error("Loot does not conserve defeated actor inventory", 3)
                end
            end
            for itemId in pairs(actual.inventory) do
                if ((source.actor.inventory or {})[itemId] or 0) == 0 then
                    error("Loot references unknown defeated actor inventory", 3)
                end
            end
            for slot, itemId in pairs(source.actor.equipment or {}) do
                if actual.equipment[slot] ~= itemId then
                    error("Loot does not conserve defeated actor equipment", 3)
                end
            end
            for slot in pairs(actual.equipment) do
                if (source.actor.equipment or {})[slot] == nil then
                    error("Loot references unknown defeated actor equipment", 3)
                end
            end
        end
    end

    if lootResult.destroyedResources.gold ~= 0 then
        error("Gold cannot be destroyed by loot resolution", 3)
    end
    if not lootResult.policy.plunderAllowed then
        for _, allocation in ipairs(lootResult.plunder.itemAllocations) do
            if allocation.item.quantity > 0 then
                error("LootResult allocates plunder despite a disallowing policy", 3)
            end
        end
        for _, allocation in ipairs(lootResult.plunder.goldAllocations) do
            if allocation.amount > 0 then
                error("LootResult allocates gold plunder despite a disallowing policy", 3)
            end
        end
    end
    local goldTotals = {}
    for _, resource in ipairs(lootResult.retainedResources.gold) do
        if not partiesById[resource.sourcePartyId] then
            error("Retained gold references an unknown source party", 3)
        end
        requireAmount(resource.amount, "Retained gold")
        goldTotals[resource.sourcePartyId] =
            (goldTotals[resource.sourcePartyId] or 0) + resource.amount
    end
    for _, allocation in ipairs(lootResult.plunder.goldAllocations) do
        if not partiesById[allocation.sourcePartyId] or
            not partiesById[allocation.recipientPartyId] then
            error("Plundered gold references an unknown party", 3)
        end
        requireAmount(allocation.amount, "Plundered gold")
        goldTotals[allocation.sourcePartyId] =
            (goldTotals[allocation.sourcePartyId] or 0) + allocation.amount
    end
    for partyId, party in pairs(partiesById) do
        if (goldTotals[partyId] or 0) ~= (party.treasury or 0) then
            error("Loot does not conserve party treasury for " .. tostring(partyId), 3)
        end
    end
end

local function addRetainedItem(plan, resource, partyIds)
    validateResource(resource, partyIds, "Retained resource")
    local partyId = resource.sourcePartyId
    local partyState = plan.lootResult.partyStates[partyId]
    if partyState.eliminated then
        plan.remainsItems[#plan.remainsItems + 1] = copyTable(resource, "Retained resource")
    else
        appendItem(plan.inventories[partyId], resource.item, resource.durabilityRemaining)
    end
end

function LootApplication.prepare(lootResult, context)
    if type(lootResult) ~= "table" or lootResult.schemaVersion ~= 1 then
        error("LootApplication requires a version 1 LootResult", 2)
    end
    if type(context) ~= "table" or type(context.map) ~= "table" or
        type(context.encounter) ~= "table" or type(context.battleResult) ~= "table" or
        type(context.battleResult.actors) ~= "table" then
        error("LootApplication requires map, encounter, and battle result context", 2)
    end
    local encounter = context.encounter
    if encounter.lootApplied then
        error("LootResult has already been applied for this encounter", 2)
    end
    if lootResult.outcome ~= "victory" and lootResult.outcome ~= "draw" and
        lootResult.outcome ~= "timeout" then
        error("LootResult has an invalid outcome", 2)
    end

    local partiesById, partyIds = {}, {}
    local partiesByActorId = {}
    for _, party in ipairs({encounter.partyA, encounter.partyB}) do
        if type(party) ~= "table" or type(party.inventory) ~= "table" or
            type(party.actors) ~= "table" then
            error("Encounter parties require actor rosters and item-list inventories", 2)
        end
        if partiesById[party.id] then error("Encounter party IDs must be unique", 2) end
        partiesById[party.id] = party
        partyIds[party.id] = true
        local state = lootResult.partyStates and lootResult.partyStates[party.id]
        if type(state) ~= "table" or type(state.eliminated) ~= "boolean" then
            error("LootResult is missing a participating party state", 2)
        end
        local survivors = 0
        for _, actor in ipairs(party.actors) do
            if partiesByActorId[actor.id] then error("Encounter actor IDs must be unique", 2) end
            partiesByActorId[actor.id] = {party = party, actor = actor}
            local actorResult = context.battleResult.actors[actor.id]
            if type(actorResult) ~= "table" or actorResult.partyId ~= party.id then
                error("Battle result does not match an encounter actor", 2)
            end
            if not actorResult.defeated then survivors = survivors + 1 end
        end
        if state.survivingActors ~= survivors or state.eliminated ~= (survivors == 0) then
            error("LootResult party state does not match battle casualties", 2)
        end
    end
    if context.battleResult.partyAId ~= encounter.partyAId or
        context.battleResult.partyBId ~= encounter.partyBId or
        lootResult.partyAId ~= encounter.partyAId or lootResult.partyBId ~= encounter.partyBId or
        lootResult.outcome ~= context.battleResult.outcome or
        lootResult.winnerPartyId ~= context.battleResult.winnerPartyId then
        error("LootResult does not match the owning encounter result", 2)
    end
    if type(lootResult.retainedResources) ~= "table" or
        type(lootResult.retainedResources.items) ~= "table" or
        type(lootResult.retainedResources.gold) ~= "table" or
        type(lootResult.destroyedResources) ~= "table" or
        type(lootResult.destroyedResources.items) ~= "table" or
        type(lootResult.combatLoot) ~= "table" or type(lootResult.plunder) ~= "table" or
        type(lootResult.plunder.itemAllocations) ~= "table" or
        type(lootResult.plunder.goldAllocations) ~= "table" then
        error("LootResult resource collections are malformed", 2)
    end
    if type(lootResult.policy) ~= "table" or
        type(lootResult.policy.plunderAllowed) ~= "boolean" or
        lootResult.plunder.eligible ~=
            (lootResult.outcome == "victory" and lootResult.policy.plunderAllowed) then
        error("LootResult plunder eligibility does not match its explicit policy", 2)
    end
    if encounter.remainsCreated then
        error("Battlefield remains were already created for this encounter", 2)
    end
    validateResourceAccounting(lootResult, partiesById, context.battleResult, partiesByActorId)

    local plan = {
        lootResult = lootResult,
        map = context.map,
        encounter = encounter,
        partiesById = partiesById,
        inventories = {},
        treasuries = {},
        remainsItems = {},
        remainsGold = {},
        defeatedActors = {}
    }
    for partyId in pairs(partyIds) do
        plan.inventories[partyId] = {}
        plan.treasuries[partyId] = 0
    end

    for _, resource in ipairs(lootResult.retainedResources.items or {}) do
        addRetainedItem(plan, resource, partyIds)
    end
    for _, resource in ipairs(lootResult.retainedResources.gold or {}) do
        if not partyIds[resource.sourcePartyId] then
            error("Retained gold references an unknown party", 2)
        end
        requireAmount(resource.amount, "Retained gold")
        if lootResult.partyStates[resource.sourcePartyId].eliminated then
            plan.remainsGold[#plan.remainsGold + 1] = copyTable(resource, "Retained gold")
        else
            plan.treasuries[resource.sourcePartyId] =
                plan.treasuries[resource.sourcePartyId] + resource.amount
        end
    end

    for _, resource in ipairs(lootResult.combatLoot or {}) do
        validateResource(resource, partyIds, "Combat loot")
        if not partyIds[resource.recipientPartyId] then
            error("Combat loot references an unknown recipient party", 2)
        end
        appendItem(plan.inventories[resource.recipientPartyId], resource.item, resource.durabilityRemaining)
    end
    for _, allocation in ipairs(lootResult.plunder.itemAllocations or {}) do
        validateResource(allocation, partyIds, "Plunder allocation")
        if not partyIds[allocation.recipientPartyId] then
            error("Plunder allocation references an unknown recipient party", 2)
        end
        appendItem(plan.inventories[allocation.recipientPartyId], allocation.item)
    end
    for _, allocation in ipairs(lootResult.plunder.goldAllocations or {}) do
        if not partyIds[allocation.sourcePartyId] or not partyIds[allocation.recipientPartyId] then
            error("Plunder gold references an unknown party", 2)
        end
        requireAmount(allocation.amount, "Plundered gold")
        plan.treasuries[allocation.recipientPartyId] =
            plan.treasuries[allocation.recipientPartyId] + allocation.amount
    end

    for _, party in pairs(partiesById) do
        for _, actor in ipairs(party.actors) do
            local actorResult = context.battleResult.actors[actor.id]
            if actorResult and actorResult.defeated then
                plan.defeatedActors[#plan.defeatedActors + 1] = actor
            end
        end
    end

    local remainsSite = BattlefieldRemainsSystem.prepare(
        context.map,
        encounter,
        context.battleResult,
        context.worldTime,
        plan.remainsItems,
        plan.remainsGold
    )
    plan.remainsSite = remainsSite
    return plan
end

function LootApplication.apply(plan)
    if type(plan) ~= "table" or type(plan.encounter) ~= "table" then
        error("LootApplication.apply requires a prepared plan", 2)
    end
    local encounter = plan.encounter
    if encounter.lootApplied then
        error("LootResult has already been applied for this encounter", 2)
    end

    for partyId, party in pairs(plan.partiesById) do
        local state = plan.lootResult.partyStates[partyId]
        if state.eliminated then
            party.inventory = {}
            party.treasury = 0
        else
            party.inventory = plan.inventories[partyId]
            party.treasury = plan.treasuries[partyId]
        end
    end
    for _, actor in ipairs(plan.defeatedActors) do
        actor.inventory = {}
        actor.equipment = {}
        actor.itemDurability = {}
    end

    BattlefieldRemainsSystem.apply(plan.map, encounter, plan.remainsSite)
    encounter.lootApplied = true
end

return LootApplication
