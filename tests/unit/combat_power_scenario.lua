local Power = require("src.game.combat_power")
local Simulation = require("src.game.battle.battle_simulation")
local Morale = require("src.game.battle.morale")
local Combat = require("src.systems.battle.combat_system")

local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a).." ~= "..tostring(b)) end
local function actor(id, hp)
    return {id=id, hp=hp or 100, stats={health=100,attack=10,defense=10,strength=10,morale=10},
        skills={attack=true}, equipment={}, size=3}
end
local function simulation()
    local a,b=actor("a"),actor("b")
    local sim=Simulation.new({id="pa",actors={a}},{id="pb",actors={b}},false,
        {moraleRng=function() return 0.999 end})
    return sim,sim.context.data.units.a,sim.context.data.units.b
end

local function options()
    local a=actor("a")
    near(Power.unit(a),5*(10+10+5+3)/30)
    a.injuryProfile="humanoid"
    a.injuries={{id="wounded_arm",bodyPart="left_arm"}}
    near(Power.unit(a),5*(9+10+5+3)/30)
    a.injuries={};a.summoned=true;a.undead=true
    near(Power.unit(a),5*(10+10+5+3)/30)
    a.skills={heal=true,charge=true};near(Power.unit(a),0)
    a.skills={attack=true,fireball=true,javelin_throw=true,javelin_throw_single=true}
    a.equipment={mainHand="iron_sword",head="helmet"}
    a.innateProtections={slashing=6,piercing=3,blunt=0,fire=1000}
    near(Power.unit(a),5*(10+13+5+15+0.25*15+1.5)/30)
    local sim=Simulation.new({id="pa",actors={a}},{id="pb",actors={actor("b")}})
    local unit=sim.context.data.units.a
    near(Power.unit(a),Power.unit(unit))
    a.size=9;near(Power.unit(a),Power.unit(unit)) -- no separate Size factor
    unit.skills={attack=true,javelin_throw=true,javelin_throw_single=true,heal=true}
    near(Power.unit(unit),5*(10+13+5+15+0.25*8+1.5)/30) -- identical throws count once
    unit.charges.javelin_throw=0;unit.charges.javelin_throw_single=0
    near(Power.unit(unit),5*(10+13+5+8+1.5)/30)
    unit.skills={javelin_throw=true,heal=true};near(Power.unit(unit),0)
    near(Power.party({members={unit}}),0)
    unit.skills={fireball=true,heal=true};unit.cooldowns.fireball=1000
    near(Power.unit(unit),5*(10+13+5+15+1.5)/30) -- cooldown ignored
    unit.hp=50;near(Power.unit(unit),2.5*(10+13+5+15+1.5)/30)
    near(Power.party({actors={unit}}),Power.unit(unit))
    near(Power.party({}),0);near(Power.party({actors={}}),0)
    unit.hp=0;near(Power.unit(unit),0)
    unit.hp=50;unit.fleeing=true;near(Power.unit(unit),0)
    unit.fleeing=false;unit.escaped=true;near(Power.unit(unit),0)
    sim:destroy()
end

local function threats()
    local sim,a,b=simulation()
    local c=sim.context
    local base=Power.unit(a)
    near(Morale.threat(Morale.powers(c),"player"),1)
    b.hp=200
    Combat._applyBattleDamage(a,20);Morale.process(c)
    near(a.battleMorale,92) -- 4 * 2, using HP before the damage
    Combat._applyBattleDamage(a,20);Morale.process(c)
    near(a.battleMorale,82) -- 4 * 2.5 after HP changed
    near(Morale.powers(c).player,base*0.6)
    b.charges.javelin_throw=1;b.skills.javelin_throw=true
    local armed=Morale.powers(c).enemy
    b.charges.javelin_throw=0
    assert(Morale.powers(c).enemy<armed,"spent ammunition retained power")
    a.battleMorale=100;b.hp=10000
    Combat._applyBattleDamage(a,10);Morale.process(c)
    assert(a.battleMorale==0 and a.fleeing,"extreme threat was capped")
    near(Morale.powers(c).player,0)
    near(Morale.threat({player=0,enemy=0},"player"),1)
    assert(Morale.threat({player=0,enemy=1},"player")==math.huge)
    sim:destroy()

    sim,a,b=simulation();a.skills={heal=true}
    Combat._applyBattleDamage(a,1);Morale.process(sim.context)
    assert(a.battleMorale==0 and a.fleeing,"zero friendly power did not resolve safely")
    sim:destroy()

    -- Casualties queued before a drain retain their own pre-transition powers.
    local a1,a2,b1=actor("a1"),actor("a2"),actor("b1")
    sim=Simulation.new({id="pa",actors={a1,a2}},{id="pb",actors={b1}},false,
        {moraleRng=function() return 0.999 end})
    c=sim.context;a=c.data.units.a1;b=c.data.units.b1
    local other=c.data.units.a2
    a.x,a.y,other.x,other.y,b.x,b.y=100,100,100,100,100,100
    b.hp=400
    Combat._applyBattleDamage(other,100)
    local queue=c.data.moraleQueue
    near(Morale.threat(queue[2].powers,"player"),2)
    near(Morale.threat(Morale.powers(c),"player"),4)
    Morale.process(c);near(a.battleMorale,92) -- other allied squad death: 4 * 2
    a.battleMorale=100
    Morale.flee(c,b)
    near(Morale.threat(c.data.moraleQueue[1].powers,"player"),4)
    near(Morale.threat(Morale.powers(c),"player"),1)
    Morale.process(c);near(a.battleMorale,100) -- positive gains ignore threat
    sim:destroy()

    -- Other-squad flight causes no morale loss, but subsequent damage uses remaining combat power.
    sim=Simulation.new({id="pa",actors={actor("a1"),actor("a2")}},{id="pb",actors={actor("b1")}},false,
        {moraleRng=function() return 0.999 end})
    c=sim.context;a=c.data.units.a1;other=c.data.units.a2;b=c.data.units.b1
    a.x,a.y,other.x,other.y=100,100,100,100;b.hp=400
    Morale.flee(c,other);Morale.process(c);near(a.battleMorale,100) -- other-squad flight has no morale penalty
    Combat._applyBattleDamage(a,10);Morale.process(c);near(a.battleMorale,96) -- 1 * 4 after flight reduced power
    sim:destroy()

    -- A vast initial disparity does not itself generate any morale or rout event.
    sim,a,b=simulation();b.hp=100000
    Morale.process(sim.context)
    assert(a.battleMorale==100 and not a.fleeing and not sim.context.data.battleParties.player.routed)
    sim:destroy()
end

return {run=function() options();threats();print("Shared combat power and threat snapshots PASS") end}
