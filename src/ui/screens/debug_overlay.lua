-- World-map debug menus. Inspectors are live; menus/editors pause world input.
local Mode = require("src.debug.mode")
local Tools = require("src.debug.campaign_tools")
local Inspector = require("src.debug.inspector")
local Button = require("src.ui.widgets.button")

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new()
    return setmetatable({scroll = 0}, Overlay)
end

function Overlay:close()
    self.view, self.target, self.form, self.focus, self.message = nil, nil, nil, nil, nil
    self.scroll = 0
end

function Overlay:blocksWorldInput()
    return Mode.enabled and self.view ~= nil and self.view ~= "inspect"
end

function Overlay:inspect(kind, id)
    self.view, self.target, self.scroll, self.message = "inspect", {kind = kind, id = id}, 0, nil
    self.focus = nil
end

function Overlay:edit(map, partyId)
    self:inspect("party", partyId)
    local leader, err, party = Tools.editableLeader(map, partyId)
    if not leader then self.message = err; return end
    local state = leader.npc_goals
    local goal = state and state.goals[1]
    local roam = goal and goal.roam or {}
    local origin = roam.originLocationId and Tools.resolve(map, "location", roam.originLocationId)
    self.form = {
        type = goal and goal.type or "acquire_gold",
        amount = tostring(goal and goal.amount or (party.treasury + 100)),
        priority = tostring(goal and goal.priority or 0),
        destinationLocationId = goal and goal.destinationLocationId,
        raid = state and state.capabilities.raid == true or not state,
        travel = state and state.capabilities.travel == true or not state,
        roam = state and state.capabilities.roam == true or false,
        originX = tostring(roam.originX or (origin and origin.x) or party.x),
        originY = tostring(roam.originY or (origin and origin.y) or party.y),
        radius = tostring(roam.radius or 300),
        durationSeconds = tostring(roam.durationSeconds or "")
    }
    self.leaderId, self.view = leader.id, "editor"
end

