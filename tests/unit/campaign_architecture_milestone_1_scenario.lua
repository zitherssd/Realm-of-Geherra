local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.parties.party_system")
local LocationSystem = require("src.systems.locations.location_system")
local InventorySystem = require("src.systems.items.inventory_system")
local Map = require("src.world.map")

local function assertEqual(actual, expected, message)
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function assertTrue(value, message)
    assert(value == true, message or "expected truthy value")
end

local function testInventoryOwnershipAndNoAliasing()
    local world = EcsWorld.init()
    local source = Party.create(world, "Source", nil, "source-party")
    local target = Party.create(world, "Target", nil, "target-party")

    source.inventory = {
        { id = "bread", quantity = 4, metadata = { batch = "north" } },
        { id = "iron_sword", quantity = 1, metadata = { quality = "fine" } }
    }
    target.inventory = {
        { id = "bread", quantity = 2, metadata = { batch = "north" } },
        { id = "bread", quantity = 3, metadata = { batch = "south" } }
    }
    source.treasury = 25
    target.treasury = 10

    local transferred = PartySystem.transferInventoryItem(source, 1, target)
    assertEqual(#source.inventory, 1, "source cargo row not removed")
    assertEqual(#target.inventory, 2, "matching metadata stack was not merged")
    assertEqual(target.inventory[1].quantity, 6, "stacked party cargo merged incorrectly")
    assertEqual(target.inventory[2].quantity, 3, "metadata-distinct stack was changed")
    transferred.metadata.batch = "mutated"
    assertEqual(target.inventory[1].metadata.batch, "north", "transfer result aliases destination metadata")
    assertEqual(target.treasury, 10, "target treasury should not change during inventory transfer")

    assertTrue(PartySystem.transferTreasury(source, target, 7), "party gold transfer failed")
    assertEqual(source.treasury, 18, "gold source was not debited")
    assertEqual(target.treasury, 17, "gold destination was not credited")
    local sourceBefore, targetBefore = source.treasury, target.treasury
    assertEqual(PartySystem.transferTreasury(source, target, 99), false, "insufficient gold transfer succeeded")
    assertEqual(source.treasury, sourceBefore, "failed gold transfer changed source")
    assertEqual(target.treasury, targetBefore, "failed gold transfer changed destination")

    local emptyTarget = Party.create(world, "Empty Target", nil, "empty-target")
    local transferToEmpty = PartySystem.transferInventoryItem(source, 1, emptyTarget)
    assertTrue(transferToEmpty ~= nil, "transfer to an empty party inventory failed")
    assertEqual(#emptyTarget.inventory, 1, "empty target party did not receive item")

    local unchanged = InventorySystem.deepClone(source.inventory)
    assertEqual(PartySystem.transferInventoryItem(source, 1, nil), nil, "invalid transfer succeeded")
    assertEqual(#source.inventory, #unchanged, "invalid transfer changed source inventory")

    local trader = Unit.create(world, "trader", "merchant-1")
    trader.inventoryFormat = "list"
    trader.inventory = {
        { id = "wine", quantity = 3, metadata = { vintage = "spring" } },
        { id = "bread", quantity = 5, metadata = { batch = "south" } }
    }

    local party = Party.create(world, "Trader Party", trader.id, "trader-party")
    assertTrue(InventorySystem.transferAll(trader, party), "NPC-to-party transfer failed")
    assertEqual(#trader.inventory, 0, "NPC retained cargo after transfer")
    party.inventory[1].metadata.vintage = "travel"
    assertEqual(trader.inventory[1], nil, "NPC inventory alias remains after departure")
    PartySystem.removeFromInventory(party, 1)
    assertTrue(InventorySystem.transferAll(party, trader), "party-to-NPC transfer failed")
    assertEqual(#trader.inventory, 1, "lost goods reappeared after return")
    assertEqual(trader.inventory[1].id, "bread", "remaining cargo did not return")
    party.inventory[1] = { id = "bread", quantity = 100, metadata = { batch = "fake" } }
    assertTrue(InventorySystem.transferAll(party, trader), "second return transfer failed")
    assertEqual(#trader.inventory, 2, "post-departure cargo was not transferred")
    assertEqual(trader.inventory[2].quantity, 100, "return cargo quantity was not preserved")

    local invalidTarget = { inventory = { invalid = true }, inventoryFormat = "list" }
    party.inventory[1] = { id = "returning_goods", quantity = 2, metadata = { condition = "worn" } }
    local sourceSnapshot = InventorySystem.deepClone(party.inventory)
    assertEqual(InventorySystem.transferItem(party, 1, invalidTarget), nil,
        "invalid target inventory accepted a transfer")
    assertEqual(#party.inventory, #sourceSnapshot, "failed item transfer debited source")
    assertEqual(invalidTarget.inventory.invalid, true, "failed item transfer changed destination")

    local actor = Unit.create(world, "soldier", "actor-1")
    actor.inventory = { bread = 2 }
    actor.equipment = { mainHand = "iron_sword" }
    local actorParty = Party.create(world, "Actor Party", actor.id, "actor-party")
    actorParty.inventory = { { id = "bread", quantity = 6, metadata = { batch = "party" } } }
    PartySystem.addActor(actorParty, actor)

    assertEqual(InventorySystem.getItemCount(actor, "bread"), 2, "actor dictionary inventory count preserved")
    assertEqual(InventorySystem.getItemCount(actorParty, "bread"), 6, "party list inventory count preserved")
    assertTrue(InventorySystem.transferItem(actor, "bread", actorParty, 1) ~= nil,
        "actor inventory did not transfer to shared party cargo")
    assertEqual(InventorySystem.getItemCount(actor, "bread"), 1, "actor transfer did not debit personal inventory")
    assertEqual(#actorParty.inventory, 2, "personal item incorrectly merged with metadata-distinct cargo")
    assertTrue(InventorySystem.transferItem(actorParty, 2, actor, 1) ~= nil,
        "metadata-free party item did not transfer back to actor inventory")
    assertEqual(InventorySystem.getItemCount(actor, "bread"), 2, "actor did not receive transferred item")
    assertEqual(actor.equipment.mainHand, "iron_sword", "inventory transfer affected actor equipment")
end

local function testLocationMembership()
    local world = EcsWorld.init()
    local location = Location.create(world, "town-1", "Hearth")
    local otherLocation = Location.create(world, "town-2", "Ford")
    local map = Map.new("membership-map")
    map:addLocation(location)
    map:addLocation(otherLocation)
    local resident = Unit.create(world, "guard", "resident-1")
    local leader = Unit.create(world, "merchant", "leader-1")
    local escort = Unit.create(world, "soldier", "escort-1")
    local otherLeader = Unit.create(world, "merchant", "other-leader-1")

    LocationSystem.addNPC(location, resident)
    assertEqual(#LocationSystem.getAvailableNpcs(location), 1, "resident NPC not included")
    local residentParty = Party.create(world, "Duplicate Resident", resident.id, "resident-party")
    PartySystem.addActor(residentParty, resident)
    assertEqual(map:addParty(residentParty), false,
        "independent resident was also added as a traveling party member")

    local party = Party.create(world, "Stationed", leader.id, "stationed-party")
    PartySystem.addActor(party, leader)
    PartySystem.addActor(party, escort)
    assertTrue(map:stationParty(location, party), "party stationing failed")
    assertEqual(#location.stationedParties, 1, "stationed party was not recorded")
    assertEqual(location.parties, nil, "redundant location party list remains")
    assertEqual(party.locationId, nil, "party has duplicate location state")
    assertEqual(map:stationParty(location, party), false, "party was stationed twice")
    assertEqual(map:stationParty(otherLocation, party), false, "party was stationed at two locations")
    assertEqual(LocationSystem.addNPC(location, leader), false,
        "stationed actor was copied into independent residents")

    local available = LocationSystem.getAvailableNpcs(location)
    assertEqual(#available, 3, "resident + party members not resolved")
    assertTrue((available[2] == leader) or (available[3] == leader), "stationed leader missing from location NPC list")

    local partyTwo = Party.create(world, "Second Stationed", otherLeader.id, "stationed-party-2")
    PartySystem.addActor(partyTwo, otherLeader)
    assertTrue(map:stationParty(location, partyTwo), "second party could not be stationed")
    assertEqual(#LocationSystem.getAvailableNpcs(location), 4, "duplicate party actors were added")

    map:addParty(party)
    assertEqual(#location.stationedParties, 1, "departure left a stationed party reference")
    assertTrue(map:stationParty(otherLocation, party), "return stationing failed")
    assertEqual(LocationSystem.getAvailableNpcs(otherLocation)[1], leader,
        "return did not expose the same actor identity")
    assertTrue(map:removeParty(party.id), "stationed party removal failed")
    assertEqual(#otherLocation.stationedParties, 0, "party removal left stale membership")
    local afterDeparture = LocationSystem.getAvailableNpcs(location)
    assertEqual(#afterDeparture, 2, "party departure removed unrelated location actors")

    assertEqual(LocationSystem.addNPC(location, resident), false,
        "duplicate NPC insertion was not prevented")

    partyTwo:destroy()
    assertEqual(#LocationSystem.getAvailableNpcs(location), 1,
        "destroyed party left stale interactable actors")
    assertEqual(#location.stationedParties, 0, "destroyed party membership was not pruned")
end

local Scenario = {}

function Scenario.run()
    testInventoryOwnershipAndNoAliasing()
    testLocationMembership()
end

return Scenario
