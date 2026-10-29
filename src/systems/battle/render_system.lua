-- systems/battle/render_system.lua
-- Handles visual updates (lerping) and world-space drawing.

local RenderSystem = {}
local DebugMode = require("src.debug.mode")
local CombatSystem = require("src.systems.battle.combat_system")
local RangeUtils = require("src.systems.battle.range_utils")

local SPRITE_FEET_OFFSET_DIAMETER_RATIO = 1 / 3
local UNIT_HEALTH_BAR_WIDTH = 40
local UNIT_BASE_VISUAL_SCALE = 1.3
local UNIT_VISUAL_SCALE_PER_SIZE = 0.08

local imageCache = {}
local projectileSpriteBounds = {}

local flashShader = love.graphics.newShader[[
    extern vec3 flashColor;
    extern number flashAmount;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 pixel = Texel(texture, texture_coords);
        vec3 flashed = mix(pixel.rgb, flashColor, flashAmount);
        return vec4(flashed, pixel.a) * color;
    }
]]

local fireballHeatShader = love.graphics.newShader[[
    extern number time;
    extern number pulse;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = texture_coords - vec2(0.5, 0.5);
        number r = length(uv);
        number wobble = sin((uv.y * 28.0) + (time * 14.0)) * 0.02 * pulse;
        number core = smoothstep(0.40 + wobble, 0.05 + wobble, r);
        number hazeRing = smoothstep(0.55, 0.25, r) - smoothstep(0.25, 0.1, r);
        vec3 col = mix(vec3(1.0, 0.35, 0.08), vec3(1.0, 0.85, 0.4), core);
        number alpha = clamp(core * 0.9 + hazeRing * 0.35, 0.0, 1.0);
        return vec4(col, alpha) * color;
    }
]]

local function getImage(path)
    if not path then return nil end
    if imageCache[path] == nil then
        local status, img = pcall(love.graphics.newImage, path)
        if status then
            imageCache[path] = img
        else
            imageCache[path] = false
        end
    end
    return imageCache[path] or nil
end

local function getBurnStatus(unit)
    if not unit or not unit.statusEffects then return nil end
    return unit.statusEffects.burn
end

local function getBurnIntensity(unit)
    local burn = getBurnStatus(unit)
    if not burn then return 0 end

    if type(burn) == "number" then
        return math.max(0, math.min(1, burn))
    end

    if type(burn) == "table" then
        local remaining = burn.remaining or burn.duration or 0
        local duration = burn.duration or 1
        if duration <= 0 then return 0 end
        return math.max(0, math.min(1, remaining / duration))
    end

    if burn == true then return 1 end
    return 0
end

-- Generic status intensity (0..1) for any keyed runtime status (freeze, etc.)
local function getStatusIntensity(unit, statusId)
    if not unit or not unit.statusEffects then return 0 end
    local status = unit.statusEffects[statusId]
    if not status then return 0 end

    if type(status) == "number" then
        return math.max(0, math.min(1, status))
    end

    if type(status) == "table" then
        local remaining = status.remaining or status.duration or 0
        local duration = status.duration or 1
        if duration <= 0 then return 0 end
        return math.max(0, math.min(1, remaining / duration))
    end

    if status == true then return 1 end
    return 0
end

local function getActorRenderScale(actor)
    local size = (actor and actor.size) or 3
    local scale = UNIT_BASE_VISUAL_SCALE * (1 + math.min(size - 3, 0) * 0.1)
        + math.max(size - 3, 0) * UNIT_VISUAL_SCALE_PER_SIZE
    return math.max(0.13, scale)
end

