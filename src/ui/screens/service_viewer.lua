local Services = require("src.systems.services.service_system")
local EcsWorld = require("src.ecs.world")
local Text = require("src.ui.world_event_text")
local Viewer = {}
Viewer.__index = Viewer

function Viewer.new(world, map)
    local self = setmetatable({world = world, map = map, scroll = 0, detailScroll = 0,
        rowHeight = 142, tab = "requests", filter = "all"}, Viewer)
    self:refresh()
    return self
end

function Viewer:refresh()
    local context = {world = self.world, map = self.map}
    self.requests = Services.listRequests(context)
    self.providers = Services.listProviders(context)
    self:selectRows()
end

function Viewer:selectRows()
    self.rows = {}
    for _, entry in ipairs(self.tab == "requests" and self.requests or self.providers) do
        if self.tab == "providers" or self.filter == "all" or entry.status == self.filter
            or (self.filter == "closed" and (entry.status == "completed" or entry.status == "cancelled")) then
            self.rows[#self.rows + 1] = entry
        end
    end
    local found = false
    for _, entry in ipairs(self.rows) do if entry.id == self.selectedId then found = true end end
    if not found then self.selectedId = self.rows[1] and self.rows[1].id end
    self.scroll, self.detailScroll = 0, 0
end

function Viewer:keypressed(key)
    if key == "r" then self:refresh()
    elseif key == "tab" then
        self.tab = self.tab == "requests" and "providers" or "requests"
        self.selectedId = nil
        self:selectRows()
    elseif ({["1"] = "all", ["2"] = "open", ["3"] = "assigned", ["4"] = "closed"})[key] then
        self.filter = ({["1"] = "all", ["2"] = "open", ["3"] = "assigned", ["4"] = "closed"})[key]
        self:selectRows()
    end
end

function Viewer:describe(entry)
    if self.tab == "providers" then
        return (entry.name or entry.id) .. " [" .. entry.id .. "]\n"
            .. entry.locationName .. " | " .. entry.selectedGoal .. "\nCapability: heal | Heal: " .. entry.price .. " gold / " .. entry.amount .. " HP"
    end
    local worker = EcsWorld.findActorById(entry.assignedActorId, self.world)
    local location = EcsWorld.findLocationById(entry.locationId, self.world)
    return entry.id .. " | " .. entry.type .. " | " .. entry.status .. "\n"
        .. (entry.employerName or entry.employerId) .. " @ " .. (location and location.name or tostring(entry.locationId))
        .. "\nRequires: " .. entry.requiredCapability .. "\nWorker: "
        .. (worker and worker.name or tostring(entry.assignedActorId or "none"))
end

function Viewer:layout()
    local w, h = love.graphics.getDimensions()
    local margin = math.min(24, w * 0.03)
    local left = {x = margin, y = 92, w = (w - margin * 3) * 0.46, h = math.max(40, h - 126)}
    local right = {x = left.x + left.w + margin, y = left.y,
        w = w - left.x - left.w - margin * 2, h = left.h}
    self.scroll = math.max(0, math.min(self.scroll, #self.rows * self.rowHeight - left.h))
    return left, right, w
end

local function inside(x, y, box)
    return x >= box.x and x < box.x + box.w and y >= box.y and y < box.y + box.h
end

function Viewer:mousepressed(x, y, button)
    local left, _, w = self:layout()
    if button ~= 1 then return end
    if x >= w - 120 and y >= 16 and y < 52 then return "close" end
    if y >= 55 and y < 88 then
        if x < left.x + left.w then self:keypressed("tab") else self:keypressed("r") end
        return
    end
    if inside(x, y, left) then
        local row = math.floor((y - left.y + self.scroll) / self.rowHeight)
        local event = self.rows[row + 1]
        if event then self.selectedId, self.detailScroll = event.id, 0 end
    end
end

function Viewer:wheelmoved(delta)
    local left, right = self:layout()
    local x, y = love.mouse.getPosition()
    if inside(x, y, left) then self.scroll = self.scroll - delta * 45
    elseif inside(x, y, right) then self.detailScroll = math.max(0, self.detailScroll - delta * 45) end
end

function Viewer:draw()
    local g = love.graphics
    g.push("all")
    g.origin()
    self.font = self.font or g.newFont(14)
    g.setFont(self.font)
    local left, right, w = self:layout()
    g.setColor(0.07, 0.065, 0.06, 0.98)
    g.rectangle("fill", 0, 0, g.getDimensions())
    g.setColor(1, 0.8, 0.4)
    g.print("GLOBAL SERVICE VIEWER", left.x, 25)
    g.printf("[Close]", w - 120, 25, 100, "center")
    g.setColor(0.7, 0.7, 0.7)
    g.print("[Tab] " .. self.tab .. " | " .. self.filter, left.x, 65)
    g.printf("[R] Refresh | 1 All  2 Open  3 Assigned  4 Closed", right.x, 60, right.w)
    g.print("F3 / Escape: close | Click row to select | Wheel over either panel to scroll", left.x, left.y + left.h + 10)
    for _, box in ipairs({left, right}) do
        g.setColor(0.16, 0.15, 0.13)
        g.rectangle("fill", box.x, box.y, box.w, box.h)
    end
    local count = #self.rows
    if not self.selectedId and count > 0 then self.selectedId = self.rows[1].id end
    g.setScissor(left.x, left.y, left.w, left.h)
    g.setColor(0.85, 0.85, 0.85)
    if count == 0 then g.printf("No " .. self.tab .. " to display.", left.x + 12, left.y + 16, left.w - 24) end
    local first = math.floor(self.scroll / self.rowHeight)
    for row = first, math.min(count - 1, first + math.ceil(left.h / self.rowHeight)) do
        local event = self.rows[row + 1]
        local y = left.y + row * self.rowHeight - self.scroll
        g.setScissor(left.x, left.y, left.w, left.h)
        if event.id == self.selectedId then
            g.setColor(0.32, 0.27, 0.16)
            g.rectangle("fill", left.x, y, left.w, self.rowHeight - 2)
        end
        g.setScissor(left.x, math.max(y, left.y), left.w,
            math.max(0, math.min(y + self.rowHeight - 4, left.y + left.h) - math.max(y, left.y)))
        g.setColor(1, 0.8, 0.4)
        g.printf(self.tab == "requests" and "Commission" or "Immediate service", left.x + 10, y + 7, left.w - 20)
        g.setColor(0.95, 0.95, 0.95)
        g.printf(self:describe(event), left.x + 10, y + 29, left.w - 20)
    end
    g.setScissor(right.x, right.y, right.w, right.h)
    local selected
    for _, entry in ipairs(self.rows) do if entry.id == self.selectedId then selected = entry end end
    local text = "Select a service or provider to inspect its current state."
    if selected then
        local identity = ""
        if self.tab == "requests" then
            identity = "\nEmployer ID: " .. tostring(selected.employerId)
                .. "\nWorker ID: " .. tostring(selected.assignedActorId or "none")
                .. "\nLocation ID: " .. tostring(selected.locationId)
                .. "\nOffer event: " .. tostring(selected.offerEventId)
                .. "\nFilled event: " .. tostring(selected.filledEventId or "none")
                .. "\nClosure event: " .. tostring(selected.closureEventId or "none")
        end
        text = self:describe(selected) .. identity .. "\n\n" .. Text.details(selected, true)
    end
    local _, lines = self.font:getWrap(text, right.w - 24)
    local height = #lines * self.font:getHeight() * self.font:getLineHeight()
    self.detailScroll = math.max(0, math.min(self.detailScroll, height - right.h + 24))
    g.setColor(0.95, 0.95, 0.95)
    g.printf(text, right.x + 12, right.y + 12 - self.detailScroll, right.w - 24)
    g.pop()
end

return Viewer
