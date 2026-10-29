local Morale = require("src.game.battle.morale")
local Simulation = require("src.game.battle.battle_simulation")
local Combat = require("src.systems.battle.combat_system")
local Decision = require("src.systems.battle.decision_system")
local Execution = require("src.systems.battle.execution_system")
local Applier = require("src.systems.campaign.campaign_battle_result_applier")
local Runner = require("src.game.battle.headless_battle_runner")

local function near(a, b) assert(math.abs(a-b) < 0.00001, tostring(a).." ~= "..tostring(b)) end
local function actor(id)
    return {id=id, hp=100, size=3, stats={health=100, morale=10, battle_speed=10},
        skills={}, equipment={}}
end
local function fixture(control, rng)
    local a = {id="a", leaderId="a1", actors={actor("a1"),actor("a2"),actor("a3"),actor("a4")}}
    local b = {id="b", leaderId="b1", actors={actor("b1"),actor("b2")}}
    local sim = Simulation.new(a,b,control,{moraleRng=rng or function() return 0.999 end})
    for _, unit in ipairs(sim.context.data.unitList) do unit.x,unit.y=600,270 end
    local units={}
    for id,unit in pairs(sim.context.data.units) do units[id]=unit end
    return sim,units
end

local function damageAndEvents()
    local sim,u=fixture()
    local c=sim.context
    assert(u.a1.battleMorale==100 and not u.a1.fleeing and not u.a1.escaped)
    u.b2.stats.attack=1000;u.a1.protections.slashing=1000
    local protected=Combat.resolveAttack(u.b2,u.a1,require("src.data.skills").attack)
    Morale.process(c)
    assert(protected.hit and protected.damage==0 and u.a1.battleMorale==100)
    Combat._applyBattleDamage(u.a1,20); Morale.process(c); near(u.a1.battleMorale,96)
    Combat._applyBattleDamage(u.a1,20); Morale.process(c); near(u.a1.battleMorale,92)
    u.a1.stats.morale=20
    Combat._applyBattleDamage(u.a1,10); Morale.process(c); near(u.a1.battleMorale,91.5)
    u.a1.stats.morale=1
    Morale.change(c,u.a1,-10);near(u.a1.battleMorale,71.5)
    near(Morale.sizeImpact({size=8},{size=8}),1)
    near(Morale.sizeImpact({size=9},{size=1}),2)
    near(Morale.sizeImpact({size=1},{size=9}),0.5)
    u.a2.battleMorale,u.a3.battleMorale,u.a4.battleMorale,u.b1.battleMorale=50,50,50,98
    u.a3.squad={members={u.a3}}
    u.a4.x=781 -- outside the radius, measured from the casualty
    Combat._applyBattleDamage(u.a2,1000);Morale.process(c)
    near(u.a3.battleMorale,46);near(u.a4.battleMorale,50);near(u.b1.battleMorale,100)
    -- Same-sized giants still produce exactly the own-squad loss.
    u.a2.actor.size,u.a4.actor.size=8,8
    u.a4.x=780;u.a2.hp=100;u.a2.moraleDefeatReported=nil
    Combat._applyBattleDamage(u.a2,100);Morale.process(c);near(u.a4.battleMorale,38)
    sim:destroy()
end

