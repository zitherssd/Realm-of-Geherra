-- World-map debug menus. Inspectors are live; menus/editors pause world input.
local Mode = require("src.debug.mode")
local Tools = require("src.debug.campaign_tools")
local Inspector = require("src.debug.inspector")
local Button = require("src.ui.widgets.button")
local Knowledge = require("src.systems.knowledge.knowledge_system")
local PartySystem = require("src.systems.parties.party_system")

local Definitions = require("src.systems.goals.goal_definitions")

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new()
    return setmetatable({scroll = 0}, Overlay)
end

function Overlay:close()
    self.view, self.target, self.form, self.focus, self.message = nil, nil, nil, nil, nil
    self.goalForms, self.capabilities, self.commandPartyId = nil, nil, nil
    self.scroll = 0
end

function Overlay:blocksWorldInput()
    return Mode.enabled and self.view ~= nil and self.view ~= "inspect"
end

function Overlay:inspect(kind, id)
    self.view, self.target, self.scroll, self.message = "inspect", {kind = kind, id = id}, 0, nil
    self.focus = nil
end

-- Kept for programmatic party callers; UI goal editing starts from an NPC inspector.
function Overlay:edit(map, partyId)
    local leader, err = Tools.editableLeader(map, partyId, nil, true)
    if not leader then self:inspect("party", partyId); self.message = err; return end
    self:editActor(map, leader.id)
end

function Overlay:editActor(map, actorId)
    self:inspect("unit", actorId)
    local actor, err, party = Tools.editableActor(map, actorId, true)
    if not actor then self.message = err; return end
    self.commandPartyId = party and PartySystem.getLeader(party) == actor and party.id or nil
    local defaults = party or {treasury = actor.treasury or 0, x = actor.x, y = actor.y}
    local state = actor.npc_goals
    self.goalForms, self.capabilities = {}, {}
    for name, allowed in pairs(state and state.capabilities or (self.commandPartyId and {raid = true, travel = true} or {})) do
        self.capabilities[name] = allowed
    end
    for _, goal in ipairs(state and state.goals or (self.commandPartyId and {{type = "acquire_gold"}} or {})) do
        self.goalForms[#self.goalForms + 1] = Definitions.form(goal, defaults, function(id)
            return Tools.resolve(map, "location", id)
        end)
    end
    self.form = self.goalForms[1]
    self.view = "editor"
end

