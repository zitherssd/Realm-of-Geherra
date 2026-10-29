local Data = require("src.data.injuries")
local Injury = require("src.systems.actors.injury_system")
local Combat = require("src.systems.battle.combat_system")
local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.parties.party_system")
local Simulation = require("src.game.battle.battle_simulation")
local Runner = require("src.game.battle.headless_battle_runner")
local Applier = require("src.systems.campaign.campaign_battle_result_applier")
local Importance = require("src.systems.goals.goal_importance")
local Goals = require("src.systems.goals.goal_system")
local Recovery = require("src.systems.actors.recovery")
local Activities = require("src.systems.world_activities.world_activity_system")
local Map = require("src.world.map")
local Game = require("src.game.game_context")
local Bus = require("src.core.event_bus")

local function near(a, b) assert(math.abs(a - b) < 1e-8, tostring(a) .. " ~= " .. tostring(b)) end
local function injury(actor, id, part) return Injury.apply(actor, {id = id, bodyPart = part}) end
local function actor(profile) return {hp = 100, maxHp = 100, injuryProfile = profile or "humanoid", injuries = {}} end
local function sequence(values)
    local index = 0
    return function() index = index + 1; assert(values[index] ~= nil, "Extra injury roll"); return values[index] end,
        function() return index end
end
local function withRandom(rng, action)
    local original = math.random
    math.random = rng
    local ok, err = xpcall(action, debug.traceback)
    math.random = original
    assert(ok, err)
end
local function party(world, id)
    local group = Party.create(world, id, nil, id)
    local member = Unit.create(world, "soldier", id .. "-actor")
    member.hp, member.maxHp = 100, 100
    member.stats = {health = 100, attack = 10, defense = 10, speed = 16, battle_speed = 10}
    member.equipment, member.skills = {}, {}
    Parties.addActor(group, member)
    return group, member
end

local function probability()
    for _, pair in ipairs({{0, 0}, {0.025, 0.0025}, {0.05, 0.005}, {0.1, 0.01},
        {0.15, 0.02}, {0.2, 0.03}, {0.3, 0.07}, {0.4, 0.135}, {0.5, 0.2},
        {0.625, 0.35}, {0.75, 0.5}, {1, 0.5}, {2, 0.5}, {-1, 0}}) do
        near(Injury.interpolate(Data.occurrenceCurve, pair[1]), pair[2])
    end
    for _, pair in ipairs({{-1, 0}, {0, 0}, {0.2, 0}, {0.3, 0}, {0.4, 0.1},
        {0.5, 0.2}, {0.75, 0.6}, {1, 1}, {2, 1}}) do
        near(Injury.interpolate(Data.majorCurve, pair[1]), pair[2])
    end
    assert(Injury.interpolate(Data.majorCurve, 0/0) == 0)
    local rng, calls = sequence({0.49, 0.59, 0, 0})
    local target = actor()
    assert(Injury.fromDamage(target, 75, rng))
    assert(Data.definitions[target.injuries[1].id].severity == "major" and calls() == 4)
    rng, calls = sequence({0.49, 0.61, 0, 0})
    target = actor()
    assert(Injury.fromDamage(target, 75, rng))
    assert(Data.definitions[target.injuries[1].id].severity == "minor" and calls() == 4)
    rng, calls = sequence({0.5})
    assert(not Injury.fromDamage(actor(), 75, rng) and calls() == 1)
    rng, calls = sequence({0, 0, 0, 0})
    target = actor()
    assert(Injury.fromDamage(target, 20, rng))
    assert(Data.definitions[target.injuries[1].id].severity == "minor")
    local never = function() error("Invalid damage consumed RNG") end
    for _, damage in ipairs({0, -1, 0/0, math.huge}) do assert(not Injury.fromDamage(actor(), damage, never)) end
    for _, maximum in ipairs({0, -1, 0/0, math.huge, "bad"}) do
        target = actor(); target.maxHp = maximum
        assert(not Injury.fromDamage(target, 75, never))
    end
    target = actor(); target.maxHp = nil
    assert(not Injury.fromDamage(target, 75, never))
    target = actor(); target.hp = 0
    assert(not Injury.fromDamage(target, 75, never))
end