function Overlay:rows(map)
    local rows = {}
    local function text(value) rows[#rows + 1] = {kind = "text", text = value} end
    local function button(value, action, key)
        rows[#rows + 1] = {kind = "button", text = value, action = action, key = key}
    end
    local function field(label, key)
        text(label)
        rows[#rows + 1] = {kind = "field", key = key, text = self.form[key]}
    end
    if self.message then text(self.message) end
    if self.view == "menu" then
        for _, hit in ipairs(self.hits) do
            local kind, id = hit.kind, hit.id
            text((hit.name or "Unnamed") .. " [" .. tostring(id) .. "]")
            button("Inspect " .. kind, function() self:inspect(kind, id) end)
            if kind == "party" then
                button("Configure leader goal", function() self:edit(map, id) end)
            end
        end
    elseif self.view == "inspect" then
        local target = Tools.resolve(map, self.target.kind, self.target.id)
        if target and self.target.kind == "party" then
            button("Configure leader goal", function() self:edit(map, self.target.id) end)
        elseif target then
            for _, party in ipairs(target.stationedParties or {}) do
                local id = party.id
                if Tools.resolve(map, "party", id) then
                    button("Inspect stationed party: " .. (party.name or tostring(id)), function() self:inspect("party", id) end)
                end
            end
        end
        for _, line in ipairs(Inspector.lines(map, self.target.kind, self.target.id)) do text(line) end
    elseif self.view == "editor" then
        text("Replace this leader's goals with one goal. Applying also stops its current activity; encounter and retry rules still apply.")
        button((self.form.type == "acquire_gold" and "[Selected] " or "") .. "Acquire Gold", function()
            self.form.type, self.focus = "acquire_gold", nil
        end)
        button((self.form.type == "reach_location" and "[Selected] " or "") .. "Reach Location", function()
            self.form.type, self.focus = "reach_location", nil
        end)
        if self.form.type == "acquire_gold" then
            field("Party treasury target", "amount")
            button((self.form.roam and "[x] " or "[ ] ") .. "Roam capability", function() self.form.roam = not self.form.roam end)
            if self.form.roam then
                field("Roam origin X", "originX")
                field("Roam origin Y", "originY")
                field("Roam radius", "radius")
                field("Roam duration in world seconds (blank: unlimited)", "durationSeconds")
            end
        else
            local destination = Tools.resolve(map, "location", self.form.destinationLocationId)
            button("Destination: " .. (destination and destination.name or "Choose location..."), function()
                self.view, self.scroll, self.focus = "destinations", 0, nil
            end)
        end
        field("Priority (higher is preferred)", "priority")
        button((self.form.raid and "[x] " or "[ ] ") .. "Raid capability", function() self.form.raid = not self.form.raid end)
        button((self.form.travel and "[x] " or "[ ] ") .. "Travel capability", function() self.form.travel = not self.form.travel end)
        text(self.form.type == "acquire_gold"
            and "Raid requires a hostile traveling party. Enable Roam to seek visible targets within the configured area."
            or "Travel requires a reachable walkable route. The goal waits if travel cannot start.")
        button("Apply - replace leader goals", function()
            local ok, message = Tools.configureGoal(map, self.target.id, self.leaderId, self.form)
            if ok then self.view, self.scroll, self.focus = "inspect", 0, nil end
            self.scroll = 0
            self.message = message
        end, "apply")
        button("Cancel", function() self:inspect(self.target.kind, self.target.id) end)
    elseif self.view == "destinations" then
        button("Back to goal editor", function() self.view, self.scroll = "editor", 0 end)
        text("Choose a destination on the current map:")
        for _, location in ipairs(Tools.locations(map)) do
            local id = location.id
            button(location.name .. " [" .. tostring(id) .. "]", function()
                self.form.destinationLocationId = id
                self.view, self.scroll = "editor", 0
            end)
        end
    end
    return rows
end

function Overlay:layout(map)
    self.font = self.font or love.graphics.newFont(14)
    local sw, sh = love.graphics.getDimensions()
    local w = math.min(self.view == "menu" and 350 or 470, sw - 24)
    local rows, total = self:rows(map), 0
    for _, row in ipairs(rows) do
        local _, wrapped = self.font:getWrap(row.text, w - 36)
        row.height = row.kind == "text" and math.max(20, #wrapped * 18 + 4)
            or math.max(34, #wrapped * 18 + 12)
        total = total + row.height + 6
    end
    local h = math.min(total + 78, sh - 96)
    h = math.max(100, h)
    local x, y = sw - w - 12, 72
    if self.view == "menu" then
        x = math.max(8, math.min(self.menuX, sw - w - 8))
        y = math.max(8, math.min(self.menuY, sh - h - 8))
    end
    self.bounds = {x = x, y = y, w = w, h = h}
    self.content = {x = x + 12, y = y + 42, w = w - 24, h = h - 72}
    self.maxScroll = math.max(0, total - self.content.h)
    self.scroll = math.max(0, math.min(self.scroll, self.maxScroll))
    local rowY = self.content.y - self.scroll
    for _, row in ipairs(rows) do
        row.x, row.y, row.w, row.h = self.content.x, rowY, self.content.w, row.height
        rowY = rowY + row.height + 6
    end
    self.controls = rows
end

local function inside(x, y, box)
    return box and x >= box.x and y >= box.y and x <= box.x + box.w and y <= box.y + box.h
end

function Overlay:mousepressed(map, camera, x, y, button)
    if not Mode.enabled then return false end
    if self.view then
        self:layout(map)
        local b = self.bounds
        if inside(x, y, b) then
            if button == 1 then
                if x >= b.x + b.w - 40 and y < b.y + 38 then self:close(); return true end
                if inside(x, y, self.content) then
                    for _, row in ipairs(self.controls) do
                        if inside(x, y, row) then
                            if row.kind == "button" then self.focus = nil; row.action()
                            elseif row.kind == "field" then self.focus, self.selectAll = row.key, true end
                            break
                        end
                    end
                end
            end
            return true
        end
        if self.view == "editor" or self.view == "destinations" then return true end
        if self.view == "menu" then self:close() end
    end
    if button == 2 then
        local hits = Tools.hitTest(map, camera, x, y)
        if #hits > 0 then
            self:close()
            self.view, self.hits, self.menuX, self.menuY = "menu", hits, x, y
        end
        return true
    end
    return false
end

function Overlay:keypressed(key)
    if not Mode.enabled or not self.view then return false end
    if key == "escape" then self:close(); return true end
    if self.view == "editor" then
        if key == "tab" then
            local fields = self.form.type == "acquire_gold" and {"amount"} or {}
            if self.form.type == "acquire_gold" and self.form.roam then
                for _, field in ipairs({"originX", "originY", "radius", "durationSeconds"}) do
                    fields[#fields + 1] = field
                end
            end
            fields[#fields + 1] = "priority"
            local nextIndex = 1
            for index, field in ipairs(fields) do
                if field == self.focus then nextIndex = index % #fields + 1; break end
            end
            self.focus = fields[nextIndex]
            self.selectAll = true
        elseif self.focus then
            if key == "a" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
                self.selectAll = true
            elseif key == "backspace" or key == "delete" then
                self.form[self.focus] = self.selectAll and "" or self.form[self.focus]:sub(1, -2)
                self.selectAll = false
            end
        end
        return true
    end
    return self.view ~= "inspect"
end

function Overlay:textinput(text)
    if Mode.enabled and self.view == "editor" and self.focus and text:match("^[%d%.%+%-]+$") then
        local value = self.selectAll and "" or self.form[self.focus]
        self.form[self.focus] = (value .. text):sub(1, 20)
        self.selectAll = false
    end
end

function Overlay:wheelmoved(map, delta)
    if not Mode.enabled or not self.view then return false end
    self:layout(map)
    local x, y = love.mouse.getPosition()
    if inside(x, y, self.bounds) then
        self.scroll = math.max(0, math.min(self.maxScroll, self.scroll - delta * 45))
        return true
    end
    return self:blocksWorldInput()
end

function Overlay:draw(map)
    if not Mode.enabled or not self.view then return end
    self:layout(map)
    local b = self.bounds
    love.graphics.push("all")
    love.graphics.setFont(self.font)
    love.graphics.setColor(0.12, 0.11, 0.10, 0.98)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    love.graphics.setColor(0.8, 0.55, 0.22, 1)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
    local titles = {menu = "DEBUG OPTIONS", inspect = "LIVE INSPECTOR", editor = "CONFIGURE LEADER GOAL", destinations = "DESTINATION"}
    love.graphics.print(titles[self.view], b.x + 12, b.y + 12)
    love.graphics.print("X", b.x + b.w - 27, b.y + 12)
    local c = self.content
    love.graphics.setScissor(c.x, c.y, c.w, c.h)
    local mx, my = love.mouse.getPosition()
    for _, row in ipairs(self.controls) do
        if row.y + row.h >= c.y and row.y <= c.y + c.h then
            if row.kind == "button" then
                local btn = Button.new(row.text, row.x, row.y, row.w, row.h)
                btn.state = inside(mx, my, row) and "hover" or "idle"
                btn:draw()
            elseif row.kind == "field" then
                local focused = self.focus == row.key
                love.graphics.setColor(focused and 0.28 or 0.18, 0.19, 0.15, 1)
                love.graphics.rectangle("fill", row.x, row.y, row.w, row.h)
                love.graphics.setColor(0.85, 0.65, 0.3, 1)
                love.graphics.rectangle("line", row.x, row.y, row.w, row.h)
                love.graphics.setColor(1, 0.94, 0.82, 1)
                love.graphics.print(row.text .. (focused and " |" or ""), row.x + 10, row.y + 8)
            else
                love.graphics.setColor(0.92, 0.87, 0.77, 1)
                love.graphics.printf(row.text, row.x + 4, row.y, row.w - 12)
            end
        end
    end
    love.graphics.setScissor()
    love.graphics.setColor(0.75, 0.7, 0.6, 1)
    love.graphics.print(self.view == "inspect" and "Live world | Space: wait | Scroll | Esc: close"
        or "World paused | Scroll | Esc: close", b.x + 12, b.y + b.h - 23)
    if self.maxScroll > 0 then
        local thumbH = math.max(18, c.h * c.h / (self.maxScroll + c.h))
        love.graphics.setColor(0.8, 0.55, 0.22, 1)
        love.graphics.rectangle("fill", b.x + b.w - 5, c.y + (c.h - thumbH) * self.scroll / self.maxScroll, 3, thumbH)
    end
    love.graphics.pop()
end

return Overlay