function Overlay:newGoal(map, id)
    local actor, err, party = Tools.editableActor(map, self.target.id, true, self.commandPartyId)
    if not actor then self.message = err; return end
    local defaults = party or {treasury = actor.treasury or 0, x = actor.x, y = actor.y}
    local form = Definitions.form({type = id}, defaults, function(locationId)
        return Tools.resolve(map, "location", locationId)
    end)
    self.goalForms[#self.goalForms + 1], self.form = form, form
    self.view, self.focus, self.scroll = "editor", nil, 0
end

function Overlay:editMemory(kind, id)
    self:inspect(kind, id)
    self.view, self.form = "memory", {eventId = "", details = {}}
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
        end
    elseif self.view == "inspect" then
        local target = Tools.resolve(map, self.target.kind, self.target.id)
        -- Both containers use the same NPC action and the same actor inspector.
        local function npcButton(actor, party)
            if actor.player then return end
            -- Memory marks important characters. Ordinary troops can also have
            -- names and recovery goals; those do not make them inspectable NPCs.
            local commander = party and PartySystem.getLeader(party) == actor
            if not actor.memory and not commander then return end
            local id = actor.id
            button("Inspect NPC: " .. (actor.name or tostring(id)), function()
                self:inspect("unit", id)
            end, "inspect_npc:" .. tostring(id))
        end
        if target and self.target.kind == "party" then
            local partyId = target.id
            button("Search here (radius 150 / six world hours)", function()
                local _, message = Tools.searchHere(map, partyId); self.message = message
            end, "search_here")
            for _, actor in ipairs(target.actors) do npcButton(actor, target) end
        elseif target and self.target.kind == "location" then
            for _, actor in ipairs(target.npcs or {}) do npcButton(actor) end
            for _, party in ipairs(target.stationedParties or {}) do
                local id = party.id
                if Tools.resolve(map, "party", id) then
                    button("Inspect stationed party: " .. (party.name or tostring(id)), function() self:inspect("party", id) end)
                end
            end
        end
        if target and self.target.kind == "unit" and not target.player then
            local party = require("src.systems.services.service_system").getParty(target, target.__world)
            if party and Tools.resolve(map, "party", party.id) then
                local partyId = party.id
                button("Inspect current party: " .. party.name, function() self:inspect("party", partyId) end)
            end
            local location = require("src.systems.services.service_system").getLocation(target, {world = target.__world, map = map})
            if location then
                local locationId = location.id
                button("Inspect current settlement: " .. location.name, function() self:inspect("location", locationId) end)
            end
            button("Configure Goal", function() self:editActor(map, self.target.id) end, "configure_goal")
            if target.memory then
                button("Enable CaravanFormation / Acquire Gold", function()
                    local _, message = Tools.enableCaravan(map, self.target.id, true); self.message = message
                end, "enable_caravan_sponsor")
                button("Enable LeadCaravan / ProvideService", function()
                    local _, message = Tools.enableCaravan(map, self.target.id, false); self.message = message
                end, "enable_caravan_worker")
            end
            button("Grant event knowledge", function() self:editMemory("unit", self.target.id) end, "grant_knowledge")
            if not target.memory then text("This NPC has no personal memory for event knowledge.") end
        elseif target and target.memory then
            button("Grant event knowledge", function() self:editMemory(self.target.kind, self.target.id) end)
        end
        for _, line in ipairs(Inspector.lines(map, self.target.kind, self.target.id)) do text(line) end
        local fixture = require("src.game.game_context").data.debugCampaign
        if fixture and fixture.map == map then
            text("DEBUG CAMPAIGN: " .. fixture.profile .. " (F2 events / F3 services)")
            for _, entry in ipairs({{kind = "location", id = fixture.homeId}, {kind = "location", id = fixture.farId}}) do
                local kind, id = entry.kind, entry.id
                local location = Tools.resolve(map, kind, id)
                if location then button("Settlement: " .. location.name .. " [" .. id .. "]",
                    function() self:inspect(kind, id) end) end
            end
            for _, id in ipairs(fixture.actors) do
                local actorId = id
                local actor = Tools.resolve(map, "unit", actorId)
                if actor then button("Debug NPC: " .. actor.name .. " [" .. actorId .. "]",
                    function() self:inspect("unit", actorId) end) end
            end
            for _, id in ipairs(fixture.parties) do
                local partyId = id
                local party = Tools.resolve(map, "party", partyId)
                if party then button("Debug party: " .. party.name,
                    function() self:inspect("party", partyId) end) end
            end
        end
    elseif self.view == "memory" then
        text("Grant explicit historical knowledge. No selected details means knowing only that the event exists.")
        field("Existing event ID (see F2)", "eventId")
        local target = Tools.resolve(map, self.target.kind, self.target.id)
        local categories = target and Knowledge.getDetailCategories(self.form.eventId, target.__world) or {}
        for _, category in ipairs(categories) do
            local name = category
            button((self.form.details[name] and "[x] " or "[ ] ") .. name, function()
                self.form.details[name] = not self.form.details[name] or nil
            end, name)
        end
        button("Grant selected details", function()
            local ok, message = Tools.grantKnowledge(map, self.target.kind, self.target.id,
                self.form.eventId, self.form.details)
            if ok then self:inspect(self.target.kind, self.target.id) end
            self.message = message
        end, "grant")
        button("Cancel", function() self:inspect(self.target.kind, self.target.id) end)
    elseif self.view == "editor" then
        text("Edit the full goal list and capabilities. Applying restarts goals and stops the current activity; encounter and retry rules still apply.")
        text("NPC GOALS (" .. #self.goalForms .. ")")
        for index, form in ipairs(self.goalForms) do
            local spec = Definitions.goals[form.type]
            button((self.form == form and "[Selected] " or "") .. index .. ". " .. spec.label, function()
                self.form, self.focus = form, nil
            end, "goal:" .. index)
        end
        button("Add goal / browse all implemented goals", function()
            self.view, self.scroll, self.focus = "goal_catalog", 0, nil
        end, "add_goal")
        if self.form then
            local spec = Definitions.goals[self.form.type]
            text(spec.label .. ": " .. (spec.description or ""))
            if spec.managed then
                text("Managed goal: use the service system to change this assignment. Accepted obligations block applying changes until resolved.")
                for _, fieldSpec in ipairs(spec.fields or {}) do
                    text(fieldSpec.label .. ": " .. tostring(self.form[fieldSpec.key]))
                end
            else
                for _, fieldSpec in ipairs(spec.fields or {}) do
                    local key = fieldSpec.key
                    if not fieldSpec.when or self.form[fieldSpec.when] then
                        if fieldSpec.kind == "boolean" then
                            button((self.form[key] and "[x] " or "[ ] ") .. fieldSpec.label, function()
                                self.form[key] = not self.form[key]
                            end, key)
                        elseif fieldSpec.kind == "location" then
                            local destination = Tools.resolve(map, "location", self.form[key])
                            button(fieldSpec.label .. ": " .. (destination and destination.name or "Choose location..."), function()
                                self.destinationKey = key
                                self.view, self.scroll, self.focus = "destinations", 0, nil
                            end, key)
                        else
                            field(fieldSpec.label, key)
                        end
                    end
                end
                field("Base importance (state rules may override)", "priority")
            end
            button(spec.managed and "Remove resolved obligation from goal list" or "Remove selected goal", function()
                for index, form in ipairs(self.goalForms) do
                    if form == self.form then table.remove(self.goalForms, index); break end
                end
                self.form, self.focus = self.goalForms[1], nil
            end, "remove_goal")
        else
            text("No goals assigned.")
        end
        text("ALL CAPABILITIES")
        local names = {}
        for name in pairs(Definitions.capabilities) do names[name] = true end
        for name in pairs(self.capabilities) do names[name] = true end
        local sorted = {}
        for name in pairs(names) do sorted[#sorted + 1] = name end
        table.sort(sorted)
        for _, name in ipairs(sorted) do
            local key = name
            local spec = Definitions.capabilities[key]
            button((self.capabilities[key] and "[x] " or "[ ] ") .. (spec and spec.label or key) .. " capability", function()
                self.capabilities[key] = not self.capabilities[key]
            end, "capability:" .. key)
        end
        button("Apply - save all NPC goals and capabilities", function()
            local ok, message = Tools.configureActorGoals(map, self.target.id, self.goalForms, self.capabilities, self.commandPartyId)
            if ok then self.view, self.focus = "inspect", nil end
            self.scroll, self.message = 0, message
        end, "apply")
        button("Cancel", function() self:inspect(self.target.kind, self.target.id) end)
    elseif self.view == "goal_catalog" then
        button("Back to goal editor", function() self.view, self.scroll = "editor", 0 end)
        text("ALL IMPLEMENTED GOALS")
        for _, spec in ipairs(Definitions.list(Definitions.goals)) do
            local id = spec.id
            text(spec.label .. " (" .. id .. "): " .. (spec.description or ""))
            if spec.managed then
                text("Managed by the service system; cannot be added manually.")
            else
                button("Add " .. spec.label, function() self:newGoal(map, id) end, "add:" .. id)
            end
        end
    elseif self.view == "destinations" then
        button("Back to goal editor", function() self.view, self.scroll = "editor", 0 end)
        text("Choose a destination on the current map:")
        for _, location in ipairs(Tools.locations(map)) do
            local id = location.id
            button(location.name .. " [" .. tostring(id) .. "]", function()
                self.form[self.destinationKey or "destinationLocationId"] = id
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
        if self:blocksWorldInput() and self.view ~= "menu" then return true end
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
    if self.view == "editor" or self.view == "memory" then
        if key == "tab" then
            if self.view == "memory" then self.focus, self.selectAll = "eventId", true; return true end
            local fields = {}
            local spec = self.form and Definitions.goals[self.form.type]
            if spec and not spec.managed then
                for _, field in ipairs(spec.fields or {}) do
                    if (field.kind == "number" or field.kind == "string") and (not field.when or self.form[field.when]) then
                        fields[#fields + 1] = field.key
                    end
                end
                fields[#fields + 1] = "priority"
            end
            if #fields == 0 then return true end
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
                if self.view == "memory" then self.form.details = {} end
                self.selectAll = false
            end
        end
        return true
    end
    return self.view ~= "inspect"
end

function Overlay:textinput(text)
    local stringField = false
    if self.view == "editor" and self.form then
        for _, field in ipairs(Definitions.goals[self.form.type].fields or {}) do
            if field.key == self.focus and field.kind == "string" then stringField = true end
        end
    end
    local allowed = (self.view == "memory" and text:match("^[%w_]+$")) or
        (self.view == "editor" and (stringField and not text:find("[%c]") or text:match("^[%d%.%+%-]+$")))
    if Mode.enabled and self.focus and allowed then
        local value = self.selectAll and "" or self.form[self.focus]
        self.form[self.focus] = (value .. text):sub(1, stringField and 128 or 32)
        self.selectAll = false
        if self.view == "memory" then self.form.details = {} end
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
    local titles = {menu = "DEBUG OPTIONS", inspect = "LIVE INSPECTOR", editor = "CONFIGURE NPC GOALS",
        goal_catalog = "ALL IMPLEMENTED GOALS", destinations = "DESTINATION", memory = "GRANT EVENT KNOWLEDGE"}
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
