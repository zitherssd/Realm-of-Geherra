local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Parties = require("src.systems.parties.party_system")
local Locations = require("src.systems.locations.location_system")
local Injury = require("src.systems.actors.injury_system")
local Treatment = require("src.systems.actors.injury_treatment")
local Inventory = require("src.systems.items.inventory_system")
local Goals = require("src.systems.goals.goal_system")
local Importance = require("src.systems.goals.goal_importance")
local Services = require("src.systems.services.service_system")
local Recovery = require("src.systems.actors.recovery")
local Activities = require("src.systems.world_activities.world_activity_system")
local Runtime = require("src.game.campaign.campaign_runtime")
local Encounters = require("src.systems.campaign.world_encounter_system")
local BattleState = require("src.game.states.battle_state")
local Simulation = require("src.game.battle.battle_simulation")
local Applier = require("src.systems.campaign.campaign_battle_result_applier")
local Time = require("src.systems.campaign.time_system")
local Game = require("src.game.game_context")
local Map = require("src.world.map")
local Inspector = require("src.debug.inspector")
local WorldState = require("src.game.states.world_state")
local Input = require("src.core.input")

local function near(a, b) assert(math.abs(a - b) < 1e-8, tostring(a) .. " ~= " .. tostring(b)) end
local function herbs(owner, count) assert(Inventory.addItem(owner, "healing_herbs", count or 1)) end
local function count(owner) return Inventory.getItemCount(owner, "healing_herbs") end
local function injured(actor, id, part)
    assert(Injury.apply(actor, {id = id or "broken_leg", bodyPart = part or "left_leg"}))
    return actor.injuries[#actor.injuries]
end
local function random(rng, action)
    local original = math.random
    math.random = rng
    local ok, err = xpcall(action, debug.traceback)
    math.random = original
    assert(ok, err)
end
local function setup(independent)
    Game.init()
    Time.reset()
    local world, map = Ecs.init(), Map.new("treatment")
    map.width, map.height = 10000, 10000
    local function actor(name, heal, troop)
        local a = Unit.create(world, troop or "soldier", name)
        a:ensure("memory")
        a.hp, a.maxHp, a.treasury = 100, 100, 100
        a.sight = 0
        Goals.configure(a, {}, {heal = heal == true, travel = true})
        return a
    end
    local healer, patient = actor("healer", true), actor("patient")
    local party = Party.create(world, "Treatment party", patient.id)
    party.x, party.y = 100, 100
    if not independent then
        Parties.addActor(party, patient); Parties.addActor(party, healer)
        map:addParty(party)
    end
    Game.data.currentMap = map
    return world, map, party, healer, patient, actor
end
local function advance(t, hours, world, roll, reserved)
    return Treatment.advance(t, hours, world, reserved, function() return roll or 0 end)
end

local function eligibilityAndResources()
    local world, map, party, healer, patient, actor = setup()
    local wound = injured(patient)
    assert(not Treatment.start(patient, patient, wound, party))
    assert(not Treatment.start(healer, patient, wound, party) and not Treatment.forHealer(healer))
    local otherParty = Party.create(world, "Other party")
    local other = actor("other", true)
    Parties.addActor(otherParty, other); map:addParty(otherParty)
    herbs(otherParty, 10)
    herbs(patient, 2)
    Treatment.update(1, world)
    assert(not Treatment.forHealer(healer) and count(otherParty) == 10 and count(patient) == 2)
    herbs(healer, 2)
    herbs(party, 2)
    assert(Inventory.addItem(party, {id = "bread", quantity = 3, metadata = {batch = "keep"}}))
    party.inventory[1].metadata = {batch = "herbs"}
    local t = assert(Treatment.start(healer, patient, wound, Treatment.resourceOwner(healer, party)))
    assert(count(party) == 1 and count(healer) == 2)
    assert(party.inventory[1].metadata.batch == "herbs" and party.inventory[2].metadata.batch == "keep")
    assert(not Treatment.start(healer, patient, wound, party) and count(party) == 1)
    local additional = actor("additional")
    assert(not Treatment.start(healer, additional, injured(additional), party) and count(party) == 1)
    assert(not Treatment.start(other, patient, wound, otherParty) and count(otherParty) == 10)
    advance(t, 12, world, 0.5)
    assert(t.status == "failure" and #patient.injuries == 1 and count(party) == 1)
    assert(not Treatment.forHealer(healer) and not Treatment.forPatient(patient))
    t = assert(Treatment.start(healer, patient, wound, party))
    advance(t, 12, world, 0.499999)
    assert(t.status == "success" and count(party) == 0 and count(healer) == 2)
    wound = injured(patient)
    Treatment.update(1, world)
    assert(Treatment.forHealer(healer).patientId == patient.id and count(healer) == 1)
    Treatment.cancel(Treatment.forHealer(healer), world)
    assert(count(healer) == 1)
    -- Empty inventories are read, never repeatedly debited.
    Inventory.removeItem(healer, "healing_herbs")
    local remove = Inventory.removeItem
    Inventory.removeItem = function() error("Empty stock reached removeItem") end
    local ok, err = pcall(function() for _ = 1, 4 do Treatment.update(1, world) end end)
    Inventory.removeItem = remove
    assert(ok, err)
    herbs(party)
    Treatment.update(1, world)
    assert(Treatment.forPatient(patient))
    Treatment.cancel(Treatment.forPatient(patient), world)
    patient.hp = 0
    herbs(party)
    assert(not Treatment.start(healer, patient, wound, party) and count(party) == 1)
    patient.hp = 100
    world:removeEntity(patient)
    assert(not Treatment.start(healer, patient, wound, party))
    healer.hp = 0
    assert(not Treatment.start(healer, healer, injured(healer), party))
end

local function anatomyAndSuccess()
    for _, spec in ipairs({{"soldier", "broken_leg", "left_leg"}, {"gaia_minotaur_naked", "crushed_hand", "left_arm"},
        {"dragon", "torn_wing", "left_wing"}, {"gaia_walking_tree", "damaged_roots", "roots"}}) do
        local world, _, _, healer, _, actor = setup(true)
        local patient = actor("anatomy", false, spec[1])
        local wound = injured(patient, spec[2], spec[3])
        herbs(healer)
        local t = assert(Treatment.start(healer, patient, wound, healer))
        advance(t, 12, world)
        assert(#patient.injuries == 0 and patient.hp == 100)
    end
    local world, _, _, healer = setup(true)
    local expected = {{"broken_leg", "left_leg", "speed", 16}, {"crushed_hand", "left_arm", "attack", 10},
        {"severe_chest_injury", "torso", "defense", 10}, {"damaged_eye", "head", "sight", 100}}
    herbs(healer, #expected)
    for _, spec in ipairs(expected) do
        local wound = injured(healer, spec[1], spec[2])
        assert(Injury.stat(healer, spec[3], spec[4]) < spec[4])
        local t = assert(Treatment.start(healer, healer, wound, healer))
        healer.hp = 60
        advance(t, 12, world)
        near(Injury.stat(healer, spec[3], spec[4]), spec[4])
        assert(healer.hp == 60, "Treatment restored HP")
    end
    herbs(healer)
    local left = injured(healer)
    injured(healer, "broken_leg", "right_leg")
    local t = assert(Treatment.start(healer, healer, left, healer))
    advance(t, 12, world)
    assert(#healer.injuries == 1 and healer.injuries[1].bodyPart == "right_leg")
end

local function durationAndRepetition()
    local world, _, party, healer, patient = setup()
    herbs(party, 4)
    local t = assert(Treatment.start(healer, patient, injured(patient), party))
    advance(t, 6, world); near(t.elapsedHours, 6)
    Time.setPaused(true)
    advance(t, Time.update(100), world); near(t.elapsedHours, 6)
    Time.setPaused(false)
    Time.setTimeScale(0)
    advance(t, Time.update(100), world); near(t.elapsedHours, 6)
    Time.setTimeScale(2)
    advance(t, Time.update(1), world); near(t.elapsedHours, 9.2)
    advance(t, 2.799, world); assert(t.status == "active")
    local rolls = 0
    Treatment.advance(t, 0.001, world, nil, function() rolls = rolls + 1; return 0 end)
    assert(t.status == "success" and rolls == 1)
    assert(Treatment.successProbability == 0.5 and t.durationHours == 12)
    Treatment.advance(t, 100, world, nil, function() error("Repeated completion") end)
    assert(count(party) == 3)
    injured(patient)
    random(function(n) if n then return 1 end; return 0.9 end, function()
        Treatment.update(25, world)
    end)
    assert(count(party) == 0 and #patient.injuries == 1 and patient.lastTreatment.status == "failure")
    t = Treatment.forHealer(healer)
    assert(t and t.elapsedHours == 1 and t.status == "active")
    random(function(n) if n then return 1 end; return 0 end, function() Treatment.update(11, world) end)
    assert(not Treatment.forHealer(healer) and #patient.injuries == 0)
    assert(not pcall(advance, t, -1, world) and not pcall(advance, t, 0/0, world))
    assert(not pcall(advance, t, math.huge, world))
end

local function automaticSelection()
    local world, map, party, healer, patient, actor = setup()
    local second = actor("healer-two", true)
    Parties.addActor(party, second)
    injured(patient)
    injured(healer)
    injured(healer, "wounded_arm", "right_arm")
    herbs(party, 3)
    local selections = 0
    random(function(n)
        assert(n, "Unexpected completion")
        selections = selections + 1
        return n -- Last patient, last injury, then remaining patient.
    end, function() Treatment.update(1, world) end)
    local first, other = Treatment.forHealer(healer), Treatment.forHealer(second)
    assert(first and other and first.patientId ~= other.patientId and selections == 4)
    assert(first.patientId == healer.id and first.injuryId == "wounded_arm")
    assert(other.patientId == patient.id and count(party) == 1)
    local lines = table.concat(Inspector.lines(map, "party", party.id), "\n")
    assert(lines:find("Healing Herbs") and lines:find("world hours") and lines:find("wounded_arm"))
    -- A healer in another party never borrows our supplies or treats our remaining injury.
    local foreign = Party.create(world, "Foreign")
    local foreignHealer = actor("foreign-healer", true)
    Parties.addActor(foreign, foreignHealer); map:addParty(foreign)
    herbs(foreign, 5)
    Treatment.update(1, world)
    assert(not Treatment.forHealer(foreignHealer) and count(foreign) == 5)
    -- No party: only self-treatment, even when another injured resident is present.
    world, map, party, healer, patient = setup(true)
    injured(healer); injured(patient); herbs(healer, 2)
    Treatment.update(1, world)
    assert(Treatment.forHealer(healer).patientId == healer.id and not Treatment.forPatient(patient))
    local selfTreatment = Treatment.forHealer(healer)
    Parties.addActor(party, healer); map:addParty(party)
    Treatment.update(0, world)
    assert(Treatment.forHealer(healer) == selfTreatment, "Joining a party separated an independent healer from themselves")
end

local function simultaneousTime()
    for _, increments in ipairs({{24}, {6, 6, 6, 6}}) do
        local world, _, party, healer, patient, actor = setup()
        local second = actor("second", true)
        Parties.addActor(party, second)
        injured(patient); injured(patient, "wounded_arm", "left_arm"); injured(patient, "damaged_eye", "head")
        herbs(party, 10)
        random(function(n) return n and 1 or 0 end, function()
            for _, hours in ipairs(increments) do Treatment.update(hours, world) end
        end)
        assert(#patient.injuries == 1 and count(party) == 8,
            "Multiple healers overlapped care on one patient during a large update")
    end
    -- Different parties run simultaneously, each spending only its own cargo.
    local world, map, party, healer, patient, actor = setup()
    local otherParty = Party.create(world, "Parallel")
    local otherHealer, otherPatient = actor("parallel-healer", true), actor("parallel-patient")
    Parties.addActor(otherParty, otherHealer); Parties.addActor(otherParty, otherPatient)
    map:addParty(otherParty)
    herbs(party); herbs(otherParty); injured(patient); injured(otherPatient)
    Treatment.update(6, world)
    near(Treatment.forHealer(healer).elapsedHours, 6)
    near(Treatment.forHealer(otherHealer).elapsedHours, 6)
    assert(count(party) == 0 and count(otherParty) == 0)
    random(function(n) return n and 1 or 0 end, function() Treatment.update(6, world) end)
    assert(#patient.injuries == 0 and #otherPatient.injuries == 0)
end

local function interruptions()
    for _, action in ipairs({"healer_dead", "patient_dead", "healer_removed", "patient_removed", "separated", "injury_changed", "capability_lost"}) do
        local world, _, party, healer, patient = setup()
        herbs(party)
        injured(patient, "sprained_ankle")
        Treatment.update(8, world)
        local t = Treatment.forHealer(healer)
        assert(t and t.elapsedHours == 8)
        if action == "healer_dead" then healer.hp = 0
        elseif action == "patient_dead" then patient.hp = 0
        elseif action == "healer_removed" then world:removeEntity(healer)
        elseif action == "patient_removed" then world:removeEntity(patient)
        elseif action == "separated" then
            Parties.removeActor(party, patient)
            assert(not Treatment.forHealer(healer), "Membership removal did not cancel immediately")
        elseif action == "injury_changed" then injured(patient)
        elseif action == "capability_lost" then healer.npc_goals.capabilities.heal = false end
        Treatment.update(0, world)
        assert(t.status == "cancelled" and not next(world.injuryTreatments) and count(party) == 0, action)
        assert(not Treatment.cancel(t, world), "Cancellation repeated")
    end
    local world, map, party, healer, patient, actor = setup()
    herbs(party, 2); injured(patient)
    Treatment.update(8, world)
    local t = Treatment.forHealer(healer)
    patient.activeEncounterId = "actor-combat"
    Treatment.update(10, world); near(t.elapsedHours, 8)
    patient.activeEncounterId = nil
    local enemy = Party.create(world, "Enemy")
    Parties.addActor(enemy, actor("enemy")); map:addParty(enemy)
    Game.data.playerParty = party
    BattleState.enter({enemyParty = enemy})
    assert(party.activeEncounterId and enemy.activeEncounterId)
    Treatment.update(20, world); near(t.elapsedHours, 8)
    BattleState.exit()
    assert(not party.activeEncounterId and not enemy.activeEncounterId)
    -- WorldEncounter owns headless reservations, including its completion frame.
    Game.data.playerParty = nil
    local ok, encounter = Encounters.start(map, party, enemy, {maxTicks = 0})
    assert(ok, tostring(encounter))
    local reserved = Recovery.encounterReservations(map)
    assert(reserved[healer] and reserved[patient])
    Treatment.update(10, world); near(t.elapsedHours, 8)
    Encounters.update(10, map)
    Treatment.update(10, world, reserved); near(t.elapsedHours, 8)
    assert(not party.activeEncounterId)
    random(function(n) if n then return 1 end; return 0 end, function() Treatment.update(4, world) end)
    assert(t.status == "success" and not Treatment.forHealer(healer))
    -- Campaign casualty application also releases treatment before returning.
    injured(patient); Treatment.update(1, world)
    local simulation = Simulation.new(party, enemy)
    for _, unit in ipairs(simulation.context.data.unitList) do
        if unit.id == patient.id then unit.hp = 0 end
    end
    local result = simulation:buildResult("timeout")
    Applier.apply(result, {parties = {party, enemy}, encounter = {state = "completed"}})
    assert(not Treatment.forHealer(healer) and not next(world.injuryTreatments))
    simulation:destroy()
    -- Removing a healer through the ID-based roster API cancels and releases its patient too.
    world, map, party, healer, patient = setup()
    herbs(party); injured(patient); Treatment.update(1, world)
    assert(Parties.removeFromParty(party, healer.id))
    assert(not Treatment.forPatient(patient) and not next(world.injuryTreatments))
end

local function travelGoalsAndClock()
    local world, map, party, healer, patient = setup()
    injured(patient); herbs(party)
    local destination = Location.create(world, nil, "Far town")
    destination.x, destination.y = 9000, 100
    map:addLocation(destination)
    Goals.configure(patient, {{type = "reach_location", destinationLocationId = destination.id, priority = 90},
        {type = "rest_and_recover"}}, {travel = true})
    Goals.update(1, map)
    assert(party.world_activity.type == "travel" and party.world_activity.status == "active")
    local sequence, x = party.world_activity.sequence, party.x
    local function tick(realSeconds)
        local hours, seconds = Runtime.advanceTime(realSeconds)
        local reserved = Runtime.updateEncounters(hours, seconds, map)
        Runtime.update(seconds, map, nil, false, reserved, hours)
    end
    tick(3.75) -- Actual clock is 1.6 game-hours per real second, regardless of old tests' 1.5 assumption.
    local t = Treatment.forHealer(healer)
    assert(t and t.elapsedHours == 6 and party.x > x)
    assert(party.world_activity.sequence == sequence and party.world_activity.type == "travel")
    assert(Importance.recovery(nil, patient, party) > 0 and patient.hp == patient.maxHp)
    assert(patient.npc_goals.goals[2].reason == "injury_treatment_in_progress")
    -- Explicit goal switch preserves committed treatment and its accumulated time.
    patient.npc_goals.goals[1].priority = 0
    Goals.addGoal(patient, {type = "return_home", importance = 95})
    patient.homeLocationId = destination.id
    patient.npc_goals.goals[3].accumulatedImportance = 95
    Goals.update(1, map)
    assert(Treatment.forHealer(healer) == t and t.elapsedHours == 6)
    assert(patient.npc_goals.previousDominantGoal == "reach_location", "Primary goal never switched")
    Time.setPaused(true); tick(100); near(t.elapsedHours, 6)
    Time.setPaused(false)
    random(function(n) if n then return 1 end; return 0 end, function() tick(3.75) end)
    assert(t.status == "success" and #patient.injuries == 0)
    -- Supply-less injuries retain urgency without repeatedly starting rest or cancelling travel.
    injured(patient)
    patient.npc_goals.goals[1].priority = 90
    patient.npc_goals.goals[3].accumulatedImportance = 0
    for _ = 1, 5 do Goals.update(1, map); Activities.update(1, map) end
    assert(patient.npc_goals.goals[2].reason == "injury_treatment_unavailable")
    assert(patient.npc_goals.goals[2].attempts == 0 and party.world_activity.type == "travel")
    local hp = patient.hp
    patient.hp = 50
    Recovery.update(1, map)
    assert(patient.hp > 50 and patient.hp < hp and #patient.injuries == 1)
end

local function waitingAndServices()
    local world, map, party, healer, patient = setup()
    injured(patient); herbs(party)
    Game.data.playerParty = party
    WorldState.currentMap, WorldState.isResting, WorldState.restInputLock = map, false, 0
    WorldState.interactionCooldowns = {}
    WorldState.camera = {update = function() end, screenToWorld = function() return -100, -100 end,
        getZoom = function() return 1 end}
    local originalInput, mouse = Input.isKeyDown, love.mouse
    love.mouse = {getPosition = function() return 0, 0 end}
    Input.isKeyDown = function(key) return key == "space" end
    local ok, err = xpcall(function()
        WorldState.update(3.75)
        local t = assert(Treatment.forHealer(healer))
        near(t.elapsedHours, 6)
        Input.isKeyDown = function() return false end
        WorldState.update(100); near(t.elapsedHours, 6)
        Input.isKeyDown = function(key) return key == "space" end
        random(function(n) if n then return 1 end; return 0 end, function() WorldState.update(3.75) end)
        assert(t.status == "success")
    end, debug.traceback)
    Input.isKeyDown, love.mouse = originalInput, mouse
    WorldState.currentMap, WorldState.camera = nil, nil
    assert(ok, err)
    world, map, party, healer, patient = setup(true)
    local place = Location.create(world, nil, "Settlement")
    map:addLocation(place)
    Locations.addNPC(place, healer); Locations.addNPC(place, patient)
    Goals.configure(healer, {{type = "provide_service"}}, {heal = true})
    patient.hp = 50
    local context = {world = world, map = map}
    local wound = injured(healer)
    herbs(healer, 2)
    local t = assert(Treatment.start(healer, healer, wound, healer))
    assert(not Services.isProviding(healer, context))
    assert(not Services.perform(healer, patient, "heal", context) and patient.hp == 50)
    local request = assert(Services.createRequest(patient, {type = "heal", requiredCapability = "heal"}, context))
    assert(not Services.accept(request.id, healer, context))
    Treatment.cancel(t, world)
    assert(Services.perform(healer, patient, "heal", context) and patient.hp == 90 and #healer.injuries == 1)
    -- Existing obligations suppress automatic treatment without consuming personal stock.
    assert(Services.accept(request.id, healer, context))
    Treatment.update(12, world)
    assert(not Treatment.forHealer(healer) and count(healer) == 1)
    assert(Services.complete(request.id, context))
    Treatment.update(1, world)
    assert(Treatment.forHealer(healer) and count(healer) == 0)
    local items = require("src.data.items")
    local stock = require("src.systems.items.trader_system").buildStockInventory(require("src.data.troops").elder)
    assert(items.healing_herbs.stackable and items.healing_herbs.value == 5 and not items.healing_herbs.durability)
    assert(Inventory.getItemCount({inventory = stock}, "healing_herbs") == 10)
end

return {run = function()
    eligibilityAndResources()
    anatomyAndSuccess()
    durationAndRepetition()
    automaticSelection()
    simultaneousTime()
    interruptions()
    travelGoalsAndClock()
    waitingAndServices()
    Time.reset()
end}
