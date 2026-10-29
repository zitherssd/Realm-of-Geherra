local Ecs = require("src.ecs.world")
local P = require("src.game.battle.projectiles")
local Combat = require("src.systems.battle.combat_system")
local Execution = require("src.systems.battle.execution_system")
local Decision = require("src.systems.battle.decision_system")
local Context = require("src.game.battle.battle_context")
local Skills = require("src.data.skills")
local Dice = require("src.utils.math")
local Scenario = {}
local function unit(id,x,y,team)
    return {id=id,x=x,y=y,hp=100,maxHp=100,battleMorale=100,moraleExempt=true,stats={precision=10,strength=0},team=team or "player",
        collisionRadius=18,height=72,equipment={},itemDurability={},statusEffects={},injuries={},
        visualEffects={},visualX=x,visualY=y,skills={},cooldowns={},charges={},globalCooldown=0}
end
local function shot(a,b,config,rng)
    return P.launch(a,{id="test_projectile",baseDamage=15,projectile=config or {speed=40,arc=0}},b.x,b.y,b,rng or function() return 0.5 end)
end
local function context(...)
    local c=Context.new()
    for _,u in ipairs({...}) do c.addUnit(u) end
    return c
end
local function finish(p,c)
    for _=1,1000 do
        local reason,target=P.advance(p,c)
        if reason then return reason,target end
    end
    error("Projectile never terminated")
end
local function geometry()
    local a,b=unit("a",100,200),unit("b",400,200,"enemy")
    local index=0
    local x,y=P.aim(a,b.x,b.y,function() index=index+1;return index==1 and 1 or 0.5 end)
    assert(index==2 and x==400 and y==230,"Lateral error must be independently sampled")
    x,y=P.aim(a,b.x,b.y,function() index=index+1;return index==3 and 0.5 or 1 end)
    assert(x==430 and y==200,"Depth error must be independent")
    local x2=P.aim(a,700,200,function() return 1 end)
    assert(x2-700==60,"Distance must scale error")
    a.stats.precision=20
    x2=P.aim(a,400,200,function() return 1 end)
    assert(x2-400==15,"Precision must reduce error")
    a.stats.precision=10;a.battleMorale=0
    assert(P.aim(a,400,200,function() return 1 end)==430,"Morale changed aim")
    a.stats.precision=0
    assert(P.aim(a,400,200,function() return 1 end)==700)
    a.stats.precision=10
    local c=context(a,b)
    local calls=0
    local p=shot(a,b,{speed=600},function() calls=calls+1;assert(calls<=2,"Aim resampled during flight");return 0.5 end)
    local reason,hit=finish(p,c)
    assert(reason=="unit" and hit==b and calls==2,"Fast swept shot tunneled or resampled")
    b.y=300;p=shot(a,{x=400,y=200,height=72})
    reason=finish(p,c);assert(reason=="range" or reason=="bounds","Moved target still got hit")
    b.y=200;p=shot(a,b);b.y=300;P.advance(p,c);b.y=200
    reason,hit=finish(p,c);assert(hit==b,"Moving target entering path was missed")
    b.height=20;p=shot(a,b,{speed=600});p.endZ=p.startZ
    assert(finish(p,c)~="unit","Short cylinder hit above height")
    b.height=72;b.y=222;b.collisionRadius=1
    p=shot(a,{x=400,y=200,height=72},{speed=600})
    assert(finish(p,c)~="unit","Narrow cylinder hit outside radius")
    b.collisionRadius=30;p=shot(a,{x=400,y=200,height=72},{speed=600})
    assert(select(2,finish(p,c))==b,"Large radius ignored")
    b.y=200;b.collisionRadius=18
    local front=unit("front",180,200)
    c=context(a,b,front)
    p=shot(a,b,{speed=600,arc=160})
    reason,hit=finish(p,c);assert(hit==b,"High arc failed to clear front rank")
    p=shot(a,b,{speed=600});reason,hit=finish(p,c)
    assert(hit==front,"Earliest collision must win independent of roster order")
    -- A shot missing the original target can hit a different unit behind it.
    local behind=unit("behind",500,200,"enemy")
    b.y=280;c=context(a,b,behind)
    p=shot(a,{x=400,y=200,height=72},{speed=600})
    assert(select(2,finish(p,c))==behind,"Missed shot did not continue into another unit")
    b.y=200
    -- A very short shot hits ground before reaching the target.
    c=context(a,b)
    p=shot(a,{x=180,y=200,height=72},{speed=600,arc=30})
    assert(finish(p,c)=="ground" and p.x<b.x,"Short shot reached the original target")
    -- Launch grace does not make the shooter immune later in flight.
    c=context(a)
    p=shot(a,b)
    P.advance(p,c);a.x=200
    assert(select(2,finish(p,c))==a,"Shooter remained immune after launch")
    a.x=100
    c=context(a)
    p=shot(a,b,{speed=40,arc=30});reason=finish(p,c)
    assert(reason=="ground" and p.x>400,"Arcing shot stopped at aim instead of ground")
    local short=shot(a,b,{speed=40,arc=30},function() return 0 end)
    local long=shot(a,b,{speed=40,arc=30},function() return 1 end)
    finish(short,c);finish(long,c)
    assert(short.x<long.x,"Depth error did not affect ground position")
    p=shot(a,b,{speed=600,maxRange=100});assert(finish(p,c)=="range")
    p=shot(a,b,{speed=600,maxRange=5000});assert(finish(p,c)=="bounds")
    p=shot(a,b,{speed=1,maxLifetime=1});assert(finish(p,c)=="lifetime")
    p=shot(a,b);for _=1,9 do assert(not P.advance(p,c)) end
    assert(p.x>b.x,"Straight shot stopped at aim point")
