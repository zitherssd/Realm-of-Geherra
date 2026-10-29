local Squads = require("src.game.battle.squads")
local World = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Context = require("src.game.battle.battle_context")
local Execution = require("src.systems.battle.execution_system")
local GameContext = require("src.game.game_context")
local StateManager = require("src.core.state_manager")
local Deployment = require("src.game.states.party_deployment_state")
local Scenario = {}
function Scenario.run()
    local world=World.init()
    local player=Unit.create(world,"player","capacity-player")
    local companion=Unit.create(world,"companion","capacity-companion")
    local troop=Unit.create(world,"soldier","capacity-troop")
    local npc=Unit.create(world,"soldier","capacity-npc"):give("npc")
    local party={id="capacity",actors={player,companion,troop,npc},leaderId=player.id}
    troop.attributes.command=4
    for level=0,4 do
        player.attributes.command=level
        assert(Squads.capacity(party)==({[0]=0,1,1,2,2})[level])
    end
    companion.attributes.command,npc.attributes.command=3,2
    assert(Squads.capacity(party)==5)
    Squads.reconcile(party)
    assert(#party.squads==0,"capacity created squads")
    assert(Squads.create(party))
    assert(Squads.create(party) and #party.squads==2)
    assert(Squads.transfer(party,troop.id,2))
    assert(party.squads[2].members[1]==troop.id)
    assert(not Squads.transfer(party,"invalid",1) and not Squads.transfer(party,troop.id,9))
    player.attributes.command,companion.attributes.command,npc.attributes.command=1,0,0
    Squads.reconcile(party)
    assert(#party.squads==1 and #party.squads[1].members==4)
    assert(not Squads.create(party))
    player.attributes.command=0
    local fallback=Squads.reconcile(party)
    assert(#party.squads==0 and #fallback[1].members==4 and Squads.capacity(party)==0)
    player.attributes.command=3
    Squads.reconcile(party)
    player.attributes.command=4
    Squads.reconcile(party)
    assert(#party.squads==0)
    assert(Squads.create(party))
    assert(Squads.create(party))
    assert(Squads.transfer(party,troop.id,2))
    assert(Squads.remove(party,1) and #party.squads[1].members==4)
    local layouts,leader=Squads.layout(party)
    assert(Squads.place(layouts,1,leader,300,280,"line"))
    assert(not Squads.place(layouts,1,leader,-100,280,"line"))
    local saved=party.squads[1]
    local oldParty=rawget(GameContext.data,"playerParty")
    rawset(GameContext.data,"playerParty",party)
    local oldPush,oldPop=StateManager.push,StateManager.pop
    local opened,closed=false,false
    StateManager.push=function(name) assert(name=="party_deployment"); opened=true; Deployment.enter() end
    StateManager.pop=function() closed=true; Deployment.exit() end
    local ok,err=xpcall(function()
        assert(require("src.game.states.world_state").keypressed("p",false) and opened)
        Deployment.draw()
        Deployment.keypressed("n")
        assert(#party.squads==2)
        Deployment.mousepressed(love.graphics.getWidth()-270,163,1)
        assert(party.squads[2].members[1]==troop.id,"roster click did not transfer actor")
        Deployment.keypressed("delete")
        assert(#party.squads==1)
        Deployment.keypressed("escape")
        assert(closed and party.squads[1]==saved and saved.x==300)
    end,debug.traceback)
    rawset(GameContext.data,"playerParty",oldParty)
    StateManager.push,StateManager.pop=oldPush,oldPop
    if not ok then error(err) end
    local function body(id,x,y,r,team)
        return {id=id,x=x,y=y,hp=100,team=team,collisionRadius=r,globalCooldown=0,stats={battle_speed=10}}
    end
    local c=Context.new()
    local a,b=body("walker",100,220,18,"player"),body("large",170,220,39,"enemy")
    c.addUnit(a);c.addUnit(b)
    local deviated=false
    for tick=1,30 do
        c.data.tick=tick
        a.globalCooldown=0
        local x,y=a.x,a.y
        Execution._executeMove(a,{target={x=400,y=220},avoidObstacles=true},c)
        assert((a.x-x)^2+(a.y-y)^2<=24^2+0.001,"avoidance exceeded step")
        if (x-400)^2+(y-220)^2 > 0.001 then
            assert(a.globalCooldown>=10.8 and a.globalCooldown<=13.2,"movement timing changed")
        end
        assert((a.x-b.x)^2+(a.y-b.y)^2>=57^2-0.01,"avoidance crossed large unit")
        deviated=deviated or a.y~=220
    end
    assert(deviated and a.x>b.x+57,"failed to avoid large unit: "..a.x..","..a.y.." steps="..tostring(a.avoidSteps))
    assert(b.x==170 and b.y==220 and b.hp==100)
    -- Packed frontlines get a bounded local attempt, never an army-wide detour.
    c=Context.new()
    a=body("blocked",100,273,18,"player")
    c.addUnit(a)
    for i=0,13 do c.addUnit(body("wall"..i,160,21+i*38,21,"enemy")) end
    for tick=1,100 do
        c.data.tick=tick; a.globalCooldown=0
        Execution._executeMove(a,{target={x=400,y=273},avoidObstacles=true},c)
    end
    assert(a.x < 160 and math.abs(a.y-273)<=144,"frontline caused an enormous detour")
    c=Context.new();a=body("free",100,200,18,"player");c.addUnit(a)
    a.stats.battle_speed=20
    Execution._executeMove(a,{target={x=400,y=200},avoidObstacles=true},c)
    assert(a.x==124 and a.y==200 and a.globalCooldown>=5.4 and a.globalCooldown<=6.6)
    local sim=require("src.game.battle.battle_simulation").new(party,{id="empty",actors={}},true)
    local expected=Squads.layout(party)
    for _,layout in ipairs(expected) do
        for i,actor in ipairs(layout.members) do
            assert(sim.context.data.units[actor.id].x==layout.circles[i].x)
            assert(sim.context.data.units[actor.id].y==layout.circles[i].y)
        end
    end
    sim:destroy()
    player.attributes.command=0
    sim=require("src.game.battle.battle_simulation").new(party,{id="empty",actors={}},false)
    assert(#party.squads==0 and sim.context.data.squads[1].order=="charge")
    sim:destroy()
    print("M2 capacity, transfers, world deployment and local avoidance PASS")
end
return Scenario
