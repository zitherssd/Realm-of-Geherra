local Ecs = require("src.ecs.world")
local C = require("src.systems.actors.conditions")
local Stats = require("src.systems.actors.effective_stats")
local Combat = require("src.systems.battle.combat_system")
local Execution = require("src.systems.battle.execution_system")
local Simulation = require("src.game.battle.battle_simulation")
local Context = require("src.game.battle.battle_context")
local Visuals = require("src.game.battle.condition_visuals")
local Render = require("src.systems.battle.render_system")
local Dice = require("src.utils.math")
local Skills = require("src.data.skills")
local Test = {}
local function near(a,b) assert(math.abs(a-b)<0.015,tostring(a).." ~= "..tostring(b)) end
local function unit(id,team)
    return {id=id,team=team or "player",hp=100,maxHp=100,stats={attack=20,defense=10,strength=0,precision=16,battle_speed=120,morale=10},
        x=100,y=100,visualX=64,visualY=64,equipment={},skills={attack=true},cooldowns={},charges={},globalCooldown=0,
        statusEffects={},injuries={},visualEffects={shakeTime=0,lungeTime=0,flashTime=0},moraleExempt=true,collisionRadius=18,
        actor={sprite="condition-fixture"},destroy=function() end}
end
local function apply(u,id,effects,extra)
    local config={battleLong=true,effects=effects}
    for k,v in pairs(extra or {}) do config[k]=v end
    return C.apply(u,id,config)
end
local function damage()
    local a,b=unit("a"),unit("b","enemy")
    a.stats.strength=8;b.innateProtections={slashing=2}
    local skill={baseDamage=10,damageType="slashing"}
    assert(Combat.calculateDamage(a,b,skill)==12)
    apply(a,"out",{outgoingDamage=2,outgoingDamageMultiplier=2})
    apply(b,"in",{incomingDamage=-4,incomingDamageMultiplier=0.5})
    assert(Combat.calculateDamage(a,b,skill)==12,"Incorrect modifier order")
    assert(a.stats.strength==8 and b.innateProtections.slashing==2)
    C.apply(b,"stoneskin");assert(Combat.calculateDamage(a,b,skill)==9)
    C.apply(a,"rage");assert(Stats.get(a,"strength")==12 and a.stats.strength==8)
    assert(Combat.calculateDamage(a,b,skill)==11)
    C.apply(b,"mistform");assert(Combat.calculateDamage(a,b,skill)==1)
    apply(b,"floor",{incomingDamageMin=5});assert(Combat.calculateDamage(a,b,skill)==1,"Upper cap must win")
    a.statusEffects={};b.statusEffects={};C.apply(b,"resist_cold")
    assert(Combat.typedDamage(a,b,10,"ice")==5 and Combat.typedDamage(a,b,10,"fire")==10)
    apply(a,"limit",{outgoingDamageMin=2,outgoingDamageMax=4})
    assert(Combat.typedDamage(a,b,10,"fire")==4 and Combat.typedDamage(a,b,0,"fire")==2)
    -- Periodic damage takes the same incoming modifier path exactly once.
    b.statusEffects={};b.innateProtections={fire=1}
    C.apply(b,"burn",{duration=1,tickEvery=1,damagePerTick=5})
    apply(b,"half",{incomingDamageMultiplier=0.5})
    Execution.tickStatuses(b,Context.new())
    assert(b.hp==98)
