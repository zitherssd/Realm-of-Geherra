local Ecs = require("src.ecs.world")
local Conditions = require("src.systems.actors.conditions")
local Stats = require("src.systems.actors.effective_stats")
local Combat = require("src.systems.battle.combat_system")
local Execution = require("src.systems.battle.execution_system")
local Decision = require("src.systems.battle.decision_system")
local Context = require("src.game.battle.battle_context")
local Simulation = require("src.game.battle.battle_simulation")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Parties = require("src.systems.parties.party_system")
local Resolution = require("src.systems.campaign.campaign_battle_resolution")
local Game = require("src.game.game_context")
local Bus = require("src.core.event_bus")
local Events = require("src.systems.campaign.world_events")
local Skills = require("src.data.skills")
local Dice = require("src.utils.math")
local Test = {}
local function unit(id, team)
    return {id=id,team=team or "player",hp=100,maxHp=100,x=200,y=200,visualX=200,visualY=200,
        stats={attack=10,defense=10,strength=0,battle_speed=120,morale=10},equipment={},skills={attack=true,heal=true},
        cooldowns={},charges={},globalCooldown=0,visualEffects={},statusEffects={},injuries={},moraleExempt=true,
        collisionRadius=18,moveStep=24, destroy=function() end}
end
local function context(...)
    local c=Context.new({width=1260,height=546})
    for _, u in ipairs({...}) do c.addUnit(u) end
    return c
end
local function ticks(u,c,n) for _=1,n do Execution.tickStatuses(u,c) end end
local function harassed()
    local a,b=unit("a"),unit("b","enemy")
    local c=context(a,b)
    a.stats.attack=100
    Combat.resolveAttack(a,b,Skills.attack)
    assert(b.statusEffects.harassed.stacks==1 and Stats.get(b,"defense")==9)
    a.stats.attack=0;b.stats.defense=100
    Combat.resolveAttack(a,b,Skills.attack)
    assert(b.statusEffects.harassed.stacks==2,"Miss did not harass")
    ticks(b,c,9)
    Conditions.apply(b,"harassed")
    ticks(b,c,1)
    assert(b.statusEffects.harassed.stacks==2,"Reapplication reset decay")
    for _=1,100 do Conditions.apply(b,"harassed") end
    assert(b.statusEffects.harassed.stacks==102 and Stats.get(b,"defense")==1)
    ticks(b,c,10)
    assert(b.statusEffects.harassed.stacks==82)
    ticks(b,c,300)
    assert(not b.statusEffects.harassed)
    Combat.resolveProjectileAttack(a,b,{id="test",baseDamage=0,projectile={defenseMode="none"}})
    Combat.resolveAreaEffect(a,b,{baseDamage=0})
    assert(not b.statusEffects.harassed)