end
local function defense()
    local original=Dice.rollExploding
    local a,b=unit("a",100,200),unit("b",400,200,"enemy")
    local function rolls(values)
        local i=0;Dice.rollExploding=function(sides) assert(sides==8);i=i+1;return assert(values[i]) end
        return function() return i end
    end
    a.stats.precision=8
    a.stats.attack=-1000;b.stats.defense=1000;b.size=100
    local count=rolls({1,1,1,2})
    local hit,margin,shield=Combat.rollProjectileDefense(a,b)
    assert(not hit and margin==0 and shield==0 and count()==4,"Unshielded tie must defend")
    rolls({1,2,1,2});assert(Combat.rollProjectileDefense(a,b),"Strict winning score failed")
    rolls({1,1,2,2});assert(not Combat.rollProjectileDefense(a,b))
    b.equipment.offHand="wooden_shield";b.itemDurability.wooden_shield=1
    rolls({1,1,1,1})
    local result=Combat.resolveProjectileAttack(a,b,Skills.arrow)
    assert(not result.hit and result.action=="block" and not b.equipment.offHand,"Shield wear/break failed")
    rolls({1,1,1,2});result=Combat.resolveProjectileAttack(a,b,Skills.arrow)
    assert(result.action=="evade" and b.hp==100 and next(b.itemDurability)==nil,"Unshielded defense damaged HP or shield")
    b.equipment.offHand="wooden_shield";b.itemDurability.wooden_shield=0
    assert(Combat._getShieldDefense(b)==0,"Broken shield contributed defense")
    local random=math.random
    math.random=function() error("Unexpected percentage hit roll") end
    rolls({1,1,1,1});assert(Combat.rollProjectileDefense(a,b))
    math.random=random
    Dice.rollExploding=original
