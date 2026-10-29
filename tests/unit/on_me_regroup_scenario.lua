local World = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Simulation = require("src.game.battle.battle_simulation")
local Squads = require("src.game.battle.squads")
local Decision = require("src.systems.battle.decision_system")
local Execution = require("src.systems.battle.execution_system")
local Scenario = {}
function Scenario.run()
    local world=World.init()
    local leader=Unit.create(world,"player","regroup-leader")
    local actor=Unit.create(world,"soldier","regroup-soldier")
    local hostile=Unit.create(world,"soldier","regroup-enemy")
    local party={id="regroup-party",leaderId=leader.id,actors={leader,actor}}
    assert(Squads.create(party))
    local sim=Simulation.new(party,{id="regroup-enemies",actors={hostile}},true)
    local c=sim.context
    local unit,enemy=c.data.units[actor.id],c.data.units[hostile.id]
    unit.skills,unit.equipment={attack={level=1}},{}
    unit.hp,unit.maxHp=200,200
    unit.stats.battle_speed=10
    enemy.skills,enemy.equipment={attack={level=1}},{}
    local function decide()
        unit.intent=nil
        Decision._processAI(unit,c)
        return unit.intent
    end
    Squads.command(c,"player","charge")
    unit.x,unit.y=400,273
    enemy.x,enemy.y=444,273
    assert(decide().type=="SKILL","Charge melee behavior changed")
    local commander=c.data.playerUnit
    Execution._initiateSkill(commander,{skillId="on_me"},c)
    local goal=Squads.position(unit)
    local intent=decide()
    assert(intent.type=="MOVE" and intent.target.x==goal.x,"On Me did not prioritize disengagement")
    local x=unit.x
    Execution._executeMove(unit,intent,c)
    assert(unit.x==x-24 and unit.globalCooldown>=10.8 and unit.globalCooldown<=13.2,tostring(unit.x).." cd="..unit.globalCooldown)
    -- Retreat has no immunity: the nearby enemy still chooses and resolves its normal attack.
    enemy.x=unit.x+42
    enemy.stats.attack,enemy.stats.strength=100,50
    unit.stats.defense=0
    enemy.intent=nil
    Decision._processAI(enemy,c)
    assert(enemy.intent.type=="SKILL" and enemy.intent.targetUnitId==unit.id)
    local hp=unit.hp
    Execution._executeSkillEffect(enemy,"attack",unit.id,nil,c)
    assert(unit.hp<hp,"retreating unit could not be attacked")
    -- A blocking enemy can be fought after an actual failed movement attempt.
    unit.globalCooldown=0
    unit.x,unit.y=400,273
    enemy.x,enemy.y=358,273
    intent=decide()
    assert(intent.type=="MOVE")
    Execution._executeMove(unit,intent,c)
    assert(unit.x==400 and unit.velocityX==0)
    assert(decide().type=="SKILL","blocked regrouping unit remained inactive")
    assert(decide().type=="MOVE","blocked unit abandoned regrouping after fighting")
    -- Clear the obstruction; movement continues until the inner arrival tolerance.
    enemy.x,enemy.y=1000,273
    for _=1,12 do
        intent=decide()
        if intent then
            assert(intent.type=="MOVE")
            unit.globalCooldown=0
            Execution._executeMove(unit,intent,c)
        end
    end
    assert(not unit.regrouping and (unit.x-goal.x)^2+(unit.y-goal.y)^2<=12^2)
    enemy.x,enemy.y=unit.x+30,unit.y
    assert(decide().type=="SKILL","reformed unit did not resume attacking")
    unit.x=goal.x+18
    assert(decide().type=="SKILL" and not unit.regrouping,"outer tolerance caused jitter")
    unit.x=goal.x+25
    assert(decide().type=="MOVE" and unit.regrouping)
    unit.x=goal.x+18
    assert(decide().type=="MOVE","regrouping ended before inner tolerance")
    unit.x=goal.x+11
    assert(decide().type=="SKILL" and not unit.regrouping)
    Squads.command(c,"player","charge")
    unit.x=400
    enemy.x=430
    assert(decide().type=="SKILL" and not unit.regrouping)
    sim:destroy()
    print("On Me melee disengagement, blocked fallback, reformation and hysteresis PASS")
end
return Scenario
