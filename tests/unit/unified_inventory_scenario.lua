local Inventory = require("src.systems.items.inventory_system")
local Equipment = require("src.systems.items.equipment_system")
local Parties = require("src.systems.parties.party_system")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local World = require("src.ecs.world")
local Combat = require("src.systems.battle.combat_system")
local Generator = require("src.systems.items.loot_generator_system")
local LootScreen = require("src.ui.screens.loot_screen")
local InventoryScreen = require("src.ui.screens.inventory_screen")
local ShopScreen = require("src.ui.screens.shop_screen")
local Context = require("src.game.game_context")
local Remains = require("src.systems.battlefield.battlefield_remains_system")
local Resolver = require("src.systems.items.loot_resolver")
local Application = require("src.systems.items.loot_application")
local Map = require("src.world.map")

local function storageAndTransfers()
    local world = World.init()
    local actor = Unit.create(world, "soldier", "inventory-actor")
    local party = Party.create(world, "Cargo", nil, "inventory-party")
    local remains = {inventory = Inventory.new()}
    local location = {inventory = Inventory.new()}
    for _, owner in ipairs({actor, party, remains, location}) do
        assert(Inventory.isValid(owner.inventory) and #owner.inventory == 0)
        assert(Inventory.addItem(owner, "bread", 2))
        assert(Inventory.addItem(owner, "bread", 3))
        assert(#owner.inventory == 1 and Inventory.getItemCount(owner, "bread") == 5)
        assert(Inventory.hasItem(owner, "bread", 5) and not Inventory.hasItem(owner, "bread", 6))
        assert(not Inventory.removeItem(owner, 1, 6) and not Inventory.addItem(owner, "bread", -1))
        assert(Inventory.removeItem(owner, 1, 2).quantity == 2)
        assert(Inventory.getItemCount(owner, "bread") == 3)
    end
    local item = {id = "iron_sword", durabilityRemaining = 7, metadata = {enchants = {fire = 2}}}
    assert(Inventory.addItem(actor, item, 2))
    item.metadata.enchants.fire = 99
    assert(Inventory.addItem(actor, {id = "iron_sword", durabilityRemaining = 6}))
    assert(#actor.inventory == 3 and actor.inventory[2].metadata.enchants.fire == 2)
    local moved = Inventory.transferItem(actor, 2, party, 1)
    assert(moved.quantity == 1 and moved.durabilityRemaining == 7)
    moved.metadata.enchants.fire = 77
    assert(actor.inventory[2].metadata.enchants.fire == 2 and party.inventory[2].metadata.enchants.fire == 2)
    assert(not Inventory.transferItem(actor, 2, party, 2))
    local sourceItem = actor.inventory[2]
    assert(Inventory.transferItem(actor, sourceItem, party))
    assert(not Inventory.transferItem(actor, sourceItem, party), "repeated instance transfer duplicated an item")
    assert(Inventory.transferAll(party, remains) and #party.inventory == 0)
    local count = Inventory.getItemCount(remains, "iron_sword")
    assert(Inventory.transferAll(party, remains) and Inventory.getItemCount(remains, "iron_sword") == count)
    assert(not Inventory.transferAll(remains, {inventory = remains.inventory}))
    assert(not Inventory.transferAll(remains, {inventory = {bread = 1}}))
    assert(Inventory.getItemCount(remains, "iron_sword") == count)
    assert(Inventory.transferAll(remains, location) and #remains.inventory == 0)

    local singles = {inventory = Inventory.new()}
    assert(Inventory.addItem(singles, {id = "token", stackable = false}, 3))
    assert(#singles.inventory == 3 and singles.inventory[1].quantity == 1)
    assert(Inventory.addItem(singles, {id = "token", instanceId = "unique"}))
    assert(not Inventory.addItem(singles, {id = "token", instanceId = "unique"}))
    assert(not Inventory.addItem(singles, {id = "token", instanceId = "another"}, 2))
    local invalidLater = {inventory = {{id = "bread", quantity = 1}, {id = "token", instanceId = "unique"}}}
    local before = #singles.inventory
    assert(not Inventory.transferAll(invalidLater, singles))
    assert(#invalidLater.inventory == 2 and #singles.inventory == before, "full transfer partially committed")

    local replacement = Unit.create(world, "soldier", "inventory-replacement")
    Parties.addActor(party, actor)
    Parties.addActor(party, replacement)
    Inventory.addItem(party, "bread", 9)
    local shared, personal = party.inventory, actor.inventory
    Parties.setLeader(party, replacement.id)
    replacement.hp = 0
    Parties.removeActor(party, replacement)
    assert(party.inventory == shared and actor.inventory == personal and shared ~= personal)
    assert(Inventory.getItemCount(party, "bread") == 9 and party.treasury == 0)
end

local function equipmentAndScreens()
    local actor = {availableSlots = {"mainHand", "offHand"}, attributes = {}, equipment = {}}
    local party = {inventory = Inventory.new(), treasury = 100}
    local sword = {id = "iron_sword", quantity = 2, durabilityRemaining = 7, metadata = {engraving = "Mira"}}
    Inventory.addItem(party, sword)
    local screen = setmetatable({actor = actor, party = party}, InventoryScreen)
    assert(screen:_clickEquipFromInventory(1))
    assert(party.inventory[1].quantity == 1 and actor.equipment.mainHand == "iron_sword")
    assert(screen:_clickUnequipSlot("mainHand"))
    assert(#party.inventory == 1 and party.inventory[1].quantity == 2)
    assert(party.inventory[1].durabilityRemaining == 7 and party.inventory[1].metadata.engraving == "Mira")
    local shieldId
    for id, def in pairs(require("src.data.items")) do
        if def.type == "armor" and def.slot == "offHand" then shieldId = id; break end
    end
    assert(shieldId)
    Equipment.equip(actor, {id = shieldId, durabilityRemaining = 2, metadata = {owner = "Mira"}}, "offHand")
    Inventory.addItem(actor, {id = shieldId, durabilityRemaining = 20})
    Combat.applyBlockDurabilityLoss(actor)
    local _, shield = Equipment.unequip(actor, "offHand")
    assert(shield.durabilityRemaining == 1 and shield.metadata.owner == "Mira")
    Equipment.equip(actor, shield, "offHand")
    Combat.applyBlockDurabilityLoss(actor)
    assert(not actor.equipment.offHand and Inventory.getItemCount(actor, shieldId) == 1,
        "breaking equipped gear deleted a spare")

    actor.attributes.shadowcraft = 2
    Equipment.equip(actor, {id = "dagger", durabilityRemaining = 3, metadata = {mark = "left"}}, "mainHand")
    Equipment.equip(actor, {id = "dagger", durabilityRemaining = 8, metadata = {mark = "right"}}, "offHand")
    screen.gridY = 0
    screen._slotAt = function() return {slotId = "mainHand"} end
    screen.dragging = {item = {id = "dagger"}, source = "equipment", slot = "offHand"}
    screen:mousereleased(1, 1, 1)
    assert(Equipment.getEquippedItem(actor, "mainHand").durabilityRemaining == 8)
    assert(Equipment.getEquippedItem(actor, "offHand").durabilityRemaining == 3)
    assert(Equipment.getEquippedItem(actor, "mainHand").metadata.mark == "right")

    local loot = {{id = "bread", quantity = 2, metadata = {batch = "loot"}}}
    Generator.generateFromTable({{id = "bread", min = 2, max = 2, chance = 1}}, loot)
    Generator.generateFromTable({{id = "bread", min = 3, max = 3, chance = 1}}, loot)
    assert(#loot == 2 and loot[2].quantity == 5 and loot[2].value == 0 and not getmetatable(loot[2]))
    local oldData = Context.data
    Context.data = {playerParty = party}
    local lootScreen = LootScreen.new(loot)
    lootScreen:takeAll()
    local count = Inventory.getItemCount(party, "bread")
    lootScreen:takeAll()
    assert(#loot == 0 and count == 7 and Inventory.getItemCount(party, "bread") == count)
    Context.data = oldData
    local merchant = {inventory = {{id = "bread", quantity = 2, value = 10, metadata = {batch = "shop"}}}}
    local shop = setmetatable({merchant = merchant, merchantStock = merchant.inventory,
        playerParty = party, playerInventory = party.inventory, allowSell = true, sellPriceFactor = 0.5}, {__index = ShopScreen})
    assert(shop:buyItem(1) and party.treasury == 90 and merchant.inventory[1].quantity == 1)
    assert(party.inventory[#party.inventory].metadata.batch == "shop")
    assert(shop:sellItem(#party.inventory) and party.treasury == 95 and merchant.inventory[1].quantity == 2)
end

local function accountingAndLegacyRestore()
    local world, map = World.init(), Map.new("inventory-loot")
    local a, b = Party.create(world, "A"), Party.create(world, "B")
    local actorA, actorB = Unit.create(world, "soldier"), Unit.create(world, "soldier")
    Parties.addActor(a, actorA); Parties.addActor(b, actorB)
    map:addParty(a); map:addParty(b)
    actorB.equipment = {}
    actorB.inventory = {
        {id = "iron_sword", quantity = 1, durabilityRemaining = 3, metadata = {owner = "A"}},
        {id = "iron_sword", quantity = 1, durabilityRemaining = 9, metadata = {owner = "B"}}
    }
    local result = {partyAId = a.id, partyBId = b.id, outcome = "victory", winnerPartyId = a.id,
        actors = {[actorA.id] = {partyId = a.id, defeated = false, finalHp = 10},
            [actorB.id] = {partyId = b.id, defeated = true, finalHp = 0}}}
    local loot = Resolver.resolve(a, b, result, {plunderAllowed = false})
    local encounter = {id = "inventory-encounter", partyAId = a.id, partyBId = b.id}
    local context = {map = map, encounter = encounter, battleResult = result, worldTime = {day = 1, hour = 1}}
    loot.combatLoot[1].item.metadata.owner = "forged"
    assert(not pcall(Application.prepare, loot, context) and #actorB.inventory == 2)
    loot.combatLoot[1].item.metadata.owner = "A"
    local plan = Application.prepare(loot, context)
    Application.apply(plan)
    assert(Inventory.getItemCount(a, "iron_sword") == 2 and #actorB.inventory == 0)
    assert(a.inventory[1].durabilityRemaining == 3 and a.inventory[2].durabilityRemaining == 9)
    assert(not pcall(Application.apply, plan))
    local legacy = {schemaVersion = 1, nextSequence = 2, sites = {{id = "old", history = {},
        loot = {gold = 4, items = {{sourceActorId = "fallen", sourceKind = "equipment",
            item = {id = "iron_sword", metadata = {rune = "fire"}}, durabilityRemaining = 6}}}}}}
    Remains.restore(map, legacy)
    local site = map.battlefieldRemains[1]
    assert(site.inventory[1].durabilityRemaining == 6 and site.inventory[1].metadata.rune == "fire")
    assert(site.loot.items == nil and site.history.resourceAllocations[1].sourceActorId == "fallen")
    assert(Remains.serialize(map).schemaVersion == 2 and legacy.sites[1].inventory == nil)
    site.discovered = true
    local collection = require("src.systems.battlefield.battlefield_resource_collection")
    assert(collection.collect(map, site.id, a).collected)
    assert(#site.inventory == 0 and a.treasury == 4 and Inventory.getItemCount(a, "iron_sword") == 3)
    assert(a.inventory[3].durabilityRemaining == 6 and a.inventory[3].metadata.rune == "fire")
    assert(not collection.collect(map, site.id, a).collected and a.treasury == 4)
    assert(site.history.resourceAllocations[1].sourceActorId == "fallen")
end

return {run = function()
    storageAndTransfers()
    equipmentAndScreens()
    accountingAndLegacyRestore()
end}
