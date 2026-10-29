local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local Context = require("src.game.battle.battle_context")
local Render = require("src.systems.battle.render_system")
local P = require("src.game.battle.projectiles")
local Skills = require("src.data.skills")
local Scenario = {}
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a).." ~= "..tostring(b)) end
function Scenario.run()
    local root=love.filesystem.getSource():gsub("\\","/"):gsub("/tests/unit$","")
    local imageData=love.image.newImageData
    love.image.newImageData=function(path,...)
        if type(path)=="string" and path:match("^presentation%-fixture/") then
            local name=path:gsub("^presentation%-fixture/","")
            local f=assert(io.open(root.."/"..name,"rb"));local bytes=f:read("*a");f:close()
            return imageData(love.filesystem.newFileData(bytes,name))
        end
        return imageData(path,...)
    end
    -- Images load through the same fixture path as the alpha data in this isolated LÖVE test.
    local newImage=love.graphics.newImage
    love.graphics.newImage=function(path,...)
        if type(path)=="string" and path:match("^presentation%-fixture/") then return newImage(love.image.newImageData(path)) end
        return newImage(path,...)
    end
    local world,battle=Ecs.init(),Ecs.startBattle()
    local c=Context.new({width=1200,height=500});c.data.camera=nil
    local cases={
        {"archer",1.3,37,0},{"slinger",1.3,39,0},{"pelas_slinger",1.3,34,2},
        {"ogre",1.46,49,0},{"dragon",1.7,70,0},{"war_dog",1.3,20,0},
    }
    local ok,err=xpcall(function()
        for i,case in ipairs(cases) do
            local actor=Unit.create(world,case[1],"presentation-"..i)
            actor.sprite="presentation-fixture/"..actor.sprite
            if case[1]=="ogre" then actor.heightMultiplier=2.5 end
            local u=BattleUnit.create(battle,actor,100+(i-1)*190,240,"player")
            u.visualX,u.visualY=u.x,u.y;u.facing=i%2==0 and -1 or 1;c.addUnit(u)
            local p=P.launch(u,Skills.arrow,u.x+100,u.y,u,function() return 0.5 end)
            p.presentationTarget=u;c.addProjectile(p)
            local x,y=Render.projectProjectile(p,p.startX,p.startY,p.startZ,nil,0)
            near(x,u.visualX)
            local feet=(u.collisionRadius*2)/3-case[4]*case[2]
            near(y,u.visualY+feet-0.9*case[3]*case[2])
            local _,impactY=Render.projectProjectile(p,u.x,u.y,u.height*0.8,u)
            near(impactY,u.visualY+feet-0.8*case[3]*case[2])
            near(p.startZ,u.height*0.9);near(p.endZ,u.height*0.8)
        end
        local canvas=love.graphics.newCanvas(1200,500)
        love.graphics.push("all");love.graphics.setCanvas(canvas);love.graphics.clear(0.08,0.08,0.08,1)
        local draw=love.graphics.draw
        local count=0
        love.graphics.draw=function(image,x,y,angle,sx,sy,ox,oy)
            count=count+1;local u=c.data.unitList[count];local case=cases[count]
            local w,h=image:getDimensions()
            near(x,u.visualX);near(y,u.visualY+u.collisionRadius*2/3)
            near(sx,case[2]*u.facing);near(sy,case[2]);near(ox,w/2);near(oy,h)
            return draw(image,x,y,angle,sx,sy,ox,oy)
        end
        local drawn,message=pcall(Render.draw,c);love.graphics.draw=draw;assert(drawn,message)
        assert(count==#cases)
        love.graphics.setColor(1,1,1,1)
        love.graphics.print("Original sprite scales, anchors and feet offsets; calibrated launch arrows",20,20)
        for i,u in ipairs(c.data.unitList) do love.graphics.print(cases[i][1],u.x-45,290) end
        -- Actual contact uses the unit struck, regardless of the intended target.
        local p=c.data.projectiles[1];local target=c.data.unitList[2]
        c.addVfx({type="projectile_contact",x=target.x,y=target.y,z=target.height*0.8,
            projectile=p,contactUnit=target,time=0,duration=0.12})
        local _,expectedY=Render.projectProjectile(p,target.x,target.y,target.height*0.8,target)
        local circle=love.graphics.circle;local contacts=0
        love.graphics.circle=function(mode,x,y,r,...)
            if r==3 and mode=="line" then contacts=contacts+1;near(y,expectedY) end
            return circle(mode,x,y,r,...)
        end
        c.data.bounds=nil
        drawn,message=pcall(Render.draw,c);love.graphics.circle=circle;assert(drawn,message);assert(contacts==1)
        love.graphics.setCanvas();love.graphics.pop()
        local output=os.getenv("GEHERRA_RENDER_PREVIEW")
        if output then local f=assert(io.open(output,"wb"));f:write(canvas:newImageData():encode("png"):getString());f:close() end
        -- Original interpolation rates are retained for both actors and projectile screen positions.
        local u=c.data.unitList[1]
        u.visualX,u.visualY=u.x-20,u.y+10
        p.presentationInitialized=true;p.visualX,p.visualY=50,150
        local targetX,targetY=Render.projectProjectile(p)
        -- Render.update first interpolates units at 10/s; use that expected pose for projectile calibration.
        u.visualX,u.visualY=u.x-18,u.y+9
        targetX,targetY=Render.projectProjectile(p)
        u.visualX,u.visualY=u.x-20,u.y+10
        local px,py,pz=p.x,p.y,p.z
        Render.update(0.01,c)
        near(u.visualX,u.x-18);near(u.visualY,u.y+9)
        near(p.visualX,50+(targetX-50)*0.15);near(p.visualY,150+(targetY-150)*0.15)
        near(p.x,px);near(p.y,py);near(p.z,pz)
        -- Endpoint mapping accounts for the target's interpolation displacement too.
        target.visualX,target.visualY=target.x-12,target.y+8
        local x,y=Render.projectProjectile(p,target.x,target.y,target.height*0.8,target)
        near(x,target.visualX)
        near(y,target.visualY+12-0.8*39*1.3)
    end,debug.traceback)
    love.image.newImageData,love.graphics.newImage=imageData,newImage
    battle:clear()
    assert(ok,err)
    print("Projectile presentation, original actor anchors/scales and interpolation PASS")
end
return Scenario