end
local function reactions()
    local a,b=unit("a"),unit("b","enemy")
    local c=Context.new();c.addUnit(a);c.addUnit(b);c.data.conditionRng=function() return 0.99 end
    C.apply(b,"immolation");C.apply(a,"immolation")
    local result=Combat.resolveAttack(a,b,Skills.attack)
    assert(result.hit and a.hp==97 and b.hp==97,"Retaliation recursed or duplicated")
    assert(#a.injuries==0)
    a.statusEffects={};b.statusEffects={};a.hp=100;b.hp=100
    apply(b,"attempt",nil,{reactions={onAttackReceived={damage=1},onHitReceived={damage=2},onDamageReceived={damage=4}}})
    apply(a,"dealt",nil,{reactions={onHitDealt={apply={poison=true}}}})
    a.stats.attack=0;b.stats.defense=100
    result=Combat.resolveAttack(a,b,Skills.attack)
    assert(not result.hit and a.hp==99 and not b.statusEffects.poison)
    a.stats.attack=200;b.innateProtections={slashing=100}
    result=Combat.resolveAttack(a,b,Skills.attack)
    assert(result.hit and result.damage==0 and a.hp==96 and b.statusEffects.poison.stacks==1)
    b.innateProtections={}
    result=Combat.resolveAttack(a,b,Skills.attack)
    assert(result.hit and result.damage==3 and a.hp==89 and b.statusEffects.poison.stacks==2)
    -- Projectile and AoE events use their delivery type; melee-only retaliation stays quiet.
    a.statusEffects={};b.statusEffects={};a.hp=100;b.hp=100
    C.apply(b,"immolation")
    apply(b,"any-hit",nil,{reactions={onHitReceived={damage=2,damageType="shock"}}})
    Combat.resolveProjectileAttack(a,b,{baseDamage=1,projectile={defenseMode="none"}})
    assert(a.hp==98)
    Combat.resolveAreaEffect(a,b,{baseDamage=0})
    assert(a.hp==96)
    Combat.resolveAreaEffect(a,b,{onHitStatuses={stun=true}});assert(a.hp==94,"Status-only AoE missed hit reaction")
    -- A probabilistic expiry follows a hit, including a zero-damage hit, never a miss.
    b.statusEffects={};C.apply(b,"mistform");a.stats.attack=0;b.stats.defense=100
    c.data.conditionRng=function() return 0 end
    Combat.resolveAttack(a,b,Skills.attack);assert(b.statusEffects.mistform)
    a.stats.attack=200
    result=Combat.resolveAttack(a,b,Skills.attack);assert(result.damage==1 and not b.statusEffects.mistform)
    apply(b,"two",nil,{expiresOn={event="onHitReceived",triggers=2}})
    Combat.resolveAreaEffect(a,b,{baseDamage=0});assert(b.statusEffects.two)
    C.apply(b,"two",{battleLong=true,expiresOn={event="onHitReceived",triggers=2}})
    Combat.resolveAreaEffect(a,b,{baseDamage=0});assert(not b.statusEffects.two,"Refresh reset trigger progress")
    -- Multiple reaction conditions run in ID order, regardless of insertion order.
    local order={}
    apply(b,"z",nil,{reactions={onHitReceived={damage=1}}})
    apply(b,"a",nil,{reactions={onHitReceived={damage=2}}})
    C.trigger(b,"onHitReceived","melee",function() error("Unneeded RNG") end,function(r) order[#order+1]=r.damage end)
    assert(order[1]==2 and order[2]==1)
end
local function projectiles()
    local a,b=unit("a"),unit("b","enemy")
    -- Two equal dice cancel, so Precision/8 == shield*2 is an exact miss.
    b.equipment.offHand="wooden_shield";b.itemDurability={wooden_shield=10}
    a.stats.precision=32
    local hit,margin=Combat.rollProjectileDefense(a,b);assert(not hit and margin==0)
    a.stats.precision=40;assert(Combat.rollProjectileDefense(a,b))
    C.apply(b,"air_shield");a.stats.precision=32
    local result=Combat.resolveProjectileAttack(a,b,{baseDamage=3,projectile={}})
    assert(not result.hit and result.action=="evade" and b.itemDurability.wooden_shield==10,"Magical defense wore shield")
    local old=Dice.rollExploding
    Dice.rollExploding=function() error("Defense roll on defenseMode none") end
    local ok,err=pcall(Combat.resolveProjectileContact,a,b,{projectile={defenseMode="none"}})
    Dice.rollExploding=old;assert(ok,err)
end
local function lifecycle()
    local u=unit("u");u.injuryProfile="humanoid"
    C.apply(u,"burn");C.apply(u,"poison");C.apply(u,"stoneskin")
    apply(u,"locked",nil,{category="buff",dispellable=false,lifetime="persistent"})
    assert(C.cleanse(u,{category="poison"})==1 and not u.statusEffects.poison and u.statusEffects.burn)
    assert(C.cleanse(u,{category="buff"})==1 and u.statusEffects.locked)
    assert(C.cleanse(u,{id="burn"})==1)
    local Data=require("src.data.injuries");local Injury=require("src.systems.actors.injury_system")
    for id,def in pairs(Data.definitions) do
        for _,part in ipairs(Injury.profile(u).bodyParts) do
            if part.category==def.category then
                assert(Injury.apply(u,{id=id,bodyPart=part.id}))
                assert(C.cleanse(u,{category="injury"})==0 and #u.injuries==1)
                local prior=def.dispellable;def.dispellable=true
                assert(C.cleanse(u,{category="injury"})==1 and #u.injuries==0)
                def.dispellable=prior
                assert(C.remove(u,"locked"));return
            end
        end
    end
    error("No injury fixture")
end
local function visuals()
    local a,b=unit("a"),unit("b")
    assert(not Visuals.compose(a).active and Visuals.compose(a).alpha==1)
    for _,u in ipairs({a,b}) do
        apply(u,"mist",nil,{visual={alpha=0.6}})
        apply(u,"gray",nil,{visual={saturation=0.3}})
    end
    apply(a,"red",nil,{visual={tint={1,0,0,0.5},priority=10}})
    apply(a,"blue",nil,{visual={tint={0,0,1,0.5},priority=1}})
    apply(b,"blue",nil,{visual={tint={0,0,1,0.5},priority=1}})
    apply(b,"red",nil,{visual={tint={1,0,0,0.5},priority=10}})
    local av,bv=Visuals.compose(a),Visuals.compose(b)
    near(av.alpha,0.6);near(av.saturation,0.3)
    for i=1,3 do near(av.tint[i],bv.tint[i]) end
    near(av.tint[1],0.75);near(av.tint[2],0.25);near(av.tint[3],0.5)
    apply(a,"more-mist",nil,{visual={alpha=0.5,saturation=0.5}})
    near(Visuals.compose(a).alpha,0.3);near(Visuals.compose(a).saturation,0.15)
    -- Composite fixture: body and equipment pixels share the same presentation.
    local data=love.image.newImageData(16,16)
    for y=0,15 do for x=0,15 do data:setPixel(x,y,x<8 and 1 or 0,0,x>=8 and 1 or 0,1) end end
    local image=love.graphics.newImage(data)
    local original=love.graphics.newImage
    love.graphics.newImage=function(path,...) if path=="condition-fixture" then return image end;return original(path,...) end
    local ok,err=xpcall(function()
        local canvas=love.graphics.newCanvas(128,128)
        love.graphics.push("all");love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0)
        a.statusEffects={};apply(a,"look",nil,{visual={alpha=0.5,saturation=0}})
        love.graphics.setColor(0.2,0.3,0.4,0.8);love.graphics.setBlendMode("add")
        local before={love.graphics.getColor()};local shader=love.graphics.getShader()
        -- Use ordinary alpha blending for pixel verification, and verify complete state restoration.
        love.graphics.setBlendMode("alpha")
        Render.drawUnit(a,false)
        local after={love.graphics.getColor()};for i=1,4 do near(before[i],after[i]) end
        assert(love.graphics.getShader()==shader and love.graphics.getBlendMode()=="alpha")
        love.graphics.setCanvas();local pixels=canvas:newImageData()
        for _,x in ipairs({58,70}) do
            local r,g,bb,alpha=pixels:getPixel(x,64)
            near(r,g);near(g,bb);near(alpha,0.5)
        end
        love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0);a.statusEffects={}
        Render.drawUnit(a,false);love.graphics.setCanvas()
        pixels=canvas:newImageData();local r,g,bb,alpha=pixels:getPixel(58,64)
        near(r,1);near(g,0);near(bb,0);near(alpha,1)
        local sentinel=love.graphics.newShader[[vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { return Texel(t,uv)*c; }]]
        apply(a,"look-again",nil,{visual={alpha=0.5,saturation=0.3}})
        love.graphics.setShader(sentinel);love.graphics.setBlendMode("add")
        Render.drawUnit(a,false)
        assert(love.graphics.getShader()==sentinel and love.graphics.getBlendMode()=="add")
        love.graphics.pop()
    end,debug.traceback)
    love.graphics.newImage=original;assert(ok,err)
end
local function parity()
    local function run(render)
        math.randomseed(51);Ecs.init()
        local a,b=unit("a"),unit("b","enemy")
        a.actor=nil;b.actor=nil;a.sprite="condition-fixture";b.sprite="condition-fixture"
        local sim=Simulation.new({id="pa",actors={a}},{id="pb",actors={b}},false,{conditionRng=function() return 0.99 end,moraleRng=function() return 1 end})
        for _,u in ipairs(sim.context.data.unitList) do
            apply(u,"visual-only",nil,{visual={alpha=0.6,saturation=0.2,tint={1,0.5,0.5}}})
        end
        for _=1,60 do
            sim:tick()
            if render then for _,u in ipairs(sim.context.data.unitList) do Render.drawUnit(u,false) end end
        end
        local result=sim:buildResult("timeout")
        local snapshot={}
        for _,id in ipairs({"a","b"}) do snapshot[#snapshot+1]=result.actors[id].finalHp end
        sim:destroy();return snapshot
    end
    local a,b=run(false),run(true);assert(a[1]==b[1] and a[2]==b[2],"Rendering changed simulation")
end
function Test.run()
    local original=Dice.rollExploding;Dice.rollExploding=function() return 1 end
    local ok,err=xpcall(function() damage();reactions();projectiles();lifecycle();visuals();parity() end,debug.traceback)
    Dice.rollExploding=original;assert(ok,err)
    print("M5.1-C modifiers, reactive events, lifecycle and rendered presentation PASS")
end
return Test


