local Ecs = require("src.ecs.world")
local Aoe = require("src.game.battle.aoe")
local Execution = require("src.systems.battle.execution_system")
local Combat = require("src.systems.battle.combat_system")
local Context = require("src.game.battle.battle_context")
local Projectile = require("src.game.battle.projectiles")
local Skills = require("src.data.skills")
local Dice = require("src.utils.math")
local Morale = require("src.game.battle.morale")
local Scenario = {}

local function unit(id,x,y,team,radius)
    return {id=id,x=x,y=y,visualX=x,visualY=y,team=team or "player",hp=100,maxHp=100,
        collisionRadius=radius or 18,height=72,stats={strength=0,precision=100,morale=10},
        equipment={},itemDurability={},injuries={},statusEffects={},visualEffects={},
        skills={},cooldowns={},charges={},globalCooldown=0,battleMorale=100,moraleExempt=true}
end
local function context(...)
    local c=Context.new()
    for _,u in ipairs({...}) do c.addUnit(u) end
    return c
end
local function geometry()
    local function hit(shape,x,y,r) return Aoe.intersects(shape,{x=x,y=y,collisionRadius=r or 0}) end
    local circle={shape="circle",x=0,y=0,radius=10}
    assert(hit(circle,15,0,5) and not hit(circle,15.001,0,5),"Circle tangent boundary")
    assert(hit(circle,0,0,0) and hit(circle,12,0,3),"Circle containment/partial overlap")
    local cone={shape="cone",x=0,y=0,dx=1,dy=0,length=10,angle=math.pi/2}
    local d=10/math.sqrt(2)
    assert(hit(cone,d,d) and hit(cone,12,0,2) and not hit(cone,12.001,0,2),"Cone arc boundary")
    assert(hit(cone,5,7,math.sqrt(2)) and not hit(cone,5,7,1.4),"Cone radial edge tangent")
    assert(not hit(cone,9,9,1),"Cone used triangular or infinite wedge approximation")
    assert(hit(cone,d+1,d+1,math.sqrt(2)),"Cone arc endpoint overlap")
    assert(hit(cone,-1,0,1) and not hit(cone,-1.01,0,1),"Cone origin overlap")
    cone.angle=3*math.pi/2
    assert(hit(cone,-5,5) and not hit(cone,-5,0),"Reflex sector")
    cone.angle=2*math.pi;assert(hit(cone,-10,0),"Full sector")
    cone.angle=0;assert(hit(cone,5,1,1) and not hit(cone,5,1.01,1),"Zero-angle sector")
    cone.length=0;assert(hit(cone,0,1,1) and not hit(cone,0,2,1),"Zero-length sector")
    local line={shape="line",x=0,y=0,dx=1,dy=0,length=10,width=4}
    assert(hit(line,5,3,1) and not hit(line,5,3.01,1),"Capsule width")
    assert(hit(line,-3,0,1) and hit(line,13,0,1) and not hit(line,13.01,0,1),"Rounded ends")
    assert(not hit(line,12,2),"Capsule was a rectangle")
    line.dx,line.dy=0,2;assert(hit(line,3,5,1),"Direction normalization")
    line.length=0;assert(hit(line,3,0,1),"Zero-length capsule")
    line.width=-1;assert(not hit(line,2,0,1),"Negative width clamp")
    line.length=-1;line.dx,line.dy=0,0;assert(hit(line,0,0),"Degenerate direction")
    circle.radius=-1;assert(hit(circle,0,1,1) and not hit(circle,0,2,1),"Degenerate circle")

    local Ecs=require("src.ecs.world")
    local Unit=require("src.ecs.assemblages.unit")
    local BattleUnit=require("src.ecs.assemblages.battle_unit")
    local world,battle=Ecs.init(),Ecs.startBattle()
    local a=Unit.create(world,"soldier","small");a.size=1
    local b=Unit.create(world,"soldier","large");b.size=6
    local small=BattleUnit.create(battle,a,120,100,"player")
    local large=BattleUnit.create(battle,b,120,100,"player")
    circle={shape="circle",x=100,y=100,radius=1}
    assert(small.collisionRadius==6 and large.collisionRadius==27)
    assert(not Aoe.intersects(circle,small) and Aoe.intersects(circle,large),"Actual Size radius ignored")
end