local function profilesAndReplacement()
    assert(Data.validate())
    for profileId, profile in pairs(Data.profiles) do
        local total, before = 0, 0
        for _, part in ipairs(profile.bodyParts) do total = total + part.weight end
        for _, part in ipairs(profile.bodyParts) do
            for _, severity in ipairs({"minor", "major"}) do
                local target = actor(profileId)
                local rng = sequence({0, severity == "major" and 0 or 0.99, (before + part.weight / 2) / total, 0})
                assert(Injury.fromDamage(target, 75, rng))
                local entry = target.injuries[1]
                assert(entry.bodyPart == part.id)
                assert(Injury.definition(target, entry).severity == severity)
                assert(Injury.definition(target, entry).category == part.category)
            end
            before = before + part.weight
        end
    end
    local never = function() error("Invalid anatomy consumed RNG") end
    assert(not Injury.fromDamage(actor("missing"), 75, never))
    local target = actor(); target.injuryProfile = nil
    assert(not Injury.fromDamage(target, 75, never))
    Data.profiles.invalid = {bodyParts = {{id = "wrong", weight = 1, category = "missing"}}}
    target = actor("invalid")
    assert(not Injury.fromDamage(target, 75, never))
    near(Injury.stat(target, "attack", 10), 10)
    assert(not pcall(Data.validate)); Data.profiles.invalid = nil
    local oldWeight = Data.definitions.concussion.weight
    Data.definitions.concussion.weight = -1
    assert(not pcall(Data.validate)); Data.definitions.concussion.weight = oldWeight
    target = actor()
    assert(injury(target, "sprained_ankle", "left_leg"))
    assert(injury(target, "broken_leg", "left_leg"))
    assert(not injury(target, "sprained_ankle", "left_leg"))
    assert(not injury(target, "broken_leg", "left_leg"))
    local rng, count = sequence({0, 0, 0.65, 0})
    assert(not Injury.fromDamage(target, 75, rng) and count() == 4, "Unchanged injury rerolled its location")
    assert(injury(target, "sprained_ankle", "right_leg") and #target.injuries == 2)
    assert(not injury(actor("plant"), "broken_leg", "roots"))
    assert(Injury.validate(target, target.injuries))
    assert(not pcall(Injury.validate, target, {{id = "broken_leg", bodyPart = "left_leg"},
        {id = "sprained_ankle", bodyPart = "left_leg"}}))
    assert(not pcall(Injury.validate, target, {{id = "missing", bodyPart = "left_leg"}}))
    local troops = require("src.data.troops")
    assert(troops.ogre.injuryProfile == "humanoid" and troops.dragon.injuryProfile == "dragon")
    assert(troops.wolf.injuryProfile == "quadruped" and troops.hutzu_pony.injuryProfile == "quadruped")
    assert(troops.gaia_walking_tree.injuryProfile == "plant")
    for _, roll in ipairs({0, 0.99}) do
        local head = actor()
        assert(Injury.fromDamage(head, 20, sequence({0, 0.99, 0.99, roll})))
        assert(head.injuries[1].id == (roll == 0 and "concussion" or "facial_wound"))
    end
end

local function effects()
    local Math = require("src.utils.math")
    local oldRoll = Math.rollExploding
    Math.rollExploding = function() return 1 end
    local ok, err = pcall(function()
        local attacker, defender = actor(), actor()
        attacker.stats, defender.stats = {attack = 10}, {defense = 9}
        assert(Combat.rollAttack(attacker, defender))
        injury(attacker, "crushed_hand", "left_arm")
        assert(not Combat.rollAttack(attacker, defender))
        injury(defender, "severe_chest_injury", "torso")
        assert(Combat.rollAttack(attacker, defender))
        assert(attacker.stats.attack == 10 and defender.stats.defense == 9)
    end)
    Math.rollExploding = oldRoll
    assert(ok, err)
    local world = Ecs.init()
    local group, member = party(world, "effects")
    local baseline = Parties.getPartySpeed(group)
    injury(member, "broken_leg", "left_leg")
    near(Parties.getPartySpeed(group), baseline * 0.6)
    local Movement = require("src.systems.parties.party_ai_system")
    -- All manual/AI/Travel callers use the same authoritative party speed.
    local oldX = group.x
    Movement.moveToward(group, oldX + 1000, group.y, Parties.worldSpeed, 1)
    near(group.x - oldX, baseline * 0.6)
    local Visibility = require("src.systems.parties.visibility_system")
    member.sight = 100
    local divisor = require("src.data.visibility").radiusDivisor or 1
    local target = {x = group.x + 80 / divisor, y = group.y, actors = {}}
    assert(Visibility.canSee(group, target))
    injury(member, "damaged_eye", "head")
    near(Parties.getPartySight(group), 65)
    assert(not Visibility.canSee(group, target))
    member.hp = 10
    Recovery.advance(member, 1000, Recovery.restHealMultiplier)
    assert(member.hp == 100 and #member.injuries == 2)
    near(Injury.effects(member).movementSpeedMultiplier, 0.6)
    local other = party(world, "effects-other")
    injury(member, "crushed_hand", "left_arm")
    local sim = Simulation.new(group, other)
    local battle = sim.context.data.units[member.id]
    near(Injury.stat(battle, "attack", battle.stats.attack), 5)
    near(battle.stats.attack, 10)
    local Execution = require("src.systems.battle.execution_system")
    near(Injury.stat(battle, "battle_speed", battle.stats.battle_speed), 6)
    withRandom(function() return 0.5 end, function()
        Execution._executeMove(battle, {target = {x = battle.x + 100, y = battle.y}}, sim.context)
    end)
    near(battle.moveCooldown, 20)
    near(battle.globalCooldown, 20)
    near(battle.stats.battle_speed, 10)
    battle.globalCooldown = 0
    injury(battle, "sprained_ankle", "right_leg")
    withRandom(function() return 0.5 end, function()
        Execution._executeMove(battle, {target = {x = battle.x + 100, y = battle.y}}, sim.context)
    end)
    near(battle.moveCooldown, 120 / (10 * 0.6 * 0.85))
    assert(#member.injuries == 3, "New battle speed injury changed campaign state")
    injury(battle, "severe_chest_injury", "torso")
    assert(#member.injuries == 3 and #battle.injuries == 5)
    sim:destroy()
    assert(table.concat(Injury.lines(member), " "):find("major, left leg")
        and table.concat(Injury.lines(member), " "):find("Movement %-40%%"))
    assert(Injury.lines(actor())[1] == "Injuries: none")
end

local function damageAndPersistence()
    local world = Ecs.init()
    local a, aa = party(world, "persistent-a")
    local b, bb = party(world, "persistent-b")
    injury(aa, "sprained_ankle", "left_leg")
    injury(bb, "concussion", "head")
    local runner = Runner.start(a, b, {maxTicks = 0})
    local unit = runner.simulation.context.data.units[aa.id]
    local other = Simulation.new(a, b)
    local rng, calls = sequence({0, 0, 0.65, 0}) -- 75 damage, major, left leg
    withRandom(rng, function() Combat._applyBattleDamage(unit, 75) end)
    assert(calls() == 4 and unit.hp == 25 and unit.injuries[1].id == "broken_leg")
    assert(aa.hp == 100 and aa.injuries[1].id == "sprained_ankle")
    assert(other.context.data.units[aa.id].injuries[1].id == "sprained_ankle")
    local result = runner:advance(0)
    assert(runner:getResult() == result and result.actors[aa.id].injuries[1].id == "broken_leg")
    local encounter = {state = "completed"}
    local context = {parties = {a, b}, encounter = encounter}
    local saved = result.actors[aa.id].injuries
    result.actors[aa.id].injuries = {{id = "broken_leg", bodyPart = "head"}}
    assert(not pcall(Applier.apply, result, context) and aa.hp == 100, "Invalid injury partially mutated campaign")
    result.actors[aa.id].injuries = saved
    Applier.apply(result, context)
    assert(aa.hp == 25 and aa.injuries[1].id == "broken_leg" and #aa.injuries == 1)
    assert(bb.injuries[1].id == "concussion", "Surviving enemy lost an old injury")
    assert(not pcall(Applier.apply, result, context))
    unit.injuries[1].id = "sprained_ankle"
    assert(aa.injuries[1].id == "broken_leg", "Campaign aliases battle injury entries")
    runner:cleanup(); runner:cleanup(); other:destroy()
    assert(runner.simulation == nil and runner.state == "cleaned")
    withRandom(function() error("Fatal, zero or status damage rolled injuries") end, function()
        local target = actor()
        Combat._applyBattleDamage(target, 0)
        Combat._applyBattleDamage(target, 10, true)
        Combat._applyBattleDamage(target, 1000)
        assert(#target.injuries == 0)
    end)
    -- The resolver rolls only once, after mitigation, for either attack path.
    local oldAttack, oldDamage, oldProjectile = Combat.rollAttack, Combat.calculateDamage, Combat.rollProjectileDefense
    Combat.rollAttack = function() return true end
    Combat.rollProjectileDefense = function() return true end
    Combat.calculateDamage = function() return 75 end
    local ok, err = pcall(function()
        for _, resolve in ipairs({Combat.resolveAttack, Combat.resolveProjectileAttack}) do
            local target = actor()
            local random, count = sequence({0, 0, 0, 0})
            withRandom(random, function() assert(resolve({}, target, {}).damage == 75) end)
            assert(count() == 4 and #target.injuries == 1)
        end
    end)
    Combat.rollAttack, Combat.calculateDamage, Combat.rollProjectileDefense = oldAttack, oldDamage, oldProjectile
    assert(ok, err)
    -- A later fatal blow still removes an already injured actor.
    runner = Runner.start(a, b, {maxTicks = 0})
    local victim = runner.simulation.context.data.units[bb.id]
    injury(victim, "broken_leg", "left_leg")
    Combat._applyBattleDamage(victim, 1000)
    runner.simulation.context.removeDeadUnits()
    result = runner:advance(0)
    Applier.apply(result, {parties = {a, b}, encounter = {state = "completed"}})
    assert(#b.actors == 0 and bb.hp == 0 and #bb.injuries == 1 and bb.injuries[1].id == "concussion")
    runner:cleanup()
end

local function recoveryAndInspection()
    Bus.init(); Game.init(); Activities.init()
    local world, map = Ecs.init(), Map.new("injury-recovery")
    Game.data.currentMap = map
    local group, member = party(world, "injured-leader")
    member:ensure("memory")
    map:addParty(group)
    local state = Goals.configure(member, {{type = "rest_and_recover"}}, {})
    local rest = state.goals[1]
    injury(member, "sprained_ankle", "left_leg")
    local minor = Goals.getImportance(rest, member, group)
    injury(member, "broken_leg", "left_leg")
    assert(minor > 0 and Goals.getImportance(rest, member, group) > minor)
    for _ = 1, 20 do Goals.update(1, map); Activities.update(1, map) end
    assert(rest.status == "blocked" and rest.reason == "injury_treatment_unavailable")
    assert(not rest.recovering and rest.attempts == 0 and group.world_activity.status == "idle")
    local follower = Unit.create(world, "soldier")
    follower.hp, follower.maxHp = 100, 100
    Parties.addActor(group, follower)
    assert(Importance.recovery(nil, follower, group) == 0, "Follower considered its leader")
    member.injuries = {}
    injury(follower, "broken_leg", "right_leg")
    assert(Importance.recovery(nil, member, group) > 0)
    follower.hp = 0
    assert(Importance.recovery(nil, member, group) == 0, "Dead member counted")
    follower.hp = 100
    injury(member, "broken_leg", "left_leg")
    member.hp = 50
    Goals.update(1, map); Activities.update(1, map)
    assert(group.world_activity.type == "rest" and group.world_activity.status == "active")
    Recovery.update(1000, map)
    Activities.update(1, map); Goals.update(1, map)
    assert(member.hp == 100 and #member.injuries == 1 and not rest.recovering)
    assert(rest.status == "blocked" and Goals.getImportance(rest, member, group) > 0)
    local text = table.concat(require("src.debug.inspector").lines(map, "unit", member.id), "\n")
    assert(text:find("Broken leg") and text:find("major, left leg") and text:find("injury_treatment_unavailable"))
    for _, part in ipairs(Data.profiles.humanoid.bodyParts) do
        injury(member, Data.candidates(part.category, "major")[1].id, part.id)
    end
    assert(Goals.getImportance(rest, member, group) <= 100)
    -- Untreatable recovery does not hold dominance over a feasible goal.
    Goals.configure(member, {{type = "rest_and_recover"}, {type = "return_home", accumulatedImportance = 20}}, {})
    local home = require("src.ecs.assemblages.location").create(world, "injured-home", "Home")
    map:addLocation(home); map:stationParty(home, group); member.homeLocationId = home.id
    Goals.update(0.1, map)
    assert(member.npc_goals.selectedGoalIndex == 2)
end

local function interactiveAndEncounter()
    local Battle = require("src.game.states.battle_state")
    local State = require("src.core.state_manager")
    Bus.init(); Game.init()
    local world = Ecs.init()
    local a, aa = party(world, "interactive-injury")
    local b, bb = party(world, "interactive-victim")
    Game.data.playerParty = a
    Game.data.currentMap = {getParties = function() return {a, b} end, removeParty = function() return true end}
    aa:ensure("memory"); aa:ensure("player")
    local companion = Unit.create(world, "soldier")
    Parties.addActor(a, companion)
    injury(aa, "sprained_ankle", "right_leg")
    Battle.enter({enemyParty = b})
    local unit = Battle.simulation.context.data.units[aa.id]
    withRandom(sequence({0, 0, 0, 0}), function() Combat._applyBattleDamage(unit, 75) end)
    local companionUnit = Battle.simulation.context.data.units[companion.id]
    withRandom(sequence({0, 0, 0.99, 0}), function()
        Combat._applyBattleDamage(companionUnit, companionUnit.maxHp * 0.5)
    end)
    Combat._applyBattleDamage(Battle.simulation.context.data.units[bb.id], 1000)
    Battle.simulation.context.removeDeadUnits()
    local oldSwap = State.swap
    State.swap = function() end
    local ok, err = pcall(function() Battle.checkBattleEnd(); Battle.checkBattleEnd() end)
    State.swap = oldSwap
    assert(ok, err)
    assert(aa.hp == 25 and #aa.injuries == 2 and #b.actors == 0)
    assert(#companion.injuries == 1 and companion.injuries[1].id == "damaged_eye")
    Battle.exit(); assert(Battle.simulation == nil)
    local Encounters = require("src.systems.campaign.world_encounter_system")
    local map = Map.new("injury-encounter")
    a, aa = party(world, "world-injury-a"); b, bb = party(world, "world-injury-b")
    map:addParty(a); map:addParty(b)
    Game.data.currentMap = map; Game.data.playerParty = nil
    local started, encounter = Encounters.start(map, a, b)
    assert(started)
    withRandom(sequence({0, 0, 0, 0}), function()
        Combat._applyBattleDamage(encounter.runner.simulation.context.data.units[aa.id], 75)
    end)
    Combat._applyBattleDamage(encounter.runner.simulation.context.data.units[bb.id], 1000)
    Encounters.update(0, map)
    assert(#aa.injuries == 1 and aa.hp == 25 and #b.actors == 0)
    assert(not a.activeEncounterId and not aa.activeEncounterId and encounter.runner == nil)
    assert(next(map.activeEncounters) == nil)
end

local function statsPanel()
    local Panel = require("src.ui.widgets.stats_panel")
    local target = actor()
    target.stats = {attack = 10, defense = 10, speed = 16}
    target.sight = 100
    injury(target, "broken_leg", "left_leg")
    injury(target, "damaged_eye", "head")
    local canvas = love.graphics.newCanvas(560, 380)
    for _, width in ipairs({350, 540}) do
        local panel = Panel.new(10, 10, width, 190)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.08, 0.08, 0.08, 1)
        panel:draw(target)
        panel:wheelmoved(0, -20)
        assert(panel.scrollOffset > 0, "Injuries cannot be scrolled into view")
        panel:draw(target)
        love.graphics.setCanvas()
    end
    -- A render artifact for visual QA; never writes into the repository.
    local file = assert(io.open(os.getenv("TEMP") .. "/geherra-injury-stats.png", "wb"))
    file:write(canvas:newImageData():encode("png"):getString()); file:close()
end

return {run = function()
    probability(); profilesAndReplacement(); effects(); damageAndPersistence()
    recoveryAndInspection(); interactiveAndEncounter(); statsPanel()
end}