end
local function periodic()
    local u=unit("u"); local c=context(u)
    Conditions.apply(u,"burn");ticks(u,c,19)
    Conditions.apply(u,"burn");ticks(u,c,1)
    assert(u.hp==99 and u.statusEffects.burn.stacks==1 and u.statusEffects.burn.remaining==119)
    Conditions.apply(u,"burn");ticks(u,c,20);assert(u.hp==98)
    u.statusEffects={};u.hp=100
    Conditions.apply(u,"poison",{maxStacks=3});ticks(u,c,19)
    Conditions.apply(u,"poison",{maxStacks=3});ticks(u,c,1)
    assert(u.hp==96 and u.statusEffects.poison.stacks==2)
    Conditions.apply(u,"poison",{maxStacks=3});Conditions.apply(u,"poison",{maxStacks=3})
    assert(u.statusEffects.poison.stacks==3)
    u.innateProtections={poison=5,fire=1};ticks(u,c,20);assert(u.hp==95)
    u.statusEffects={};Conditions.apply(u,"burn");ticks(u,c,20);assert(u.hp==95)
    u.statusEffects={poison={remaining=0,damagePerTick=100,tickEvery=1}}
    ticks(u,c,1);assert(u.hp==95 and not u.statusEffects.poison)
    assert(#u.injuries==0)
end
local function restrictionsAndHealing()
    local a,b=unit("a"),unit("b","enemy");b.x=240
    local c=context(a,b)
    for _, id in ipairs({"stun","paralyze"}) do
        a.globalCooldown=0
        Execution._initiateSkill(a,{skillId="heal",targetUnitId=a.id},c)
        assert(a.currentCast)
        local charges=a.charges.heal
        Conditions.apply(a,id)
        assert(not a.currentCast and a.charges.heal==charges)
        Execution._executeSkillEffect(a,"attack",b.id,nil,c)
        Execution._executeMove(a,{target={x=100,y=200}},c)
        assert(a.x==200 and b.hp==100)
        a.fleeing=true;a.escapeEdge=0;a.globalCooldown=0
        local d=Decision();d.pool={a};d:update(c)
        assert(not a.intent,"Disabled fleeing unit moved")
        Conditions.remove(a,id);a.fleeing=false
    end
    Conditions.apply(a,"immobilize")
    a.globalCooldown=0
    Execution._executeMove(a,{target={x=100,y=200}},c);assert(a.x==200)
    a.fleeing=true;a.escapeEdge=0
    local d=Decision();d.pool={a};d:update(c);assert(not a.intent)
    a.fleeing=false;a.hp=40
    Execution._initiateSkill(a,{skillId="heal",targetUnitId=a.id},c)
    assert(a.currentCast,"Immobilize prevented casting")
    Execution._completeCast(a,c);assert(a.hp==90)
    a.globalCooldown=0;a.cooldowns={};a.hp=90
    Execution._executeSkillEffect(a,"heal",a.id,nil,c);assert(a.hp==100)
    local ally=unit("ally");ally.x=250;ally.hp=20;c.addUnit(ally)
    Execution._executeSkillEffect(a,"heal",ally.id,nil,c);assert(ally.hp==70 and b.hp==100)
    ally.hp=20
    Execution._executeSkillEffect(a,"heal",b.id,nil,c);assert(ally.hp==70 and b.hp==100,"Heal targeted enemy")
    a.stats.attack=100; a.cooldowns={};a.globalCooldown=0
    Execution._executeSkillEffect(a,"attack",b.id,nil,c)
    assert(b.statusEffects.harassed,"Immobilize prevented attack")
end
local function settlement()
    local world=Ecs.init();Game.init();Bus.init()
    local function party(id)
        local p=Party.create(world,id,nil,id)
        local u=Unit.create(world,"soldier",id.."-actor")
        u.equipment={};u.stats.health=100;u.hp=100;u.maxHp=100
        Parties.addActor(p,u);return p,u
    end
    local pa,actor=party("a");local pb=party("b")
    local sim=Simulation.new(pa,pb)
    local a,b=sim.context.data.unitList[1],sim.context.data.unitList[2]
    a.moraleExempt=true;b.hp=0;sim.context.removeDeadUnits()
    a.hp=1
    Conditions.apply(a,"burn",{duration=20})
    Conditions.apply(a,"kept",{lifetime="permanent",effects={attack=1}})
    a.currentCast={skillId="heal",remaining=1,targetUnitId=a.id}
    a.intent={type="SKILL",skillId="heal",targetUnitId=a.id}
    local projectile={sentinel=true};sim.context.data.projectiles={projectile}
    local x,tick=a.x,sim.context.data.tick
    local outcome,winner=sim:getOutcome();assert(outcome=="victory" and winner==pa.id)
    local result=sim:buildResult(outcome,winner)
    assert(result.winnerPartyId==pa.id and result.outcome=="victory" and result.actors[a.id].defeated)
    assert(result.settlementTicks==20 and result.ticks==tick and a.x==x)
    assert(not a.currentCast and sim.context.data.projectiles[1]==projectile)
    assert(result.actors[a.id].statusEffects.kept and not result.actors[a.id].statusEffects.burn)
    local locked,lockedWinner=sim:getOutcome();assert(locked==outcome and lockedWinner==winner)
    local map=require("src.world.map").new("settlement-map")
    map:addParty(pa);map:addParty(pb)
    local encounter={x=0,y=0,id="settlement",state="completed",result=result,partyAId=pa.id,partyBId=pb.id,lootPolicy={plunderAllowed=false,stolenProportion=0,destroyedProportion=0}}
    local resolved=Resolution.resolve(result,{map=map,encounter=encounter,parties={pa,pb},world=world,rewardPolicy="npc",lootPolicy={plunderAllowed=false,stolenProportion=0,destroyedProportion=0}})
    assert(resolved and #pa.actors==0 and #pb.actors==0)
    local event=Events.getByType(world,"battle_ended")[1]
    assert(event.winnerPartyId==pa.id and event.participants[1].casualties==1 and event.participants[2].casualties==1)
    sim:destroy()
    -- Regeneration resolves, while permanent pulses neither prolong nor run in settlement.
    pa=party("regen-a");pb=party("regen-b");sim=Simulation.new(pa,pb)
    a,b=sim.context.data.unitList[1],sim.context.data.unitList[2]
    a.hp=50;b.hp=0;sim.context.removeDeadUnits()
    Conditions.apply(a,"regen",{duration=4,tickEvery=2,healingPerTick=30,lifetime="persistent"})
    Conditions.apply(a,"forever",{lifetime="permanent",damagePerTick=99,tickEvery=1})
    result=sim:buildResult("victory",pa.id)
    assert(a.hp==100 and result.settlementTicks==4 and result.actors[a.id].statusEffects.forever)
    sim:destroy()
    -- Escaped survivors still resolve finite statuses and cannot be both dead and escaped.
    pa=party("escape-a");pb=party("escape-b");sim=Simulation.new(pa,pb)
    a,b=sim.context.data.unitList[1],sim.context.data.unitList[2]
    a.hp=1;a.escaped=true
    sim.context.data.escaped={a}
    sim.context.data.units[a.id]=nil
    sim.context.data.unitList={b}
    Conditions.apply(a,"poison",{duration=1,tickEvery=1})
    result=sim:buildResult("victory",pb.id)
    assert(result.actors[a.id].defeated and not result.actors[a.id].escaped)
    assert(#sim.context.data.escaped==0 and #sim.context.data.casualties==1)
    sim:destroy()
    -- The safety bound is observable and persistent state survives truncation.
    pa=party("bound-a");pb=party("bound-b");sim=Simulation.new(pa,pb)
    a,b=sim.context.data.unitList[1],sim.context.data.unitList[2]
    b.hp=0;sim.context.removeDeadUnits()
    Conditions.apply(a,"long-regen",{duration=100,tickEvery=2,healingPerTick=1,lifetime="persistent"})
    sim.SETTLEMENT_LIMIT=3
    result=sim:buildResult("victory",pa.id)
    assert(result.settlementTruncated and result.settlementTicks==3 and a.statusEffects["long-regen"].remaining==97)
    sim:destroy()
end
function Test.run()
    local old=Dice.rollExploding;Dice.rollExploding=function() return 1 end
    local ok,err=xpcall(function() harassed();periodic();restrictionsAndHealing();settlement() end,debug.traceback)
    Dice.rollExploding=old;assert(ok,err)
    print("M5.1-B periodic effects, restrictions, healing and settlement PASS")
end
return Test