-- Match projectile Z to the existing sprite draw; never change the actor's anchor or scale.
local function projectileFrame(unit)
    local sprite = unit.actor and unit.actor.sprite
    local bounds = sprite and projectileSpriteBounds[sprite]
    if sprite and bounds == nil then
        local ok, data = pcall(love.image.newImageData, sprite)
        bounds = false
        if ok then
            local w, h = data:getDimensions()
            local left, top, right, bottom = w, h, 0, 0
            for y=0,h-1 do for x=0,w-1 do
                local _,_,_,alpha = data:getPixel(x,y)
                if alpha > 0 then
                    left, top = math.min(left,x), math.min(top,y)
                    right, bottom = math.max(right,x+1), math.max(bottom,y+1)
                end
            end end
            if bottom > top then bounds = {w=w,h=h,left=left,top=top,right=right,bottom=bottom} end
        end
        projectileSpriteBounds[sprite] = bounds
    end
    local dx = (unit.visualX or unit.x)-unit.x
    local dy = (unit.visualY or unit.y)-unit.y
    if not bounds then return dx,dy,1 end
    local scale = getActorRenderScale(unit.actor)
    local height = require("src.game.battle.projectiles").height(unit)
    return dx + ((bounds.left+bounds.right)/2-bounds.w/2)*scale*(unit.facing or 1),
        dy + (unit.collisionRadius or 18)*2*SPRITE_FEET_OFFSET_DIAMETER_RATIO + (bounds.bottom-bounds.h)*scale,
        (bounds.bottom-bounds.top)*scale/height
end

function RenderSystem.projectProjectile(proj, x, y, z, contactUnit, progress)
    x,y,z = x or proj.x,y or proj.y,z or proj.z or 0
    local dx,dy,scale = projectileFrame(contactUnit or proj.attackerUnit)
    if not contactUnit then
        -- shortcut: flight blends endpoint sprite frames; use a shared scene mapping if mixed-scale interception needs refinement.
        local ex,ey,es = projectileFrame(proj.presentationTarget or proj.attackerUnit)
        local t = math.max(0,math.min(1,progress or proj.progress or 0))
        dx,dy,scale = dx+(ex-dx)*t,dy+(ey-dy)*t,scale+(es-scale)*t
    end
    return x+dx,y+dy-z*scale,scale
end

local function initializeProjectileProjection(proj)
    if proj.presentationInitialized then return end
    proj.visualX,proj.visualY = RenderSystem.projectProjectile(proj,
        proj.startX,proj.startY,proj.startZ,nil,0)
    proj.presentationInitialized = true
end

