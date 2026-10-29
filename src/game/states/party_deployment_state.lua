local Squads = require("src.game.battle.squads")
local GameContext = require("src.game.game_context")
local StateManager = require("src.core.state_manager")
local Deployment = {}

local function view()
    return 30, 110, math.min((love.graphics.getWidth()-340)/600, (love.graphics.getHeight()-150)/546)
end
local function refresh()
    Deployment.layouts, Deployment.leader = Squads.layout(Deployment.party)
    Deployment.selected = math.min(Deployment.selected, #Deployment.layouts)
end
function Deployment.enter()
    Deployment.party = GameContext.data.playerParty
    Deployment.selected, Deployment.drag, Deployment.rosterOffset = 1, nil, 0
    refresh()
    require("src.core.input").init()
end
function Deployment.exit()
    Deployment.party, Deployment.layouts, Deployment.drag = nil, nil, nil
end
function Deployment.keypressed(key)
    if key == "escape" or key == "p" then StateManager.pop(); return true end
    if Squads.capacity(Deployment.party) == 0 then return true end
    if key == "n" then
        if Squads.create(Deployment.party) then Deployment.selected = #Deployment.party.squads end
        refresh()
    elseif key == "delete" then
        Squads.remove(Deployment.party, Deployment.selected)
        refresh()
    elseif key == "tab" then
        Deployment.selected = Deployment.selected % #Deployment.layouts + 1
    elseif (key == "l" or key == "b") and #Deployment.party.squads > 0 then
        local layout = Deployment.layouts[Deployment.selected]
        Squads.place(Deployment.layouts, Deployment.selected, Deployment.leader,
            layout.config.x, layout.config.y, key == "l" and "line" or "box")
    end
    return true
end
function Deployment.mousepressed(x,y,button)
    if button ~= 1 or #Deployment.party.squads == 0 then return end
    local ox,oy,scale = view()
    local rosterX = love.graphics.getWidth()-280
    if x >= rosterX then
        local row = math.floor((y-110)/24)+1+Deployment.rosterOffset
        local actor = Deployment.party.actors[row]
        if actor and y >= 110 and actor ~= Deployment.leader then
            Squads.transfer(Deployment.party,actor.id,Deployment.selected)
            refresh()
        end
        return
    end
    local wx,wy = (x-ox)/scale,(y-oy)/scale
    for i,layout in ipairs(Deployment.layouts) do
        for _,c in ipairs(layout.circles) do
            if (wx-c.x)^2+(wy-c.y)^2 <= c.radius^2 then
                Deployment.selected = i
                Deployment.drag = {x=wx-layout.config.x,y=wy-layout.config.y}
                return
            end
        end
    end
end
function Deployment.update()
    if not Deployment.drag then return end
    local x,y = love.mouse.getPosition()
    local ox,oy,scale = view()
    Squads.place(Deployment.layouts,Deployment.selected,Deployment.leader,
        (x-ox)/scale-Deployment.drag.x,(y-oy)/scale-Deployment.drag.y)
end
function Deployment.mousereleased(x,y,button)
    if button == 1 then Deployment.update(); Deployment.drag = nil end
end
function Deployment.wheelmoved(x,y)
    local rows = math.max(1,math.floor((love.graphics.getHeight()-130)/24))
    Deployment.rosterOffset = math.max(0,math.min(math.max(0,#Deployment.party.actors-rows),Deployment.rosterOffset-y*3))
end
function Deployment.draw()
    local g = love.graphics
    local ox,oy,scale = view()
    g.clear(0.08,0.09,0.12)
    g.setColor(1,1,1)
    local capacity = Squads.capacity(Deployment.party)
    g.print("Party Deployment    Enemy -> RIGHT    Squads: "..#Deployment.party.squads.."/"..capacity,30,20)
    g.print("N: create | Delete: remove | Tab: select | L: line | B: box | P / Esc: close",30,45)
    g.print("Drag formations. Click a roster member to assign them to the selected squad.",30,70)
    g.rectangle("line",ox,oy,600*scale,546*scale)
    if Deployment.leader then
        g.setColor(1,0.8,0.2)
        g.circle("fill",ox+500*scale,oy+273*scale,require("src.ecs.assemblages.battle_unit").actorRadius(Deployment.leader)*scale)
        g.print("Leader",ox+500*scale,oy+273*scale+22)
    end
    for i,layout in ipairs(Deployment.layouts) do
        if i==Deployment.selected then g.setColor(0.3,0.9,1) else g.setColor(0.3,0.6,0.8) end
        for _,c in ipairs(layout.circles) do g.circle("line",ox+c.x*scale,oy+c.y*scale,c.radius*scale) end
        g.print((#Deployment.party.squads==0 and "Fallback" or "Squad "..i).." ("..layout.config.formation..")",
            ox+layout.config.x*scale,oy+layout.config.y*scale)
    end
    local rosterX = g.getWidth()-280
    g.setColor(1,1,1)
    local rows = math.max(1,math.floor((g.getHeight()-130)/24))
    for i=Deployment.rosterOffset+1,math.min(#Deployment.party.actors,Deployment.rosterOffset+rows) do
        local actor = Deployment.party.actors[i]
        local assignment = actor==Deployment.leader and "fixed" or "fallback"
        for j,config in ipairs(Deployment.party.squads) do
            for _,id in ipairs(config.members) do if id==actor.id and actor~=Deployment.leader then assignment="squad "..j end end
        end
        g.print((actor.name or tostring(actor.id)).." - "..assignment,rosterX,110+(i-1-Deployment.rosterOffset)*24)
    end
    if capacity==0 then g.print("No eligible commander: temporary fallback group (read only).",30,85) end
end
return Deployment
