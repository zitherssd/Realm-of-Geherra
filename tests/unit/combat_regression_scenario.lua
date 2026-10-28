local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.parties.party_system")
local Combat = require("src.systems.battle.combat_system")
local Skills = require("src.data.skills")
local Items = require("src.data.items")
local Math = require("src.utils.math")
local Execution = require("src.systems.battle.execution_system")
local Simulation = require("src.game.battle.battle_simulation")
local Runner = require("src.game.battle.headless_battle_runner")
local Encounters = require("src.systems.campaign.world_encounter_system")
local Map = require("src.world.map")
local InventoryScreen = require("src.ui.screens.inventory_screen")

local function party(world, id, equipment, skills)
    local result = Party.create(world, id, nil, id)
    local actor = Unit.create(world, "soldier", id .. "-actor")
    actor.equipment, actor.skills = equipment or {}, skills or {}
    actor.inventory, actor.itemDurability = {}, {}
    actor.stats.strength, actor.stats.battle_speed = 0, 120
    actor.hp, actor.maxHp, actor.stats.health = 100, 100, 100
    Parties.addActor(result, actor)
    return result, actor
end

local function testEquipmentSwaps()
    local actor = {equipment = {mainHand = "iron_sword", offHand = "dagger"},
        availableSlots = {"mainHand", "offHand"}, attributes = {shadowcraft = 2}}
    local screen = setmetatable({actor = actor, party = {inventory = {}}, gridY = 0,
        _slotAt = function() return {slotId = "mainHand"} end}, InventoryScreen)
    local function drag()
        screen.dragging = {item = Items.dagger, source = "equipment", slot = "offHand"}
        screen:mousereleased(10, 10, 1)
    end
    drag()
    assert(actor.equipment.mainHand == "iron_sword" and actor.equipment.offHand == "dagger",
        "A rejected swap changed equipment")
    assert(#screen.party.inventory == 0, "A rejected swap fell through to unequipping")
    actor.equipment.mainHand = "poison_dagger"
    drag()
    assert(actor.equipment.mainHand == "dagger" and actor.equipment.offHand == "poison_dagger",
        "Compatible equipment did not swap")
    actor.equipment.mainHand = nil
    drag()
    assert(actor.equipment.mainHand == "poison_dagger" and actor.equipment.offHand == nil,
        "Moving equipment to an empty slot duplicated it")
end

local function testSkillDamageAndModifiers()
    local target = {protections = {fire = 0, slashing = 100, piercing = 0, blunt = 0}}
    local attacker = {stats = {strength = 0}, equipment = {mainHand = "fire_wand"}}
    assert(Combat.calculateDamage(attacker, target, Skills.fireball) == 15, "Fireball ignored its base damage")
    attacker.equipment.mainHand = "greatsword"
    assert(Combat.calculateDamage(attacker, target, Skills.fireball) == 15, "A sword changed spell damage")
    attacker.equipment.rangedWeapon = "javelin"
    assert(Combat.calculateDamage(attacker, target, Skills.javelin_throw) == 15,
        "A javelin used main-hand damage")
    attacker.equipment.mainHand = "fire_sword"
    assert(Combat.calculateDamage(attacker, target, Skills.attack) == 13,
        "The fire sword used slashing protection")
    assert(Combat.getEffectiveSkill(attacker, "attack").onHitStatuses[1] == "burn")

    local world = Ecs.init()
    local a, actor = party(world, "spear", {mainHand = "spear"})
    local b = party(world, "spear-target")
    local simulation = Simulation.new(a, b)
    local unit, enemy = simulation.context.data.unitList[1], simulation.context.data.unitList[2]
    unit.x, enemy.x, enemy.y = 100, 155, unit.y
    unit.stats.attack, enemy.stats.defense = 100, 0
    Execution._executeSkillEffect(unit, "attack", enemy.id, nil, simulation.context)
    assert(enemy.hp == 92, "The spear did not hit beyond the base attack reach")
    assert(actor.equipment.mainHand == "spear", "Battle changed campaign equipment")
    simulation:destroy()
end

local function testStatuses()
    for _, entry in ipairs({{"fireball", "burn"}, {"shield_bash", "stun"},
        {"frostbolt", "freeze"}, {"lightning", "paralyze"}}) do
        local target = {statusEffects = {}, visualX = 0, visualY = 0}
        Execution.applyAttackResult({hit = true, damage = 1}, target, {}, Skills[entry[1]])
        local effect = target.statusEffects[entry[2]]
        assert(effect and effect.remaining == require("src.data.statuses")[entry[2]].duration,
            entry[1] .. " did not apply " .. entry[2])
    end
    local target = {statusEffects = {}, visualX = 0, visualY = 0}
    local skill = Combat.getEffectiveSkill({equipment = {mainHand = "poison_dagger"}}, "attack")
    Execution.applyAttackResult({hit = true, damage = 1}, target, {}, skill)
    assert(target.statusEffects.poison.damagePerTick == 2, "Weapon status configuration was lost")
end

local function testCasterRange()
    local world = Ecs.init()
    local a, actorA = party(world, "caster-a", {mainHand = "fire_wand"}, {fireball = {learned = true}})
    local b, actorB = party(world, "caster-b", {mainHand = "fire_wand"}, {fireball = {learned = true}})
    local result = Runner.run(a, b, {maxTicks = 400})
    assert(result.actors[actorA.id].finalHp < 100 or result.actors[actorB.id].finalHp < 100,
        "Fireball casters stalled outside casting range")
    assert(actorA.hp == 100 and actorB.hp == 100, "Headless simulation changed campaign HP")
end

local function testShieldPersistence()
    for _, defeated in ipairs({false, true}) do
        local world = Ecs.init()
        require("src.core.event_bus").init()
        require("src.game.game_context").init()
        require("src.systems.campaign.time_system").reset()
        local map = Map.new("shield-persistence-" .. tostring(defeated))
        local a, actorA = party(world, "shield-a", {offHand = "wooden_shield"})
        local b, actorB = party(world, "shield-b", {offHand = "wooden_shield"})
        actorA.itemDurability.wooden_shield, actorB.itemDurability.wooden_shield = 3, 1
        map:addParty(a); map:addParty(b)
        local started, encounter = Encounters.start(map, a, b, {maxTicks = 0})
        assert(started)
        local context = encounter.runner.simulation.context
        local unitA, unitB = context.data.units[actorA.id], context.data.units[actorB.id]
        local function block(unit)
            local result = Combat.resolveAttack({}, unit, Skills.attack)
            Execution.applyAttackResult(result, unit, context, Skills.attack)
        end
        block(unitA); block(unitB)
        assert(unitA.itemDurability.wooden_shield == 2, "A block consumed durability twice")
        assert(not unitB.equipment.offHand, "A one-durability shield did not break")
        assert(actorA.itemDurability.wooden_shield == 3 and actorB.equipment.offHand == "wooden_shield",
            "Battle mutated campaign equipment before applying its result")
        if defeated then unitB.hp = 0; context.removeDeadUnits() end
        Encounters.update(0, map)
        assert(actorA.itemDurability.wooden_shield == 2, "Survivor shield wear was not persisted")
        if defeated then
            assert(#encounter.lootResult.destroyedResources.items == 1, "Broken casualty shield was not destroyed")
            for _, resource in ipairs(encounter.lootResult.combatLoot) do
                assert(resource.item.id ~= "wooden_shield", "Broken shield returned as loot")
            end
        else
            assert(not actorB.equipment.offHand, "Broken survivor shield returned after battle")
            local nextBattle = Simulation.new(a, b)
            assert(nextBattle.context.data.units[actorA.id].itemDurability.wooden_shield == 2,
                "Next battle reset shield wear")
            assert(not nextBattle.context.data.units[actorB.id].equipment.offHand)
            nextBattle:destroy()
        end
    end
end

local function testInteractiveShieldPersistence()
    local world = Ecs.init()
    local Game = require("src.game.game_context")
    local StateManager = require("src.core.state_manager")
    local BattleState = require("src.game.states.battle_state")
    Game.init()
    require("src.core.event_bus").init()
    require("src.systems.campaign.time_system").reset()
    local a, actor = party(world, "interactive-shield", {offHand = "wooden_shield"})
    local b, enemy = party(world, "interactive-shield-enemy")
    actor.itemDurability.wooden_shield = 1
    Game.setPlayerParty(a)
    local previousSwap = StateManager.swap
    StateManager.swap = function() end
    local ok, err = xpcall(function()
        BattleState.enter({enemyParty = b})
        local context = BattleState.simulation.context
        local unit = context.data.units[actor.id]
        Execution.applyAttackResult(Combat.resolveAttack({}, unit, Skills.attack), unit, context, Skills.attack)
        context.data.units[enemy.id].hp = 0
        context.removeDeadUnits()
        BattleState.checkBattleEnd()
        assert(not actor.equipment.offHand and not actor.itemDurability.wooden_shield,
            "Interactive battle restored a broken shield")
    end, debug.traceback)
    BattleState.exit()
    StateManager.swap = previousSwap
    if not ok then error(err, 0) end
end

local Scenario = {}
function Scenario.run()
    local previousRoll, previousAttack, previousRandom = Math.rollExploding, Combat.rollAttack, math.random
    local ok, err = xpcall(function()
        Math.rollExploding = function() return 1 end
        math.random = function(first, second)
            if second then return first end
            return first and 1 or 0.5
        end
        testEquipmentSwaps()
        testSkillDamageAndModifiers()
        testStatuses()
        testCasterRange()
        Combat.rollAttack = function() return false, -1, 2 end
        testShieldPersistence()
        testInteractiveShieldPersistence()
    end, debug.traceback)
    Math.rollExploding, Combat.rollAttack, math.random = previousRoll, previousAttack, previousRandom
    if not ok then error(err, 0) end
end
return Scenario