function RenderSystem.update(dt, context)
    local units = context.data.unitList
    local LERP_SPEED = 10.0

    for _, unit in ipairs(units) do
        local targetX = unit.x
        local targetY = unit.y

        local dx = targetX - unit.visualX
        local dy = targetY - unit.visualY

        if math.abs(dx) < 1 and math.abs(dy) < 1 then
            unit.visualX = targetX
            unit.visualY = targetY
        else
            unit.visualX = unit.visualX + dx * LERP_SPEED * dt
            unit.visualY = unit.visualY + dy * LERP_SPEED * dt
        end

        if unit.visualEffects then
            if unit.visualEffects.shakeTime > 0 then
                unit.visualEffects.shakeTime = math.max(0, unit.visualEffects.shakeTime - dt)
            end
            if unit.visualEffects.flashTime > 0 then
                unit.visualEffects.flashTime = math.max(0, unit.visualEffects.flashTime - dt)
            end
            if unit.visualEffects.lungeTime > 0 then
                unit.visualEffects.lungeTime = math.max(0, unit.visualEffects.lungeTime - dt)
            end
        end
    end

    local projectiles = context.data.projectiles
    if projectiles then
        local PROJ_LERP = 15.0
        for _, proj in ipairs(projectiles) do
            initializeProjectileProjection(proj)
            local projectedX,projectedY = RenderSystem.projectProjectile(proj)
            local dx = projectedX - proj.visualX
            local dy = projectedY - proj.visualY
            proj.visualX = proj.visualX + dx * PROJ_LERP * dt
            proj.visualY = proj.visualY + dy * PROJ_LERP * dt

            if proj.trailParticles then
                for i = #proj.trailParticles, 1, -1 do
                    local p = proj.trailParticles[i]
                    p.life = p.life - dt
                    if p.life <= 0 then
                        table.remove(proj.trailParticles, i)
                    else
                        p.x = p.x + p.vx * dt
                        p.y = p.y + p.vy * dt
                        if p.kind == "smoke" then
                            p.vx = p.vx * 0.97
                            p.vy = p.vy * 0.98
                        else
                            p.vx = p.vx * 0.96
                            p.vy = p.vy * 0.92
                        end
                    end
                end
            end
        end
    end

    local vfx = context.data.vfx
    if vfx then
        for i = #vfx, 1, -1 do
            local effect = vfx[i]
            effect.time = (effect.time or 0) + dt

            if effect.type == "fire_explosion" and effect.sparks then
                for j = #effect.sparks, 1, -1 do
                    local spark = effect.sparks[j]
                    spark.life = spark.life - dt
                    if spark.life <= 0 then
                        table.remove(effect.sparks, j)
                    else
                        spark.x = (spark.x or effect.x) + spark.vx * dt
                        spark.y = (spark.y or effect.y) + spark.vy * dt
                        spark.vx = spark.vx * 0.9
                        spark.vy = spark.vy + (220 * dt)
                    end
                end
            end

            if effect.type == "fire_explosion" and effect.smoke then
                for j = #effect.smoke, 1, -1 do
                    local puff = effect.smoke[j]
                    puff.life = puff.life - dt
                    if puff.life <= 0 then
                        table.remove(effect.smoke, j)
                    else
                        puff.x = (puff.x or effect.x) + puff.vx * dt
                        puff.y = (puff.y or effect.y) + puff.vy * dt
                        puff.vx = puff.vx * 0.94
                        puff.vy = puff.vy - (14 * dt)
                    end
                end
            end

            if effect.time >= (effect.duration or 0.4) then
                table.remove(vfx, i)
            end
        end
    end

    local camera = context.data.camera
    local selectedUnitId = context.data.selectedUnitId
    local unit = context.data.units[selectedUnitId]

    if camera and unit then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()

        local targetX = unit.visualX - screenW / 2
        local targetY = unit.visualY - screenH / 2

        local camSpeed = 5.0
        camera.x = camera.x + (targetX - camera.x) * camSpeed * dt
        camera.y = camera.y + (targetY - camera.y) * camSpeed * dt
    end

    local texts = context.data.floatingTexts
    if texts then
        for i = #texts, 1, -1 do
            local txt = texts[i]
            txt.time = txt.time + dt
            txt.offsetY = txt.offsetY - (30 * dt)

            if txt.time >= txt.duration then
                table.remove(texts, i)
            end
        end
    end
end

function RenderSystem.drawMoraleDebug(context)
    if not DebugMode.enabled then return end
    local Morale = require("src.game.battle.morale")
    local powers = Morale.powers(context)
    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() + 2
    local width, height = 340, lineHeight * 7 + 16
    local x, y = love.graphics.getWidth() - width - 10, love.graphics.getHeight() - height - 10
    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, width, height)
    for index, side in ipairs({{team="player", label="Player"}, {team="enemy", label="Enemy"}}) do
        local party = context.data.battleParties and context.data.battleParties[side.team]
        local members = party and party.members or {}
        local average, eligible = Morale.average(members)
        local fighting, fleeing, escaped = 0, 0, 0
        for _, unit in ipairs(members) do
            if unit.escaped then escaped = escaped + 1
            elseif unit.hp > 0 then
                if unit.fleeing then fleeing = fleeing + 1 else fighting = fighting + 1 end
            end
        end
        local rowY = y + 8 + (index - 1) * 3 * lineHeight
        local value = eligible > 0 and string.format("%.1f", average) or "N/A"
        love.graphics.setColor(side.team == "player" and 0.5 or 1, 0.8, side.team == "player" and 1 or 0.5, 1)
        love.graphics.print(string.format("%s | Morale %s | Power %.1f%s",
            side.label, value, powers[side.team] or 0, party and party.routed and " | ROUTED" or ""),
            x + 10, rowY)
        love.graphics.setColor(1, 1, 1, 1)
        local threat = Morale.threat(powers, side.team)
        local multiplier = threat == math.huge and "infinite" or string.format("%.2fx", threat)
        love.graphics.print(string.format("Fight %d  Flee %d  Esc %d | Threat %s",
            fighting, fleeing, escaped, multiplier), x + 10, rowY + lineHeight)
    end
    local scaleWidth = 100 * (context.data.camera and context.data.camera.zoom or 1)
    local scaleX, scaleY = x + 10, y + 8 + 6 * lineHeight
    love.graphics.setLineWidth(2)
    love.graphics.line(scaleX, scaleY, scaleX + scaleWidth, scaleY)
    love.graphics.line(scaleX, scaleY - 4, scaleX, scaleY + 4)
    love.graphics.line(scaleX + scaleWidth, scaleY - 4, scaleX + scaleWidth, scaleY + 4)
    love.graphics.print("100 units", scaleX + scaleWidth + 8, scaleY - font:getHeight() / 2)
    love.graphics.pop()
