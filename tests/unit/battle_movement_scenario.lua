local World = require("src.ecs.world")
local Execution = require("src.systems.battle.execution_system")
local Context = require("src.game.battle.battle_context")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local Unit = require("src.ecs.assemblages.unit")
local Range = require("src.systems.battle.range_utils")

local function body(id, x, y, radius, team)
    return {id = id, x = x, y = y, collisionRadius = radius, team = team or "player",
        hp = 100, globalCooldown = 0, stats = {battle_speed = 10}, moveStep = 24}
end
local function move(unit, context, x, y)
    unit.globalCooldown = 0
    Execution._executeMove(unit, {target = {x = x, y = y}}, context)
end
local function pair(size, team, otherSize)
    otherSize = otherSize or 3
    local c = Context.new()
    local a, b = body("a", 100, 200, BattleUnit.actorRadius({size = size})), body("b", 160, 200, BattleUnit.actorRadius({size = otherSize}), team)
    a.actor, b.actor = {size = size}, {size = otherSize}
    c.addUnit(a); c.addUnit(b)
    return c, a, b
end
local Scenario = {}
function Scenario.run()
    local world = World.init()
    local actor = Unit.create(world, "soldier", "geometry")
    actor.size, actor.heightMultiplier = 3, nil
    local battle = World.startBattle()
    local human = BattleUnit.create(battle, actor, 100, 100, "player")
    assert(human.collisionRadius == 18 and human.height == 72)
    assert(BattleUnit.actorRadius({size = 2}) == 12)
    assert(BattleUnit.actorRadius({size = 4}) == 21)
    actor.size, actor.heightMultiplier = 5, 2.5
    local ogre = BattleUnit.create(battle, actor, 200, 100, "enemy")
    assert(ogre.collisionRadius == 24 and ogre.height == 60)
    assert(Range.effectiveSkillRange(human, ogre, {range = 1}) == 42 + 18 + 24)
    World.endBattle(battle)
    local Simulation = require("src.game.battle.battle_simulation")
    actor.size = 10
    local actors = {}
    for i = 1, 8 do
        actors[i] = Unit.create(world, "soldier", "giant" .. i)
        actors[i].size = 10
    end
    local sim = Simulation.new({id = "large", actors = actors}, {id = "empty", actors = {}})
    for i, u in ipairs(sim.context.data.unitList) do
        assert(u.collisionRadius == 39 and u.x >= 39 and u.x <= 1221 and u.y >= 39 and u.y <= 507)
        for j = 1, i - 1 do
            local v = sim.context.data.unitList[j]
            assert((u.x - v.x)^2 + (u.y - v.y)^2 >= 78^2, "deployment overlaps large actors")
        end
    end
    sim:destroy()

    -- Nearby backline soldiers must not cause proactive detours through an open lane.
    local lane = Context.new()
    local soldier = body("backline",100,273,18)
    lane.addUnit(soldier)
    for i=1,4 do
        lane.addUnit(body("backline-above"..i,100+i*40,230,18))
        lane.addUnit(body("backline-below"..i,100+i*40,316,18))
    end
    local function attempt(unit, context, x, y)
        unit.globalCooldown=0
        Execution._executeMove(unit,{target={x=x,y=y},avoidObstacles=true},context)
    end
    for i=1,5 do
        attempt(soldier,lane,400,273)
        assert(soldier.x==100+i*24 and soldier.y==273 and not soldier.bypass)
        assert(soldier.stuckAttempts==0)
    end
    -- Temporary obstructions wait for allies rather than immediately circling them.
    local blocked = Context.new()
    local waiting = body("waiting",100,273,24)
    local obstruction = body("obstruction",157,273,33,"enemy")
    blocked.addUnit(waiting); blocked.addUnit(obstruction)
    attempt(waiting,blocked,400,273)
    assert(waiting.x==100 and waiting.y==273 and not waiting.bypass,"temporary obstruction triggered bypass")
    assert(waiting.stuckAttempts==1)
    for _=1,20 do
        local cooldown=waiting.globalCooldown
        Execution._executeMove(waiting,{target={x=400,y=273},avoidObstacles=true},blocked)
        assert(waiting.stuckAttempts==1 and waiting.globalCooldown==cooldown,"cooldown counted as an attempt")
    end
    obstruction.y=400
    attempt(waiting,blocked,400,273)
    assert(waiting.x==124 and waiting.y==273 and waiting.stuckAttempts==0 and not waiting.bypass)
    obstruction.x,obstruction.y=181,273
    attempt(waiting,blocked,400,273)
    assert(waiting.stuckAttempts==1)
    attempt(waiting,blocked,401,273)
    assert(waiting.stuckAttempts==1 and not waiting.bypass,"goal change retained stuck attempts")
    attempt(waiting,blocked,401,273)
    assert(waiting.stuckAttempts==2 and waiting.bypass and waiting.y~=273,
        "clear flank did not move on the second failed attempt")
    assert(waiting.bypass and waiting.bypass.blocker==obstruction,"sustained blockage did not activate bypass")

    -- Retargeting after a kill keeps the route around the same allied ogre.
    local retargetWorld = World.startBattle()
    local retargetContext = Context.new()
    local function fighter(troop, id, x, y, team)
        local unit = BattleUnit.create(retargetWorld,Unit.create(world,troop,id),x,y,team)
        retargetContext.addUnit(unit)
        return unit
    end
    local follower = fighter("soldier","retarget-follower",190,522,"player")
    local ogreBlocker = fighter("ogre","retarget-ogre",240,522,"player")
    local oldTarget = fighter("soldier","retarget-old",400,522,"enemy")
    local newTarget = fighter("soldier","retarget-new",500,522,"enemy")
    local Decision = require("src.systems.battle.decision_system")
    local function advance()
        follower.globalCooldown,follower.intent = 0,nil
        Decision._processAI(follower,retargetContext)
        assert(follower.intent and follower.intent.type=="MOVE")
        Execution._executeMove(follower,follower.intent,retargetContext)
    end
    for _=1,10 do
        advance()
        if follower.slideBlocker then break end
    end
    assert(follower.slideBlocker==ogreBlocker)
    local side = follower.slideSide
    oldTarget.hp = 0
    advance()
    assert(follower.moveTarget.x==newTarget.x,"AI did not switch targets after death")
    assert(follower.slideBlocker==ogreBlocker and follower.slideSide==side,
        "retargeting discarded the sliding direction around the ogre")
    newTarget.y = newTarget.y-2
    advance()
    assert(follower.slideSide==side,"moving target reversed friendly sliding")
    newTarget.x,newTarget.y = 100,400
    advance()
    assert(not follower.bypass,"clear route to new target did not resume direct movement")
    World.endBattle(retargetWorld)

    -- A supported allied frontline is a valid waiting place for a second-rank soldier.
    local packed = Context.new()
    local secondRank = body("second-rank",100,273,18)
    packed.addUnit(secondRank)
    for col=0,2 do
        for row=0,13 do packed.addUnit(body("ally"..col.."-"..row,160+col*36,21+row*36,18)) end
    end
    -- First two actions make direct progress up to the frontline.
    attempt(secondRank,packed,400,273)
    attempt(secondRank,packed,400,273)
    for count=1,2 do
        attempt(secondRank,packed,400,273)
        assert(secondRank.stuckAttempts==count and not secondRank.bypass,
            "crowded frontline received early flank bypass")
    end
    for _=1,50 do
        attempt(secondRank,packed,400,273)
        for _, ally in ipairs(packed.data.unitList) do
            if ally ~= secondRank then
                assert((secondRank.x-ally.x)^2+(secondRank.y-ally.y)^2 >= (28.8)^2-0.001,
                    "friendly sliding overlapped a packed frontline")
            end
        end
    end

    -- A close destination requires moving away from it before rounding the dragon.
    for _, laneY in ipairs({273,50,496,513}) do
        local c = Context.new()
        local ogreActor = Unit.create(world, "ogre", "bypass-ogre"..laneY)
        local dragonActor = Unit.create(world, "dragon", "bypass-dragon"..laneY)
        local bypassWorld = World.startBattle()
        local walker = BattleUnit.create(bypassWorld, ogreActor, 190, laneY, "player")
        local dragon = BattleUnit.create(bypassWorld, dragonActor, 250, laneY, laneY==513 and "player" or "enemy")
        c.addUnit(walker); c.addUnit(dragon)
        local movedAway, bypassSide = false, nil
        for tick = 1, 600 do
            c.data.tick = tick
            if walker.globalCooldown > 0 then
                local x,y,cd=walker.x,walker.y,walker.globalCooldown
                Execution._executeMove(walker,{target={x=320,y=laneY},avoidObstacles=true},c)
                assert(walker.x==x and walker.y==y and walker.globalCooldown==cd,"cooldown bypassed")
                walker.globalCooldown = math.max(0,walker.globalCooldown-1)
            else
                local x,y = walker.x,walker.y
                local oldDistance = (320-x)^2+(laneY-y)^2
                Execution._executeMove(walker,{target={x=320,y=laneY},avoidObstacles=true},c)
                movedAway = movedAway or (320-walker.x)^2+(laneY-walker.y)^2 > oldDistance+0.01
                assert((walker.x-x)^2+(walker.y-y)^2 <= 24^2+0.001)
                if walker.bypass and walker.bypass.side then
                    assert(walker.bypass.blocker == dragon,"wrong blocking unit")
                    bypassSide = bypassSide or walker.bypass.side
                    assert(walker.bypass.side == bypassSide,"bypass side oscillated")
                end
                local reach = (walker.collisionRadius+dragon.collisionRadius)*(walker.team==dragon.team and 0.8 or 1)
                assert((walker.x-dragon.x)^2+(walker.y-dragon.y)^2 >= reach^2-0.001)
            end
        end
        if dragon.team~=walker.team then assert(movedAway,"ogre never accepted a necessary step away from target") end
        assert((walker.x-320)^2+(walker.y-laneY)^2 < 1,"ogre remained stuck behind dragon")
        assert(not walker.bypass,"direct movement did not resume after bypass")
        assert(dragon.x==250 and dragon.y==laneY and dragon.hp==dragon.maxHp)
        World.endBattle(bypassWorld)
    end

    local c, a, b = pair(3, "enemy")
    for _ = 1, 30 do move(a, c, 400, 200) end
    assert(a.x <= b.x - 36 and b.x == 160 and b.y == 200, "enemy line crossed or pushed")
    local stopped = a.x
    for _ = 1, 100 do move(a, c, 400, 200) end
    assert(a.x == stopped, "blocked actor jitters")

    c, a, b = pair(3, "player")
    for _ = 1, 30 do move(a, c, 400, 200) end
    assert(a.x > b.x + 36 and b.y ~= 200, "ally did not yield")
    assert(a.hp == 100 and b.hp == 100)
    for _, team in ipairs({"player", "enemy"}) do
        c, a, b = pair(5, team)
        for _ = 1, 40 do move(a, c, 400, 200) end
        assert(a.x > b.x + 42, "large walker could not pass small troop")
        assert(a.hp == 100 and b.hp == 100, "contact caused damage")
    end
    for _, sizes in ipairs({{4, 3}, {5, 4}}) do
        for _, team in ipairs({"player", "enemy"}) do
            c, a, b = pair(sizes[1], team, sizes[2])
            for _ = 1, 40 do move(a, c, 400, 200) end
            assert(a.x > b.x + a.collisionRadius + b.collisionRadius,
                "one Size point advantage did not allow displacement")
            assert(a.hp == 100 and b.hp == 100, "contact caused damage")
        end
        c, a, b = pair(sizes[2], "enemy", sizes[1])
        for _ = 1, 40 do move(a, c, 400, 200) end
        assert(a.x < b.x and b.y == 200, "smaller actor displaced larger enemy")
    end
    c, a, b = pair(5, "enemy")
    a.moveStep = 1000
    move(a, c, 1200, 200)
    assert(a.x < b.x, "fast movement tunneled through blocker")
    c, a, b = pair(3, "enemy")
    -- A supported line has no free local yielding space and must stay still.
    for i = 1, 5 do c.addUnit(body("crowd" .. i, 160, 200 + i * 36, 18, "enemy")) end
    for _ = 1, 100 do move(a, c, 400, 200) end
    for i, u in ipairs(c.data.unitList) do
        assert(u.hp == 100 and u.x == (i == 1 and a.x or 160))
    end
    c, a, b = pair(3, "player")
    local support = body("support", 160, 230, 18)
    c.addUnit(support)
    for _ = 1, 100 do move(a, c, 400, 200) end
    for _, unit in ipairs({a,b,support}) do
        assert(unit.hp==100)
        for _, other in ipairs({a,b,support}) do
            if unit~=other then assert((unit.x-other.x)^2+(unit.y-other.y)^2>=28.8^2-0.001,
                "sliding through supported allies broke friendly collision separation") end
        end
    end
    c = Context.new()
    a = body("bounds", -100, 1000, 30)
    c.addUnit(a)
    assert(a.x == 30 and a.y == 516)
    for _ = 1, 100 do move(a, c, 2000, -1000) end
    assert(a.x >= 30 and a.x <= 1230 and a.y >= 30 and a.y <= 516)
end
return Scenario
