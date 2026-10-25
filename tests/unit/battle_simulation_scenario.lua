local EcsWorld = require("src.ecs.world")
local Party = require("src.ecs.assemblages.party")
local Unit = require("src.ecs.assemblages.unit")
local PartySystem = require("src.systems.party_system")
local BattleSimulation = require("src.game.battle.battle_simulation")
local DecisionSystem = require("src.ecs.systems.decision_system")
local ExecutionSystem = require("src.ecs.systems.execution_system")

local function createParty(world, partyId, actorId, skills)
    local party = Party.create(world, partyId, nil, partyId)
    local actor = Unit.create(world, "soldier", actorId)
    actor.stats.health = 1000
    actor.stats.attack = 1000
    actor.stats.defense = 0
    actor.hp = actor.stats.health
    actor.maxHp = actor.stats.health
    actor.skills = skills or {attack = {learned = true}}
    actor.statusEffects = {
        burn = {
            remaining = 50,
            duration = 50,
            damagePerTick = 1,
            tickEvery = 1,
            tickCounter = 0
        }
    }
    PartySystem.addActor(party, actor)
    return party, actor
end

local function testSimulationInstances()
    local campaign = EcsWorld.init()
    local partyA, actorA = createParty(campaign, "sim-a", "actor-a")
    local partyB, actorB = createParty(campaign, "sim-b", "actor-b")

    local first = BattleSimulation.new(partyA, partyB)
    local second = BattleSimulation.new(partyA, partyB)
    local firstUnit = first.context.data.units[actorA.id]
    local secondUnit = second.context.data.units[actorA.id]

    assert(first.partyA == partyA and first.partyB == partyB, "simulation did not retain explicit parties")
    assert(first.world ~= second.world, "simulations share a Concord world")
    assert(first.world:getSystem(DecisionSystem) ~= second.world:getSystem(DecisionSystem),
        "simulations share a decision system instance")
    assert(first.world:getSystem(ExecutionSystem) ~= second.world:getSystem(ExecutionSystem),
        "simulations share an execution system instance")
    assert(first.context ~= second.context, "simulations share a battle context")
    assert(first.context.data ~= second.context.data, "simulations share mutable context data")
    assert(firstUnit ~= secondUnit, "simulations share battle-unit entities")
    assert(firstUnit.statusEffects.burn ~= secondUnit.statusEffects.burn, "status tables are shared between simulations")

    local secondUnitStartX = secondUnit.x
    first:tick()

    assert(firstUnit.x ~= 180, "AI movement did not advance")
    assert(secondUnit.x == secondUnitStartX, "ticking one simulation moved units in another")
    assert(#second.context.data.projectiles == 0, "projectile state is shared between simulations")
    assert(actorA.statusEffects.burn.remaining == 50, "battle tick mutated campaign status effects")
    assert(secondUnit.statusEffects.burn.remaining == 50, "battle tick mutated the other simulation's status effects")

    first:destroy()
    second:destroy()
end

local function testInteractiveBattle()
    local campaign = EcsWorld.init()
    local playerParty, playerActor = createParty(campaign, "interactive-player", "interactive-player-actor", {
        javelin_throw = {learned = true}
    })
    local enemyParty, enemyActor = createParty(campaign, "interactive-enemy", "interactive-enemy-actor")
    local GameContext = require("src.game.game_context")
    local BattleState = require("src.game.states.battle_state")
    local StateManager = require("src.core.state_manager")
    local EventBus = require("src.core.event_bus")
    local Input = require("src.core.input")

    GameContext.data.playerParty = playerParty
    GameContext.data.currentMap = {
        removeParty = function(_, partyId)
            if partyId == enemyParty.id then
                return true
            end
            return false
        end
    }
    EventBus.init()

    local previousSwap = StateManager.swap
    local lastTransition
    StateManager.swap = function(stateName, params)
        lastTransition = {name = stateName, params = params}
    end

    local ok, err = xpcall(function()
        BattleState.enter({enemyParty = enemyParty})
        local simulation = BattleState.simulation
        local context = simulation.context
        local playerUnit = context.data.units[playerActor.id]
        local enemyUnit = context.data.units[enemyActor.id]

        assert(simulation.partyA == playerParty and simulation.partyB == enemyParty)
        assert(context.data.selectedUnitId == playerActor.id, "interactive player unit was not selected")

        Input.keypressed("d")
        BattleState.update(0.05)
        Input.keyreleased("d")
        assert(playerUnit.x > 180, "player movement command did not execute")

        playerUnit.x = 500
        playerUnit.y = 200
        playerUnit.globalCooldown = 0
        enemyUnit.x = 550
        enemyUnit.y = 200
        context.data.playerCommand = {
            type = "SKILL",
            skillId = "javelin_throw",
            targetUnitId = enemyUnit.id,
            unitId = playerUnit.id
        }
        BattleState.update(0.05)
        assert(playerUnit.currentCast and playerUnit.currentCast.skillId == "javelin_throw",
            "player skill command did not start its cast")

        context.data.selectedUnitId = nil
        local projectileLaunched = false
        for _ = 1, 25 do
            BattleState.update(0.05)
            projectileLaunched = projectileLaunched or (playerUnit.charges.javelin_throw < 2)
        end
        assert(projectileLaunched, "projectile skill did not launch")

        enemyUnit.hp = 0
        context.removeDeadUnits()
        BattleState.checkBattleEnd()
        assert(lastTransition and lastTransition.name == "battle_end", "victory did not open battle-end flow")
        assert(lastTransition.params.victory == true)
        assert(playerActor.statusEffects.burn.remaining < 50, "battle status effects were not applied to the campaign actor")
        BattleState.exit()

        local defeatParty, defeatActor = createParty(campaign, "defeat-player", "defeat-player-actor")
        local survivingEnemyParty = createParty(campaign, "defeat-enemy", "defeat-enemy-actor")
        GameContext.data.playerParty = defeatParty
        GameContext.data.currentMap = nil
        lastTransition = nil
        BattleState.enter({enemyParty = survivingEnemyParty})
        local defeatContext = BattleState.simulation.context
        defeatContext.data.units[defeatActor.id].hp = 0
        defeatContext.removeDeadUnits()
        BattleState.checkBattleEnd()
        assert(lastTransition and lastTransition.name == "menu", "defeat did not preserve the existing menu transition")
        BattleState.exit()
    end, debug.traceback)

    StateManager.swap = previousSwap
    if not ok then
        error(err)
    end
end

local Scenario = {}

function Scenario.run()
    testSimulationInstances()
    testInteractiveBattle()
end

return Scenario
