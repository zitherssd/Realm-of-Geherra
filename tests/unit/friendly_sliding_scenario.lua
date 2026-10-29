require("src.ecs.world")
local Execution = require("src.systems.battle.execution_system")
local Context = require("src.game.battle.battle_context")
local Scenario = {}
local function body(id,x,y,team)
    return {id=id,x=x,y=y,team=team or "player",hp=100,collisionRadius=18,
        actor={size=3},globalCooldown=0,stats={battle_speed=10},moveStep=24}
end
function Scenario.run()
    -- Observe the solver's path length, including every slide and any subsequent bypass segment.
    local index,solver
    for i=1,30 do
        local name,value=debug.getupvalue(Execution._executeMove,i)
        if name=="moveWithCollisions" then index,solver=i,value; break end
    end
    assert(solver,"movement solver not found")
    local path=0
    debug.setupvalue(Execution._executeMove,index,function(...)
        local blocker,distance=solver(...)
        path=path+distance
        return blocker,distance
    end)
    local function move(unit,context,x,y,ai)
        local distance=math.sqrt((x-unit.x)^2+(y-unit.y)^2)
        path=0;unit.globalCooldown=0
        Execution._executeMove(unit,{target={x=x,y=y},avoidObstacles=ai},context)
        assert(path<=24.001,"sliding plus bypass exceeded the movement path budget")
        if distance>0.001 then assert(unit.globalCooldown>=10.8 and unit.globalCooldown<=13.2,"sliding changed cooldown") end
        assert(unit.x>=18 and unit.y>=18 and unit.x<=1242 and unit.y<=528)
        for _,other in ipairs(context.data.unitList) do
            if other~=unit then
                local reach=(unit.collisionRadius+other.collisionRadius)*(unit.team==other.team and 0.8 or 1)
                assert((unit.x-other.x)^2+(unit.y-other.y)^2>=reach^2-0.001,"sliding crossed another unit")
            end
        end
    end
    local ok,err=xpcall(function()
        local outcomes={}
        for _,ai in ipairs({false,true}) do
            local c=Context.new()
            local mover,idlePlayer=body("advancing",100,528),body("idle-player",160,528)
            c.addUnit(mover);c.addUnit(idlePlayer)
            c.data.selectedUnitId=idlePlayer.id
            move(mover,c,400,528,ai)
            assert(mover.x==124 and mover.y==528 and not mover.slideBlocker,"proactive slide")
            move(mover,c,400,528,ai)
            assert(mover.slideBlocker==idlePlayer and mover.y<528,"did not slide within blocked action")
            local side=mover.slideSide
            for _=1,12 do
                move(mover,c,400,528,ai)
                assert(mover.slideSide==side,"sliding direction oscillated")
            end
            assert(mover.x>idlePlayer.x+36,"advancing unit stayed behind idle player")
            assert(idlePlayer.x==160 and idlePlayer.y==528,"idle player was pushed out of bounds")
            assert(not mover.bypass,"friendly sliding required delayed bypass")
            outcomes[#outcomes+1]={x=mover.x,y=mover.y}
        end
        assert(outcomes[1].x==outcomes[2].x and outcomes[1].y==outcomes[2].y,"player/AI cooperation differs")
        local c=Context.new()
        local mover=body("crowd-walker",100,270)
        c.addUnit(mover)
        for i=0,5 do c.addUnit(body("line"..i,160,270+i*30)) end
        for _=1,20 do move(mover,c,500,270,false) end
        assert(mover.x>196,"could not slide past supported friendly line")
        c=Context.new()
        mover=body("enemy-test",100,528)
        local enemy=body("enemy",160,528,"enemy")
        c.addUnit(mover);c.addUnit(enemy)
        for _=1,12 do move(mover,c,400,528,false) end
        assert(mover.x<=124 and mover.y==528 and not mover.slideBlocker,"automatically slid around enemy")
        assert(enemy.x==160 and enemy.y==528 and enemy.hp==100)
        -- An enemy beside a friendly contact must also block every proposed slide segment.
        c=Context.new()
        mover=body("mixed-walker",100,528)
        local ally=body("mixed-ally",160,528)
        enemy=body("mixed-enemy",132,490,"enemy")
        c.addUnit(mover);c.addUnit(ally);c.addUnit(enemy)
        for _=1,20 do move(mover,c,400,528,false) end
        assert(enemy.x==132 and enemy.y==490 and enemy.hp==100)
        assert(not mover.bypass,"manual friendly sliding activated AI bypass")
    end,debug.traceback)
    debug.setupvalue(Execution._executeMove,index,solver)
    if not ok then error(err) end
    print("Friendly sliding, crowded line, idle player, swept collisions and path budget PASS")
end
return Scenario