end
local function impacts()
    local original=Dice.rollExploding
    Dice.rollExploding=function() return 1 end
    local a,b,ally=unit("a",100,200),unit("b",400,200,"enemy"),unit("ally",200,200)
    a.stats.precision=100
    local c=context(a,b,ally)
    c.data.projectiles={shot(a,b,{speed=600})}
    Execution._updateProjectiles(c)
    assert(ally.hp==85 and b.hp==100 and #c.data.projectiles==0,"Friendly fire failed")
    Execution._updateProjectiles(c);assert(ally.hp==85,"Duplicate projectile damage")
    local p=shot(a,b,{speed=600});a.stats.precision=0;c.data.projectiles={p}
    Execution._updateProjectiles(c);assert(ally.hp==85 and #c.data.projectiles==0,"Defended projectile continued")
    a.stats.precision=100;ally.y=300
    c.data.projectiles={shot(a,b,{speed=600})}
    Execution._updateProjectiles(c);assert(b.hp==85,"Enemy impact failed")
    -- Fireball keeps splash/status behavior at physical contact, with no second direct hit.
    b.hp=100;ally.x=400;ally.y=230
    c.data.projectiles={P.launch(a,Skills.fireball,b.x,b.y,b,function() return 0.5 end)}
    for _=1,20 do Execution._updateProjectiles(c) end
    assert(b.hp==85 and ally.hp==70 and b.statusEffects.burn and ally.statusEffects.burn,"Fireball splash/direct status changed")
    Dice.rollExploding=original
end
local function ai()
    local a,b,ally=unit("a",100,200),unit("b",400,200,"enemy"),unit("ally",150,200)
    a.skills={frostbolt={}};local c=context(a,b,ally)
    assert(P.friendlyRisk(a,b,Skills.frostbolt,c)==nil,"Obvious obstruction accepted")
    Decision._processAI(a,c);assert(not a.intent or a.intent.type~="SKILL","AI fired through near ally")
    ally.x=370
    Decision._processAI(a,c);assert(a.intent and a.intent.targetUnitId==b.id,"AI refused ongoing melee")
    local safe=unit("safe",380,330,"enemy");c.addUnit(safe);a.intent=nil
    Decision._processAI(a,c);assert(a.intent.targetUnitId==safe.id,"AI failed to prefer safer enemy")
    ally.x,ally.y=150,200
    local high={projectile={arc=160}}
    assert(P.friendlyRisk(a,b,high,c)~=nil,"Arc treated like straight obstruction")
    -- A distant target with intervening friendlies loses to a clear nearer target.
    ally.x,ally.y=280,200
    safe.x,safe.y=340,300;a.intent=nil
    Decision._processAI(a,c)
    assert(a.intent.targetUnitId==safe.id,"AI blindly preferred distant obstructed target")
    ally.x,ally.y=150,200
    -- Player execution bypasses the AI veto.
    a.skills={frostbolt={}};a.globalCooldown=0
    Execution._executeSkillEffect(a,"frostbolt",b.id,nil,c)
    assert(#c.data.projectiles==1,"Player fire was vetoed")
end
local function presentationParity()
    local Simulation=require("src.game.battle.battle_simulation")
    local Party=require("src.ecs.assemblages.party")
    local Unit=require("src.ecs.assemblages.unit")
    local Parties=require("src.systems.parties.party_system")
    local Render=require("src.systems.battle.render_system")
    local world=Ecs.init()
    local a,b=Party.create(world,"parity-a"),Party.create(world,"parity-b")
    for index,party in ipairs({a,b}) do
        local actor=Unit.create(world,"soldier","parity-"..index)
        actor.equipment={};actor.skills={arrow={},fireball={}}
        actor.stats.health=1000;actor.hp=1000;actor.maxHp=1000
        actor.stats.precision=8
        Parties.addActor(party,actor)
    end
    local function run(render)
        math.randomseed(4812)
        local simulation=Simulation.new(a,b)
        local snapshots={}
        for tick=1,180 do
            simulation:tick()
            local entries={}
            for _,u in ipairs(simulation.context.data.unitList) do
                entries[#entries+1]=string.format("%s:%.8f:%.8f:%d",u.id,u.x,u.y,u.hp)
                if render then u.visualEffects.shakeTime=0.1 end
            end
            for _,p in ipairs(simulation.context.data.projectiles) do
                entries[#entries+1]=string.format("%s:%.8f:%.8f:%.8f",p.skillId,p.x,p.y,p.z)
            end
            snapshots[tick]=table.concat(entries,"|")
            if render then Render.update(0.05,simulation.context);Render.draw(simulation.context) end
        end
        simulation:destroy()
        return table.concat(snapshots,"\n")
    end
    assert(run(false)==run(true),"Presentation changed tick/projectile outcomes")
end
function Scenario.run()
    local world=require("src.ecs.world").init()
    local battleWorld=Ecs.startBattle()
    local Unit=require("src.ecs.assemblages.unit")
    local BattleUnit=require("src.ecs.assemblages.battle_unit")
    local actor=Unit.create(world,"soldier","precision-default")
    assert(actor.stats.precision==10)
    actor.stats.precision=32
    local battle=BattleUnit.create(battleWorld,actor,100,100,"player")
    assert(battle.stats.precision==32 and battle.height==battle.collisionRadius*4)
    actor.stats.precision=nil
    assert(BattleUnit.create(battleWorld,actor,100,100,"player").stats.precision==10)
    for _, entry in ipairs({{"archer", "bow", "arrow"}, {"slinger", "sling", "sling_stone"}}) do
        local actor = Unit.create(world, entry[1], "ranged-fixture-"..entry[1])
        local ranged = BattleUnit.create(battleWorld, actor, 100, 200, "player")
        assert(actor.equipment.rangedWeapon == entry[2] and ranged.skills[entry[3]],
            entry[1].." did not receive its equipment-granted ranged skill")
        assert(ranged.stats.precision == 10, entry[1].." has missing Precision")
        local sprite = assert(io.open(actor.sprite, "rb"), entry[1].." has a missing sprite")
        sprite:close()
        local target = unit("ranged-target", 300, 200, "enemy")
        local c = context(ranged, target)
        Execution._executeSkillEffect(ranged, entry[3], target.id, nil, c)
        assert(#c.data.projectiles == 1 and c.data.projectiles[1].skillId == entry[3],
            entry[1].." could not launch its ranged attack")
    end
    geometry();defense();impacts();ai();presentationParity()
    print("M4 precision, trajectory, collision, defense, friendly fire and AI checks passed")
end
return Scenario