local function effects()
    local a,b,ally=unit("caster",100,100),unit("enemy",110,100,"enemy"),unit("ally",110,100)
    local c=context(a,b,ally)
    c.data.unitList[#c.data.unitList+1]=b -- Repeated references and overlapping bodies.
    local skill={id="area-test",baseDamage=15,damageType="fire",
        aoe={shape="circle",radius=20},onHitStatuses={"burn","stun"}}
    b.protections={fire=5};b.equipment.offHand="wooden_shield";b.itemDurability.wooden_shield=10
    local targets=Execution._resolveAoeAtPoint(a,skill,100,100,c)
    assert(#targets==3 and a.hp==85 and b.hp==90 and ally.hp==85,"Friendly fire/self/dedup/protection")
    assert(b.statusEffects.burn and b.statusEffects.stun and b.itemDurability.wooden_shield==10,"Multiple effects or shield")
    local heal={id="area-heal",healing=50,aoe={shape="circle",radius=20,eligibility="allies"},onHitStatuses={stun=10}}
    targets=Execution._resolveAoeAtPoint(a,heal,100,100,c)
    assert(#targets==2 and a.hp==100 and ally.hp==100 and b.hp==90 and a.statusEffects.stun.remaining==10,"Ally heal/caster/max HP")
    skill.aoe.eligibility="enemies"
    targets=Execution._resolveAoeAtPoint(a,skill,100,100,c)
    assert(#targets==1 and b.hp==80 and a.hp==100 and ally.hp==100,"Enemy eligibility")
    b.escaped=true;assert(#Aoe.select({shape="circle",x=100,y=100,radius=20},{a,b},a,"enemies")==0)
    b.escaped=false;b.hp=0
    assert(#Aoe.select({shape="circle",x=100,y=100,radius=20},{b},a)==0,"Dead actor selected")

    -- A first casualty can route the caster and move a later selected actor.
    b.hp=10;ally.hp=10;a.hp=100;a.moraleExempt=false
    local process=Morale.process
    local calls=0
    Morale.process=function(ctx)
        calls=calls+1
        if calls==1 then a.fleeing=true;ally.x=900 end
        process(ctx)
    end
    skill.aoe.eligibility="all"
    targets=Execution._resolveAoeAtPoint(a,skill,100,100,c)
    Morale.process=process
    assert(#targets==3 and b.hp==0 and ally.hp==0,"Target set changed mid-resolution")
    assert(b.moraleDefeatReported and ally.moraleDefeatReported,"Casualty events merged")
end

local function delivery()
    local a,b,ally=unit("caster",100,100),unit("enemy",180,100,"enemy"),unit("ally",150,100)
    local c=context(a,b,ally)
    for _,kind in ipairs({"cone","line","circle"}) do
        local id="test_"..kind
        Skills[id]={id=id,type="aoe",range=5,windup=2,cooldown=7,maxCharges=1,baseDamage=10,
            aoe={shape=kind,length=100,width=10,angle=math.pi/2,radius=100}}
        a.skills[id]={};a.charges[id]=1;a.globalCooldown=0;a.fleeing=false
        a.hp,b.hp,ally.hp=100,100,100
        Execution._initiateSkill(a,{skillId=id,target={x=180,y=100}},c)
        assert(a.currentCast and #c.data.projectiles==0 and b.hp==100,"Windup bypassed")
        a.currentCast.remaining=0;Execution._completeCast(a,c)
        assert(a.hp==90 and b.hp==90 and ally.hp==90,"Shape delivery or self-intersection")
        assert(a.cooldowns[id]==7 and a.globalCooldown==7 and a.charges[id]==0,"Cooldown/charge")
        a.globalCooldown=0;Execution._initiateSkill(a,{skillId=id,target=b},c)
        assert(not a.currentCast,"Exhausted skill activated")
        Skills[id]=nil
    end
    local shape=Aoe.at(a,{shape="line",length=20,width=0,origin={x=300,y=100}},320,100)
    assert(Aoe.intersects(shape,{x=320,y=100,collisionRadius=0}) and shape.x==300,"Explicit line origin")
    a.facing=1;shape=Aoe.at(a,{shape="cone",length=20,angle=0},a.x,a.y)
    assert(Aoe.intersects(shape,{x=80,y=100,collisionRadius=0}),"Facing fallback")
end

local function projectileImpacts()
    local defense=Combat.rollProjectileDefense
    Combat.rollProjectileDefense=function() error("Fireball performed a projectile-defense roll") end
    local function run(a,c,skill,target)
        local p=Projectile.launch(a,skill,target.x,target.y,target,function() return 0.5 end)
        c.addProjectile(p)
        for _=1,100 do Execution._updateProjectiles(c);if #c.data.projectiles==0 then break end end
        assert(#c.data.projectiles==0,"Projectile failed to terminate")
        return p
    end
    local a,b,front,overlap=unit("caster",100,200),unit("intended",400,200,"enemy"),
        unit("interceptor",180,200),unit("overlap",180,200,"enemy")
    a.collisionRadius=50 -- Its collision circle touches the actual explosion.
    local c=context(a,b,front,overlap)
    front.equipment.offHand="wooden_shield";front.itemDurability.wooden_shield=10
    front.protections={fire=5}
    a.stats.precision=0 -- Physical aim is fixed by the fixture; defense must never run.
    local p=run(a,c,Skills.fireball,b)
    assert(p.x<front.x and p.x~=b.x and p.z>0,"Explosion not at physical interception")
    assert(a.hp==85 and front.hp==90 and overlap.hp==85 and b.hp==100,"Splash self/overlap/direct double hit/protection")
    assert(front.itemDurability.wooden_shield==10 and front.statusEffects.burn and overlap.statusEffects.burn,
        "Fireball wore a shield or lost statuses")
    local explosions=0
    for _,v in ipairs(c.data.vfx) do
        if v.type=="fire_explosion" then explosions=explosions+1;assert(v.x==p.x and v.y==p.y) end
    end
    assert(explosions==1)
    Execution._updateProjectiles(c);assert(front.hp==90,"Animation repeated damage")

    a,b=unit("unshielded-caster",100,200),unit("unshielded-target",200,200,"enemy")
    c=context(a,b);p=run(a,c,Skills.fireball,b)
    assert(b.hp==85 and b.statusEffects.burn and c.data.vfx[1].x==p.x,"Unshielded unit impact failed")

    -- A curved fireball reaches ground without contacting these short cylinders.
    a=unit("ground-caster",100,200)
    b=unit("ground-victim",225,225,"enemy");b.height=1
    c=context(a,b)
    local ground={id="ground-test",baseDamage=15,damageType="fire",aoe=Skills.fireball.aoe,
        projectile={style="fireball",speed=30,arc=30,defenseMode="none"}}
    p=run(a,c,ground,{x=180,y=200,height=72})
    assert(math.abs(p.z)<0.000001 and b.hp==85,"Ground explosion missed")
    assert(c.data.vfx[1].x==p.x,"Ground impact position changed")
    for _,config in ipairs({{speed=10,maxRange=5},{speed=1,maxLifetime=1},{speed=600,maxRange=5000}}) do
        config.style="fireball"
        config.defenseMode="none"
        local skill={id="expiry",baseDamage=15,aoe=Skills.fireball.aoe,projectile=config}
        a=unit("expiry-caster",100,200);c=context(a)
        run(a,c,skill,{x=400,y=200,height=72})
        assert(a.hp==100 and #c.data.vfx==0,"Expiry caused explosion")
    end
    -- Both M4 defense outcomes suppress payload; evade continuation stays harmless.
    local opposedArea={id="opposed-area",baseDamage=15,aoe=Skills.fireball.aoe,
        projectile={style="fireball",speed=24,defenseMode="opposed"}}
    for _,action in ipairs({"block","evade"}) do
        a,b=unit("defend-caster",100,200),unit("defender",200,200,"enemy")
        b.equipment.offHand=action=="block" and "wooden_shield" or nil
        b.itemDurability.wooden_shield=10
        Combat.rollProjectileDefense=function() return false,-1,action=="block" and 1 or 0 end
        c=context(a,b);run(a,c,opposedArea,b)
        assert(a.hp==100 and b.hp==100 and next(b.statusEffects)==nil and #c.data.vfx==0,"Defended payload exploded")
        if action=="block" then assert(b.itemDurability.wooden_shield==9) end
    end
    Combat.rollProjectileDefense=defense
end

local function compatibility()
    local a,b=unit("melee",100,100),unit("target",130,100,"enemy")
    a.stats.attack=100;b.stats.defense=0
    assert(Combat.resolveAttack(a,b,Skills.attack).hit and b.hp==97,"Melee damage changed")
    a.stats.precision=100
    assert(Combat.resolveProjectileAttack(a,b,Skills.arrow).hit and b.hp==87,"Single-target projectile changed")
    a.stats.precision=0
    assert(not Combat.resolveProjectileAttack(a,b,Skills.arrow).hit and b.hp==87,"Single-target defense changed")

    for _,skill in ipairs({Skills.arrow,Skills.javelin_throw}) do
        for _,mode in ipairs({"default","opposed"}) do
            local configured={}
            for key,value in pairs(skill) do configured[key]=value end
            configured.projectile={}
            for key,value in pairs(skill.projectile) do configured.projectile[key]=value end
            if mode=="opposed" then configured.projectile.defenseMode="opposed" end
            for _,shielded in ipairs({false,true}) do
                a,b=unit("defended-caster",100,200),unit("defended-target",250,200,"enemy")
                a.stats.precision=shielded and 8 or 0
                if shielded then b.equipment.offHand="wooden_shield";b.itemDurability.wooden_shield=1 end
                local c=context(a,b)
                local p=Projectile.launch(a,configured,b.x,b.y,b,function() return 0.5 end)
                c.addProjectile(p)
                for _=1,30 do
                    Execution._updateProjectiles(c)
                    if p.visualOnly or #c.data.projectiles==0 then break end
                end
                assert(b.hp==100 and #c.data.vfx==0,"Arrow/javelin defense failed")
                if shielded then
                    assert(#c.data.projectiles==0 and not b.equipment.offHand,"Shield block failed to stop projectile/wear shield")
                else
                    assert(p.visualOnly and #c.data.projectiles==1,"Unshielded tie failed to evade")
                end
            end
        end
    end

    local Simulation=require("src.game.battle.battle_simulation")
    local Party=require("src.ecs.assemblages.party")
    local Unit=require("src.ecs.assemblages.unit")
    local Parties=require("src.systems.parties.party_system")
    local Render=require("src.systems.battle.render_system")
    local world=Ecs.init()
    local partyA,partyB=Party.create(world,"m5-a"),Party.create(world,"m5-b")
    for index,party in ipairs({partyA,partyB}) do
        local actor=Unit.create(world,"soldier","m5-parity-"..index)
        actor.equipment={};actor.skills={fireball={}}
        actor.stats.health=1000;actor.hp=1000;actor.maxHp=1000
        actor.stats.precision=100
        Parties.addActor(party,actor)
    end
    local function run(render)
        math.randomseed(4812)
        local sim=Simulation.new(partyA,partyB)
        local snapshots={}
        for tick=1,180 do
            sim:tick()
            local entries={}
            for _,u in ipairs(sim.context.data.unitList) do
                entries[#entries+1]=string.format("%s:%.8f:%.8f:%d:%s",u.id,u.x,u.y,u.hp,tostring(u.statusEffects.burn and u.statusEffects.burn.remaining))
            end
            for _,p in ipairs(sim.context.data.projectiles) do
                entries[#entries+1]=string.format("%s:%.8f:%.8f:%.8f",p.skillId,p.x,p.y,p.z)
            end
            snapshots[tick]=table.concat(entries,"|")
            if render then Render.update(0.05,sim.context);Render.draw(sim.context) end
        end
        assert(sim.context.data.unitList[1].hp<1000,"Parity fixture never received AoE damage")
        sim:destroy()
        return table.concat(snapshots,"\n")
    end
    assert(run(false)==run(true),"Rendering changed shared simulation AoE results")
    assert(partyA.actors[1].hp==1000 and partyB.actors[1].hp==1000,"Battle mutated campaign actors")
end

local function casualtyOpportunities()
    local Simulation=require("src.game.battle.battle_simulation")
    local function actor(id)
        return {id=id,hp=100,size=3,stats={health=100,morale=10,battle_speed=10},skills={attack=true},equipment={}}
    end
    local a={id="a",leaderId="a1",actors={actor("a1"),actor("a2"),actor("a3"),actor("a4")}}
    local b={id="b",leaderId="b1",actors={actor("b1"),actor("b2")}}
    local calls=0
    local sim=Simulation.new(a,b,false,{moraleRng=function() calls=calls+1;return 0.999 end})
    local c=sim.context
    local u=c.data.units
    for _,unit in ipairs(c.data.unitList) do unit.x,unit.y=600,270 end
    u.a1.x,u.a4.x=100,100
    u.a3.battleMorale,u.a4.battleMorale=50,25
    u.a3.stats.morale=1e12
    u.b1.stats.strength=1000
    Execution._resolveAoeAtPoint(u.b1,Skills.fireball,600,270,c)
    assert(u.a2.hp==0 and u.a3.hp==0 and calls==3,"Separate casualties lost independent M3 rout opportunities")
    local before=calls;Morale.process(c);assert(calls==before,"Casualty events repeated")
    sim:destroy()
end

function Scenario.run()
    local dice,attack,projectileDefense=Dice.rollExploding,Combat.rollAttack,Combat.rollProjectileDefense
    local ok,err=xpcall(function()
        Dice.rollExploding=function(sides) assert(sides==6,"AoE performed an accuracy/defense roll");return 1 end
        Combat.rollAttack=function() error("AoE rolled melee accuracy") end
        Combat.rollProjectileDefense=function() error("AoE rolled projectile defense") end
        geometry();effects();delivery();projectileImpacts()
        Dice.rollExploding=function() return 1 end
        Combat.rollAttack,Combat.rollProjectileDefense=attack,projectileDefense
        compatibility();casualtyOpportunities()
    end,debug.traceback)
    Dice.rollExploding,Combat.rollAttack,Combat.rollProjectileDefense=dice,attack,projectileDefense
    assert(ok,err)
    print("M5 geometry, eligibility, effects, delivery and physical impact checks passed")
end
return Scenario