end

function RenderSystem.draw(context)
    local camera = context.data.camera

    love.graphics.push()
    if camera then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()
        local zoom = camera.zoom or 1.0

        love.graphics.translate(screenW / 2, screenH / 2)
        love.graphics.scale(zoom)
        love.graphics.translate(-screenW / 2, -screenH / 2)
        love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))
    end

    local bounds = context.data.bounds
    local debug = context.data.debug or {}
    local showCollisionCircles = DebugMode.enabled
        and debug.showCollisionCircles ~= false
    if bounds then
        love.graphics.setColor(0.16, 0.16, 0.16, 0.85)
        love.graphics.rectangle("fill", 0, 0, bounds.width, bounds.height)
        love.graphics.setColor(0.25, 0.25, 0.25, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", 0, 0, bounds.width, bounds.height)
    end

    local player = context.data.playerUnit
    if DebugMode.enabled and player and player.hp > 0 then
        local skillId = player.skillList and player.skillList[context.data.selectedSkillIndex]
        local skill = skillId and CombatSystem.getEffectiveSkill(player, skillId)
        if skill and skill.range then
            -- Target collision radii extend attack reach beyond this ring to their edges.
            local range = RangeUtils.effectiveSkillRange(player, nil, skill)
            love.graphics.setColor(0.2, 0.8, 1, 0.8)
            love.graphics.setLineWidth(1.5)
            love.graphics.circle("line", player.visualX, player.visualY, range)
            love.graphics.setLineWidth(1)
        end
    end

    local sortedUnits = {}
    for _, unit in ipairs(context.data.unitList) do
        if unit.hp > 0 then
            table.insert(sortedUnits, unit)
        end
    end

    table.sort(sortedUnits, function(a, b)
        local ay = a.visualY or a.y or 0
        local by = b.visualY or b.y or 0
        if ay == by then
            return (a.visualX or a.x or 0) < (b.visualX or b.x or 0)
        end
        return ay < by
    end)

    for _, unit in ipairs(sortedUnits) do
        local sprite = getImage(unit.actor.sprite)
        local drawX, drawY = unit.visualX, unit.visualY
        local burnIntensity = getBurnIntensity(unit)
        local freezeIntensity = getStatusIntensity(unit, "freeze")
        local paralyzeIntensity = getStatusIntensity(unit, "paralyze")
        local collisionRadius = unit.collisionRadius or 18
        local renderScale = getActorRenderScale(unit.actor)

            if unit.visualEffects and unit.visualEffects.shakeTime > 0 then
                local magnitude = 3 * (unit.visualEffects.shakeTime * 4)
                drawX = drawX + (love.math.random() - 0.5) * magnitude
                drawY = drawY + (love.math.random() - 0.5) * magnitude
            end

            if unit.visualEffects and unit.visualEffects.lungeTime > 0 then
                local p = 1.0 - (unit.visualEffects.lungeTime / unit.visualEffects.lungeDuration)
                local offset = math.sin(p * math.pi) * (collisionRadius * renderScale * 0.5)
                drawX = drawX + unit.visualEffects.lungeX * offset
                drawY = drawY + unit.visualEffects.lungeY * offset
            end

            if showCollisionCircles then
                if unit.team == "player" then
                    love.graphics.setColor(0.3, 0.95, 0.3, 0.9)
                elseif unit.team == "enemy" then
                    love.graphics.setColor(0.95, 0.35, 0.35, 0.9)
                else
                    love.graphics.setColor(0.95, 0.95, 0.35, 0.9)
                end
                love.graphics.setLineWidth(1.5)
                love.graphics.circle("line", drawX, drawY, collisionRadius)
                love.graphics.circle("fill", drawX, drawY, 1.8)
                love.graphics.setLineWidth(1)
            end

            if sprite then
                love.graphics.setColor(1, 1, 1, 1)

                if unit.visualEffects and unit.visualEffects.flashTime > 0 then
                    local baseIntensity = unit.visualEffects.flashIntensity or 0.7
                    local duration = unit.visualEffects.flashDuration or 1.0
                    local fade = math.min(1, math.max(0, unit.visualEffects.flashTime / duration))
                    local intensity = baseIntensity * fade

                    flashShader:send("flashColor", unit.visualEffects.flashColor)
                    flashShader:send("flashAmount", intensity)
                    love.graphics.setShader(flashShader)
                end

                local w, h = sprite:getDimensions()
                local scale = renderScale
                local spriteFeetOffsetY = (collisionRadius * 2) * SPRITE_FEET_OFFSET_DIAMETER_RATIO
                love.graphics.draw(sprite, drawX, drawY + spriteFeetOffsetY, 0, scale * (unit.facing or 1), scale, w / 2, h)

                love.graphics.setShader()
            else
                if unit.team == "player" then
                    love.graphics.setColor(0.2, 0.8, 0.2, 1)
                elseif unit.team == "enemy" then
                    love.graphics.setColor(0.8, 0.2, 0.2, 1)
                else
                    love.graphics.setColor(0.8, 0.8, 0.2, 1)
                end
                love.graphics.circle("fill", drawX, drawY, collisionRadius * renderScale)
            end

            if burnIntensity > 0 then
                local effectRadius = collisionRadius * renderScale
                local pulse = 0.65 + 0.35 * math.sin(love.timer.getTime() * 18)
                fireballHeatShader:send("time", love.timer.getTime())
                fireballHeatShader:send("pulse", pulse)

                love.graphics.setShader(fireballHeatShader)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, 0.45 * burnIntensity)
                love.graphics.circle("fill", drawX, drawY - effectRadius * 0.35, effectRadius * (1.2 + 0.2 * pulse))
                love.graphics.setShader()

                love.graphics.setColor(1, 0.5, 0.15, 0.35 * burnIntensity)
                love.graphics.circle("line", drawX, drawY - effectRadius * 0.35, effectRadius * (1.35 + 0.2 * pulse))
                love.graphics.setBlendMode("alpha")
            end

            if freezeIntensity > 0 then
                local effectRadius = collisionRadius * renderScale
                local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 10)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(0.45, 0.7, 1, 0.4 * freezeIntensity)
                love.graphics.circle("fill", drawX, drawY - effectRadius * 0.35, effectRadius * (1.15 + 0.15 * pulse))
                love.graphics.setColor(0.7, 0.9, 1, 0.4 * freezeIntensity)
                love.graphics.circle("line", drawX, drawY - effectRadius * 0.35, effectRadius * (1.3 + 0.15 * pulse))
                love.graphics.setBlendMode("alpha")
            end

            if paralyzeIntensity > 0 then
                local effectRadius = collisionRadius * renderScale
                local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 26)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 0.9, 0.35, 0.4 * paralyzeIntensity)
                love.graphics.circle("line", drawX, drawY - effectRadius * 0.35, effectRadius * (1.2 + 0.2 * pulse))
                love.graphics.setColor(0.6, 0.85, 1, 0.3 * paralyzeIntensity)
                love.graphics.circle("fill", drawX, drawY - effectRadius * 0.35, effectRadius * (0.9 + 0.2 * pulse))
                love.graphics.setBlendMode("alpha")
            end

            local barWidth = UNIT_HEALTH_BAR_WIDTH
            local barHeight = 4
            local barX = drawX - barWidth / 2
            local barY = drawY + collisionRadius * renderScale - 4

            love.graphics.setColor(0.3, 0, 0, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

            local hpPercent = math.max(0, unit.hp / math.max(1, unit.maxHp))
            love.graphics.setColor(0.2, 0.8, 0.2, 1)
            love.graphics.rectangle("fill", barX, barY, barWidth * hpPercent, barHeight)
    end

    local projectiles = context.data.projectiles
    if projectiles then
        for _, proj in ipairs(projectiles) do
            initializeProjectileProjection(proj)
            local projectedX,projectedY,heightScale = RenderSystem.projectProjectile(proj)
            local trailDX,trailDY = projectedX-proj.x,projectedY-(proj.y-(proj.z or 0))
            if proj.trailParticles and #proj.trailParticles > 0 then
                for _, p in ipairs(proj.trailParticles) do
                    local lifeRatio = math.max(0, math.min(1, p.life / p.duration))
                    local size = p.size * (0.4 + 0.6 * lifeRatio)
                    if p.kind == "smoke" then
                        love.graphics.setBlendMode("alpha")
                        love.graphics.setColor(0.2, 0.2, 0.2, 0.22 * lifeRatio)
                        love.graphics.circle("fill", p.x+trailDX, p.y+trailDY, size)
                    else
                        love.graphics.setBlendMode("add")
                        love.graphics.setColor(1, 0.5 + 0.4 * lifeRatio, 0.15, 0.55 * lifeRatio)
                        love.graphics.circle("fill", p.x+trailDX, p.y+trailDY, size)
                    end
                end
                love.graphics.setBlendMode("alpha")
            end

            local sprite = getImage(proj.sprite)
            if proj.style == "fireball" then
                local pulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 22)
                fireballHeatShader:send("time", love.timer.getTime())
                fireballHeatShader:send("pulse", pulse)
                love.graphics.setShader(fireballHeatShader)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 13)
                love.graphics.setShader()

                love.graphics.setColor(1, 0.95, 0.8, 0.95)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 3.5)

                love.graphics.setColor(1, 0.5, 0.15, 0.26)
                love.graphics.circle("line", proj.visualX, proj.visualY, 17)
                love.graphics.setBlendMode("alpha")
            elseif proj.style == "frostbolt" then
                local pulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 18)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(0.45, 0.8, 1, 0.35)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 13 * pulse)
                love.graphics.setColor(0.75, 0.95, 1, 0.9)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 6 * pulse)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 2.5)
                love.graphics.setColor(0.6, 0.85, 1, 0.3)
                love.graphics.circle("line", proj.visualX, proj.visualY, 16)
                love.graphics.setBlendMode("alpha")
            elseif proj.style == "lightning" then
                local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 32)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 0.95, 0.5, 0.45 * pulse)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 15 * pulse)
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 7 * pulse)
                love.graphics.setColor(0.7, 0.85, 1, 0.4)
                love.graphics.circle("line", proj.visualX, proj.visualY, 18)
                love.graphics.setBlendMode("alpha")
            elseif proj.style == "arrow" then
                local dz = ((proj.endZ-proj.startZ)+4*proj.arc*(1-2*proj.progress))/proj.distance*heightScale
                love.graphics.setColor(0.7, 0.6, 0.4, 1)
                love.graphics.line(proj.visualX-proj.nx*10, proj.visualY-(proj.ny-dz)*10,
                    proj.visualX, proj.visualY)
            elseif proj.style == "sling_stone" then
                love.graphics.setColor(0.38, 0.34, 0.28, 1)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 3)
            elseif sprite then
                local dx = proj.nx * proj.distance
                local dy_linear = proj.ny * proj.distance
                local dy_arc = (-(proj.endZ-proj.startZ)-4*proj.arc*(1-2*proj.progress))*heightScale
                local target_angle = math.atan2(dy_linear + dy_arc, dx)

                local horizontal_angle = 0
                if dx < 0 then
                    horizontal_angle = math.pi
                end

                local rotation = (horizontal_angle + target_angle) / 2

                local sx = 1
                if dx < 0 then
                    sx = -1
                    rotation = math.pi - rotation
                end

                local drawX = proj.visualX
                local drawY = proj.visualY

                local w, h = sprite:getDimensions()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(sprite, drawX, drawY, rotation, sx, 1, w / 2, h / 2)
            else
                local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 24)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 0.65, 0.2, 0.28)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 14 * pulse)
                love.graphics.setColor(1, 0.85, 0.4, 0.75)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 8 * pulse)
                love.graphics.setColor(1, 0.95, 0.75, 1)
                love.graphics.circle("fill", proj.visualX, proj.visualY, 3.5)
                love.graphics.setBlendMode("alpha")
            end
        end
    end

    local vfx = context.data.vfx
    if vfx then
        for _, effect in ipairs(vfx) do
            local effectX,effectY = effect.x,effect.y
            if effect.projectile then
                effectX,effectY = RenderSystem.projectProjectile(effect.projectile,effect.x,effect.y,
                    effect.z,effect.contactUnit)
            end
            local offsetX,offsetY = effectX-effect.x,effectY-effect.y
            if effect.type == "projectile_contact" then
                love.graphics.setColor(1,0.85,0.4,1-effect.time/effect.duration)
                love.graphics.circle("line",effectX,effectY,3)
            elseif effect.type == "fire_explosion" then
                local t = math.max(0, math.min(1, effect.time / effect.duration))
                local coreRadius = (effect.maxRadius or 44) * t
                local ringRadius = (effect.ringRadius or 12) + (effect.maxRadius or 44) * t
                local fade = 1.0 - t

                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 0.45, 0.1, 0.4 * fade)
                love.graphics.circle("fill", effectX, effectY, coreRadius)

                love.graphics.setColor(1, 0.75, 0.2, 0.65 * fade)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", effectX, effectY, ringRadius)

                if effect.sparks then
                    for _, spark in ipairs(effect.sparks) do
                        local sx = (spark.x or effect.x)+offsetX
                        local sy = (spark.y or effect.y)+offsetY
                        local sparkFade = math.max(0, math.min(1, spark.life / 0.36))
                        love.graphics.setColor(1, 0.85, 0.25, 0.9 * sparkFade)
                        love.graphics.circle("fill", sx, sy, (spark.size or 3) * sparkFade)
                    end
                end

                if effect.smoke then
                    love.graphics.setBlendMode("alpha")
                    for _, puff in ipairs(effect.smoke) do
                        local px = (puff.x or effect.x)+offsetX
                        local py = (puff.y or effect.y)+offsetY
                        local puffFade = math.max(0, math.min(1, puff.life / 0.7))
                        love.graphics.setColor(0.17, 0.17, 0.17, 0.22 * puffFade)
                        love.graphics.circle("fill", px, py, (puff.size or 10) * (1.2 - puffFade * 0.2))
                    end
                end

                love.graphics.setBlendMode("alpha")
                love.graphics.setLineWidth(1)
            end
        end
    end

    local texts = context.data.floatingTexts
    if texts then
        for _, txt in ipairs(texts) do
            local alpha = 1.0 - (txt.time / txt.duration)
            love.graphics.setColor(txt.color[1], txt.color[2], txt.color[3], alpha)
            if txt.centered then
                local font = love.graphics.getFont()
                local textWidth = font:getWidth(txt.text) * 0.9
                love.graphics.print(txt.text, txt.x - textWidth / 2, txt.y + txt.offsetY - 40, 0, 0.7, 0.7)
            else
                love.graphics.print(txt.text, txt.x - 5, txt.y + txt.offsetY - 20, 0, 0.7, 0.7)
            end
        end
    end

    love.graphics.pop()
end

return RenderSystem
