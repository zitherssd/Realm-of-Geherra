local Squads = require("src.game.battle.squads")
local World = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Simulation = require("src.game.battle.battle_simulation")
local Decision = require("src.systems.battle.decision_system")
local Execution = require("src.systems.battle.execution_system")
local PartySystem = require("src.systems.parties.party_system")
local Scenario = {}
function Scenario.run()
    local world = World.init()
    local actors = {}
    for i=1,5 do actors[i]=Unit.create(world,"soldier","squad"..i) end
    actors[1].troopType,actors[1].attributes.command = "player",3
    local party = {id="a",leaderId=actors[1].id,actors=actors}
    local enemy = {id="b",actors={Unit.create(world,"soldier","hostile")}}
    assert(Squads.create(party))
    local configs = Squads.reconcile(party)
    assert(#configs==1 and #configs[1].members==5)
    configs[2]={members={actors[5].id,"invalid"},formation="line",x=400,y=450}
    table.remove(configs[1].members,5)
    Squads.reconcile(party)
    assert(#configs[2].members==1)
    local removed = actors[5].id
    PartySystem.removeFromParty(party,removed)
    assert(#configs[2].members==0)
    for _,formation in ipairs({"line","box"}) do
        local slots=Squads.slots({{size=2},{size=3},{size=5}},formation)
        for _,c in ipairs(slots) do c.x,c.y=c.x+300,c.y+273 end
        assert(Squads.valid(slots,{width=600,height=546}))
        assert(not Squads.valid(slots,{width=10,height=10}))
        assert(not Squads.valid(slots,{width=600,height=546},{slots[1]}))
    end
    local sim=Simulation.new(party,enemy,true)
    local c=sim.context
    local leader=c.data.playerUnit
    local squad=c.data.squads[1]
    local unit=squad.members[1]
    local target=c.data.units[enemy.actors[1].id]
    assert(squad.order=="hold" and c.data.squads[3].order=="charge")
    local pos=Squads.position(unit)
    leader.y=leader.y+100
    local nextPos=Squads.position(unit)
    assert(pos.y==nextPos.y and pos.x==nextPos.x)
    leader.x=leader.x+24
    nextPos=Squads.position(unit)
    assert(nextPos.x==pos.x+24 and nextPos.y==pos.y)
    local stable=squad.assignments[unit.id]
    Squads.position(unit)
    assert(squad.assignments[unit.id]==stable)
    unit.x,unit.y=nextPos.x,nextPos.y
    target.x,target.y=1100,273
    Decision._processAI(unit,c)
    assert(not unit.intent,"Hold pursued a distant target")
    target.x,target.y=unit.x+30,unit.y
    unit.skills={attack={level=1}}
    Decision._processAI(unit,c)
    assert(unit.intent and unit.intent.type=="SKILL")
    unit.intent=nil
    Execution._initiateSkill(leader,{skillId="charge"},c)
    assert(squad.order=="charge" and not Squads.position(unit))
    assert(leader.globalCooldown==5 and leader.cooldowns.charge==60)
    leader.globalCooldown=0
    Squads.command(c,"player","hold")
    Execution._initiateSkill(leader,{skillId="charge"},c)
    assert(squad.order=="hold","cooldown bypass")
    Execution._initiateSkill(leader,{skillId="on_me"},c)
    assert(leader.globalCooldown==5 and leader.cooldowns.on_me==60 and leader.cooldowns.charge==60)
    Squads.command(c,"player","charge")
    target.x,target.y=1100,273
    Decision._processAI(unit,c)
    assert(unit.intent.type=="MOVE")
    unit.skills={attack={level=1},javelin_throw={level=1}}
    unit.charges.javelin_throw=1
    unit.cooldowns.javelin_throw=30
    target.x,target.y=unit.x+100,unit.y
    unit.intent=nil
    Decision._processAI(unit,c)
    assert(not unit.intent,"ranged cooldown caused melee advance")
    unit.cooldowns.javelin_throw=0
    Decision._processAI(unit,c)
    assert(unit.intent.skillId=="javelin_throw")
    unit.charges.javelin_throw=0
    unit.intent=nil
    Decision._processAI(unit,c)
    assert(unit.intent.type=="MOVE","exhausted ranged did not close to melee")
    -- Reform by proximity after Charge, rather than restoring personal slots.
    local first,second=squad.members[1],squad.members[2]
    Squads.command(c,"player","hold")
    Squads.position(first)
    local oldFirst,oldSecond=squad.assignments[first.id],squad.assignments[second.id]
    first.x=leader.x+squad.offsetX+oldSecond.x; first.y=squad.config.y+oldSecond.y
    second.x=leader.x+squad.offsetX+oldFirst.x; second.y=squad.config.y+oldFirst.y
    Squads.command(c,"player","charge")
    Squads.command(c,"player","hold")
    Squads.position(first)
    assert(squad.assignments[first.id].y==oldSecond.y)
    for _=1,5 do sim:tick() end
    assert(leader.globalCooldown==0 and leader.cooldowns.on_me==55)
    for _=1,55 do sim:tick() end
    assert(leader.cooldowns.on_me==0 and leader.cooldowns.charge==0)
    sim:destroy()
    assert(configs==party.squads and configs[2].formation=="line")
    sim=Simulation.new(party,enemy,false)
    for _,s in ipairs(sim.context.data.squads) do assert(s.order=="charge") end
    sim:destroy()
    print("Squad persistence, deployment, formation, AI and commands PASS")
end
return Scenario