local function probabilitiesAndCascades()
    near(Morale.probability(100),0);near(Morale.probability(50),0)
    near(Morale.probability(25),0.125);near(Morale.probability(0),1)
    local calls=0
    local sim,u=fixture(false,function() calls=calls+1;return 0.999 end)
    local c=sim.context
    u.a2.battleMorale=0;u.a3.battleMorale=25;u.a4.battleMorale=25
    u.a2.hp=0;u.a4.fleeing=true
    local average,count=Morale.average(u.a3.squad.members)
    near(average,25);assert(count==1)
    u.a2.hp=100;u.a4.fleeing=false;u.a2.battleMorale=100
    -- Each distinct casualty yields its own squad roll, even before the same drain.
    u.a1.x,u.a2.x=100,100
    Combat._applyBattleDamage(u.a2,100);Combat._applyBattleDamage(u.a4,100)
    Morale.process(c)
    assert(calls==3,"expected observer check plus two independent squad checks")
    local before=calls;Morale.process(c);assert(calls==before)
    u.a3.battleMorale=1
    Morale.change(c,u.a3,-1);Morale.process(c)
    assert(u.a3.fleeing and not Morale.flee(c,u.a3))
    sim:destroy()

    -- Two casualties in one AoE still provide two squad checks (plus one witness roll).
    calls=0
    sim,u=fixture(false,function() calls=calls+1;return 0.999 end)
    c=sim.context
    for _,unit in pairs(u) do unit.skills={attack=true} end
    u.a1.x,u.a4.x=100,100
    u.a3.battleMorale,u.a4.battleMorale=50,25
    u.a3.stats.morale=1e12
    u.b1.stats.attack,u.b1.stats.strength=1000,1000
    local random=math.random
    math.random=function() return 1 end
    local ok,err=pcall(Execution._resolveAoeAtPoint,u.b1,require("src.data.skills").fireball,600,270,c)
    math.random=random
    assert(ok,err)
    assert(u.a2.hp==0 and u.a3.hp==0 and calls==3,"AoE merged casualty rout opportunities")
    sim:destroy()

    -- A squad rout and widespread flight share one party opportunity per root event.
    calls=0
    sim,u=fixture(false,function() calls=calls+1;return 0 end)
    c=sim.context
    for _,id in ipairs({"a1","a2","a3","a4"}) do u[id].battleMorale=10 end
    u.a2.x=100 -- keep direct observer shocks separate from the cascade
    Combat._applyBattleDamage(u.a2,100);Morale.process(c)
    assert(u.a2.hp==0 and u.a3.fleeing and u.a4.fleeing and u.a1.fleeing)
    assert(u.a3.squad.routed and c.data.battleParties.player.routed)
    local transitions=0
    for _,unit in ipairs(c.data.unitList) do if unit.fleeing then transitions=transitions+1 end end
    assert(transitions==3 and #c.data.moraleQueue==0)
    before=calls;Morale.process(c);assert(calls==before)
    sim:destroy()
end

local function flightAndPlayer()
    local companion,player=actor("companion"),actor("player")
    player.player={}
    local marked=Simulation.new({id="a",leaderId="companion",actors={companion,player}},
        {id="b",actors={actor("enemy")}},true)
    assert(marked.context.data.playerUnit.id=="player")
    local npc=marked.context.data.units.companion
    assert(not npc.moraleExempt,"NPC leader inherited player immunity")
    Morale.change(marked.context,npc,-100)
    assert(npc.fleeing and not marked.context.data.units.player.fleeing)
    marked:destroy()
    local sim,u=fixture(true)
    local c=sim.context
    u.a1.x=u.a1.collisionRadius
    Morale.change(c,u.a1,-1000);assert(u.a1.battleMorale==100 and not u.a1.fleeing)
    Morale.updateEscapes(c);assert(not u.a1.escaped)
    Morale.flee(c,u.a2);Morale.process(c)
    assert(not u.a1.fleeing)
    u.a2.currentCast={skillId="attack",remaining=1}
    u.a2.globalCooldown=0
    Decision._processAI(u.a2,c) -- update() supplies flight override; stale skills must still be rejected
    Execution._executeSkillEffect(u.a2,"attack",u.b1.id,nil,c)
    assert(#c.data.projectiles==0)
    local oldHp=u.a2.hp;Combat._applyBattleDamage(u.a2,10);assert(u.a2.hp==oldHp-10)
    u.a2.x=u.a2.collisionRadius;Morale.updateEscapes(c)
    assert(u.a2.escaped and not c.data.units.a2)
    Combat._applyBattleDamage(u.a2,100);assert(u.a2.hp==90)
    Morale.flee(c,u.a3);Combat._applyBattleDamage(u.a3,100);Morale.process(c)
    c.removeDeadUnits();assert(not u.a3.escaped and u.a3.hp==0)
    c.data.battleParties.player.routed=true
    Morale.updateEscapes(c);assert(u.a1.escaped and not u.a1.fleeing)
    sim:destroy()

    sim,u=fixture(true)
    c=sim.context
    for _,id in ipairs({"a2","a3","a4"}) do Morale.flee(c,u[id]) end
    Morale.process(c)
    assert(c.data.battleParties.player.routed and not sim:getOutcome(),"active player must keep fighting")
    u.a1.x=u.a1.collisionRadius;Morale.updateEscapes(c)
    -- Physically trapped units survive a bounded escape resolution.
    c.data.tick=Morale.escapeTicks
    Morale.updateEscapes(c)
    local outcome,winner=sim:getOutcome()
    assert(outcome=="victory" and winner=="b")
    local result=sim:buildResult(outcome,winner)
    assert(result.actors.a2.escaped and not result.actors.a2.defeated and result.actors.a2.finalHp==100)
    local encounter={state="completed"}
    local context={parties={sim.partyA,sim.partyB},encounter=encounter}
    Applier.apply(result,context)
    assert(#sim.partyA.actors==4 and sim.partyA.actors[2].id=="a2")
    assert(not pcall(Applier.apply,result,context),"duplicate application accepted")
    result.actors.a2.defeated=true
    assert(not pcall(Applier.validate,result,{parties=context.parties,encounter={state="completed"}}))
    sim:destroy()
end

local function parityAndMovement()
    local a={id="a",actors={actor("a1")}}
    local b={id="b",actors={actor("b1")}}
    local interactive=Simulation.new(a,b,true)
    local headless=Runner.start(a,b,{moraleRng=function() return 0.999 end})
    for _,sim in ipairs({interactive,headless.simulation}) do
        local unit=sim.context.data.units.b1
        unit.x=1000;unit.y=100
        Morale.flee(sim.context,unit);Morale.process(sim.context)
        local x=unit.x
        sim:tick()
        assert(unit.x>x and unit.x-x <= unit.moveStep+0.001 and unit.globalCooldown>0)
    end
    local result=headless:advance(1000)
    for _=1,result.ticks-1 do interactive:tick() end
    local outcome,winner=interactive:getOutcome()
    local other=interactive:buildResult(outcome,winner)
    assert(result.outcome==other.outcome and result.winnerPartyId==other.winnerPartyId)
    assert(result.actors.b1.state=="escaped" and other.actors.b1.state=="escaped")
    headless:cleanup();interactive:destroy()
    local World=require("src.ecs.world")
    local Unit=require("src.ecs.assemblages.unit")
    local world=World.init()
    local permanent=Unit.create(world,"soldier","morale-default")
    assert(permanent.stats.morale==10 and permanent.battleMorale==nil)
end

local function triggersAndWitnesses()
    local calls=0
    local sim,u=fixture(false,function() calls=calls+1;return 0.999 end)
    local c=sim.context
    u.a1.battleMorale,u.a3.battleMorale,u.a4.battleMorale,u.b1.battleMorale=80,80,80,80
    u.a4.squad={members={u.a4}}
    u.a3.stats.morale=20
    Morale.flee(c,u.a2);Morale.process(c)
    near(u.a3.battleMorale,79);near(u.a4.battleMorale,80)
    near(u.a1.battleMorale,80);near(u.b1.battleMorale,85)
    u.b1.x=1000
    Morale.flee(c,u.a3);Morale.process(c);near(u.b1.battleMorale,85)
    sim:destroy()

    -- Other-squad flight cannot propagate individual flight, even at zero morale/infinite threat.
    calls=0
    sim,u=fixture(false,function() calls=calls+1;return 0 end)
    c=sim.context
    for _,unit in pairs(u) do unit.squad=nil;unit.battleMorale=0 end
    u.b1.skills={attack=true}
    Morale.flee(c,u.a2);Morale.process(c)
    for _,id in ipairs({"a1","a3","a4"}) do
        near(u[id].battleMorale,0)
        assert(not u[id].fleeing,"witnessed flight propagated individual fleeing")
    end
    assert(calls==0 and not c.data.battleParties.player.routed)
    near(u.b1.battleMorale,5) -- enemy-flight gains remain
    sim:destroy()

    for _,sample in ipairs({{0,78},{90,79},{180,80},{181,80}}) do
        sim,u=fixture()
        c=sim.context
        u.a3.battleMorale=80;u.a3.x=u.a2.x+sample[1]
        Morale.flee(c,u.a2);Morale.process(c)
        near(u.a3.battleMorale,sample[2])
        assert(not u.a3.fleeing,"confident flight witness fled")
        sim:destroy()
    end

    -- Leader defeat is a party opportunity even without squads or nearby witnesses.
    sim,u=fixture(false,function() return 0.07 end)
    c=sim.context
    for _,id in ipairs({"a2","a3","a4"}) do u[id].battleMorale=25;u[id].x=100 end
    Combat._applyBattleDamage(u.a1,100);Morale.process(c)
    assert(not c.data.battleParties.player.routed,"party chance must be half the individual curve")
    sim:destroy()
    calls=0
    sim,u=fixture(false,function() calls=calls+1;return 0 end)
    c=sim.context
    for _,id in ipairs({"a2","a3","a4"}) do u[id].battleMorale=25;u[id].x=100 end
    Combat._applyBattleDamage(u.a1,100);Morale.process(c)
    assert(c.data.battleParties.player.routed and calls==1)
    assert(u.a2.fleeing and u.a3.fleeing and u.a4.fleeing)
    sim:destroy()

    -- One death can produce widespread individual flight without any squad rout.
    sim,u=fixture(false,function() return 0 end)
    c=sim.context
    for _,id in ipairs({"a1","a2","a3","a4"}) do u[id].squad=nil;u[id].battleMorale=1 end
    Combat._applyBattleDamage(u.a2,100);Morale.process(c)
    assert(c.data.battleParties.player.routed and u.a1.fleeing)
    sim:destroy()

    -- Full-party withdrawal is not extermination, including mutual withdrawal.
    sim,u=fixture()
    c=sim.context
    for _,unit in ipairs(c.data.unitList) do Morale.flee(c,unit) end
    Morale.process(c);c.data.tick=Morale.escapeTicks;Morale.updateEscapes(c)
    local outcome,winner=sim:getOutcome()
    assert(outcome=="draw" and winner==nil)
    local result=sim:buildResult(outcome,winner)
    Applier.validate(result,{parties={sim.partyA,sim.partyB},encounter={state="completed"}})
    sim:destroy()

    -- The headless combat timeout must not interrupt an already pending rout resolution.
    local a={id="a",actors={actor("a1")}}
    local b={id="b",actors={actor("b1")}}
    local runner=Runner.start(a,b,{maxTicks=1})
    Morale.flee(runner.simulation.context,runner.simulation.context.data.units.b1)
    local result=runner:advance(1)
    assert(result.outcome=="victory" and result.actors.b1.escaped and result.ticks<=1+Morale.escapeTicks)
    runner:cleanup()
end

local function campaignRoutes()
    local World=require("src.ecs.world")
    local Party=require("src.ecs.assemblages.party")
    local Unit=require("src.ecs.assemblages.unit")
    local PartySystem=require("src.systems.parties.party_system")
    local Resolution=require("src.systems.campaign.campaign_battle_resolution")
    local function parties()
        local world=World.init()
        local a=Party.create(world,"route-a",nil,"Route A")
        local b=Party.create(world,"route-b",nil,"Route B")
        PartySystem.addActor(a,Unit.create(world,"soldier","route-a1"))
        PartySystem.addActor(b,Unit.create(world,"soldier","route-b1"))
        local map={id="route-map",getParties=function() return {a,b} end,
            removeParty=function() error("routed survivors must remain on map") end}
        return a,b,map
    end
    local a,b,map=parties()
    local sim=Simulation.new(a,b)
    local c=sim.context
    local enemy=c.data.units["route-b1"]
    enemy.hp=37
    Morale.flee(c,enemy);Morale.process(c)
    c.data.tick=Morale.escapeTicks;Morale.updateEscapes(c)
    local outcome,winner=sim:getOutcome()
    local result=sim:buildResult(outcome,winner)
    local encounter={lootPolicy={plunderAllowed=false},id="route-npc",partyAId=a.id,partyBId=b.id,state="completed"}
    local Events=require("src.systems.campaign.world_events")
    local EventBus=require("src.core.event_bus")
    EventBus.init()
    local killed=0
    EventBus.subscribe("party_killed",function() killed=killed+1 end)
    local resolution=Resolution.resolve(result,{map=map,parties={a,b},encounter=encounter,rewardPolicy="npc"})
    local event=resolution.event
    assert(event.type=="battle_ended" and event.routedPartyIds[1]==b.id)
    assert(event.winnerPartyId==a.id and event.loserPartyId==b.id)
    assert(event.participants[2].routed and not event.participants[2].destroyed)
    assert(event.participants[2].escapedActorIds[1]=="route-b1" and event.participants[2].casualties==0)
    assert(killed==0 and Events.count(a:getWorld())==1,"rout logged elimination")
    assert(Resolution.resolve(result,{encounter=encounter})==resolution)
    assert(Events.count(a:getWorld())==1,"duplicate battle event")
    assert(#b.actors==1 and b.actors[1].hp==37)
    assert(not encounter.lootResult.partyStates[b.id].eliminated)
    assert(map.partyEncounterCooldowns[a.id]>0 and map.partyEncounterCooldowns[b.id]>0)
    sim:destroy()

    local GameContext=require("src.game.game_context")
    local BattleState=require("src.game.states.battle_state")
    local StateManager=require("src.core.state_manager")
    a,b,map=parties()
    GameContext.data.playerParty=a;GameContext.data.currentMap=map
    local swap=StateManager.swap
    local transition
    StateManager.swap=function(name,params) transition={name=name,params=params} end
    local ok,err=xpcall(function()
        BattleState.enter({enemyParty=b})
        local context=BattleState.simulation.context
        context.data.battleParties.player.routed=true
        local player=context.data.playerUnit
        player.hp=42;player.x=player.collisionRadius
        Morale.updateEscapes(context)
        BattleState.checkBattleEnd()
        assert(transition.name=="battle_end" and not transition.params.victory)
        assert(a.actors[1].hp==42 and #b.actors==1)
        local event=Events.getByType(a:getWorld(),"battle_ended")[1]
        assert(event.participants[1].routed and not event.participants[1].destroyed)
        assert(event.participants[1].escapedActorIds[1]=="route-a1")
        assert(map.partyEncounterCooldowns[a.id]>0)
        BattleState.exit()
        assert(not a.activeEncounterId and not b.activeEncounterId)
    end,debug.traceback)
    StateManager.swap=swap
    if not ok then error(err) end
end

local function decisionsAndReset()
    local sim,u=fixture()
    local c=sim.context
    for _,morale in ipairs({100,49,0}) do
        u.a1.battleMorale=morale
        u.a1.skills={attack={learned=true}}
        u.a1.intent=nil;u.a1.x=500;u.b1.x=900;u.b2.x=950
        Decision._processAI(u.a1,c)
        assert(u.a1.intent and u.a1.intent.type=="MOVE","morale changed advancing")
        u.a1.intent=nil;u.b1.x=535
        Decision._processAI(u.a1,c)
        assert(u.a1.intent and u.a1.intent.type=="SKILL","morale changed attacking")
        u.a1.skills.fireball={learned=true}
        Execution._initiateSkill(u.a1,{skillId="fireball",targetUnitId=u.b1.id},c)
        assert(u.a1.currentCast and u.a1.currentCast.skillId=="fireball","morale prevented casting")
        u.a1.currentCast=nil;u.a1.globalCooldown=0
        require("src.game.battle.squads").command(c,"player","hold")
        u.a4.battleMorale=morale;u.a4.x,u.a4.y=200,100
        Decision._processAI(u.a4,c)
        assert(u.a4.intent and u.a4.intent.type=="MOVE","morale prevented regrouping")
        assert(not u.a1.fleeing and not u.a4.fleeing,"morale alone triggered flight")
    end
    u.a2.x,u.a2.y=300,100
    u.a2.currentCast={skillId="attack",remaining=100}
    Morale.flee(c,u.a2);Morale.process(c)
    assert(not u.a2.currentCast and not u.a2.intent)
    require("src.game.battle.squads").command(c,"player","hold")
    sim:tick()
    assert(u.a2.x<300,"Hold overrode flight")
    u.b1.x,u.b1.y=u.a2.x+40,u.a2.y
    assert(c.findNearestHostile(u.b1)==u.a2,"fleeing actors vanished as targets")
    local second=Simulation.new(sim.partyA,sim.partyB)
    assert(second.context.data.units.a2.battleMorale==100 and not second.context.data.units.a2.fleeing)
    assert(sim.partyA.actors[2].battleMorale==nil)
    second:destroy();sim:destroy()
end

local function debugOverlay()
    local Render = require("src.systems.battle.render_system")
    local Mode = require("src.debug.mode")
    local sim, u = fixture(true)
    u.a2.battleMorale = 25
    u.a3.fleeing = true
    u.a4.escaped = true
    u.b1.hp = 0
    u.b2.fleeing = true
    u.a1.skills = {attack=true}
    sim.context.data.battleParties.enemy.routed = true
    local enabled, printText = Mode.enabled, love.graphics.print
    local lines = {}
    love.graphics.print = function(value, ...)
        lines[#lines+1] = value
        return printText(value, ...)
    end
    local ok, err = pcall(function()
        Mode.enabled = false
        Render.drawMoraleDebug(sim.context)
        assert(#lines == 0, "Morale debug information appeared with F1 disabled")
        Mode.enabled = true
        Render.drawMoraleDebug(sim.context)
        local text = table.concat(lines, "\n")
        assert(text:find("Player | Morale 25.0 | Power", 1, true))
        assert(text:find("Fight 2  Flee 1  Esc 1", 1, true))
        assert(text:find("Enemy | Morale N/A | Power 0.0 | ROUTED", 1, true))
        assert(text:find("Fight 0  Flee 1  Esc 0", 1, true))
        assert(text:find("Threat 1.00x", 1, true))
        assert(text:find("Threat infinite", 1, true))
        u.b2.fleeing=false;u.b2.skills={attack=true};u.b2.hp=200
        lines={}
        Render.drawMoraleDebug(sim.context)
        assert(table.concat(lines,"\n"):find("Threat 2.00x",1,true),
            "Debug threat did not update when fighting power changed")
        assert(u.a2.battleMorale == 25 and not u.a2.fleeing, "Debug drawing changed morale")
    end)
    love.graphics.print, Mode.enabled = printText, enabled
    sim:destroy()
    assert(ok, err)
end

return {run=function()
    damageAndEvents();probabilitiesAndCascades();flightAndPlayer();parityAndMovement();triggersAndWitnesses();campaignRoutes();decisionsAndReset();debugOverlay()
    print("M3 morale, cascades, player escape, survivors and simulation parity PASS")
end}
