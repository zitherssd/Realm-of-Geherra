
local interactions = require('src.data.interactions')
local GameState = require('src.game.GameState')
local SimpleMenu = {}

-- Module-level state (singleton)
SimpleMenu.borderImgPath = 'assets/sprites/ui/border2.png'
SimpleMenu.borderTileSize = 16
SimpleMenu.borderImgSize = 48
SimpleMenu.activeMenu = nil
SimpleMenu.menuCooldown = false
SimpleMenu.borderImg = nil
SimpleMenu.borderQuads = nil
SimpleMenu.text = nil

function SimpleMenu:initBorder()
    if self.borderImg then return end
    self.borderImg = love.graphics.newImage(self.borderImgPath)
    local s = self.borderTileSize
    local S = self.borderImgSize
    self.borderQuads = {
        tl = love.graphics.newQuad(0, 0, s, s, S, S),
        tr = love.graphics.newQuad(S - s, 0, s, s, S, S),
        bl = love.graphics.newQuad(0, S - s, s, s, S, S),
        br = love.graphics.newQuad(S - s, S - s, s, s, S, S),
        top = love.graphics.newQuad(s, 0, S - 2*s, s, S, S),
        bottom = love.graphics.newQuad(s, S - s, S - 2*s, s, S, S),
        left = love.graphics.newQuad(0, s, s, S - 2*s, S, S),
        right = love.graphics.newQuad(S - s, s, s, S - 2*s, S, S),
        center = love.graphics.newQuad(s, s, S - 2*s, S - 2*s, S, S),
    }
end

function SimpleMenu:draw9SliceBorder(x, y, w, h)
    local img = self.borderImg
    local q = self.borderQuads
    local s = self.borderTileSize
    local S = self.borderImgSize
    local ex, ey = x + w - s, y + h - s
    love.graphics.draw(img, q.tl, x, y)
    love.graphics.draw(img, q.tr, ex, y)
    love.graphics.draw(img, q.bl, x, ey)
    love.graphics.draw(img, q.br, ex, ey)
    love.graphics.draw(img, q.top, x + s, y, 0, (w - 2*s)/(S - 2*s), 1)
    love.graphics.draw(img, q.bottom, x + s, ey, 0, (w - 2*s)/(S - 2*s), 1)
    love.graphics.draw(img, q.left, x, y + s, 0, 1, (h - 2*s)/(S - 2*s))
    love.graphics.draw(img, q.right, ex, y + s, 0, 1, (h - 2*s)/(S - 2*s))
    love.graphics.draw(img, q.center, x + s, y + s, 0, (w - 2*s)/(S - 2*s), (h - 2*s)/(S - 2*s))
end

function SimpleMenu:isOpen()
    return self.activeMenu ~= nil
end

function SimpleMenu:isCooldown()
    return self.menuCooldown
end

function SimpleMenu:resetCooldown()
    self.menuCooldown = false
end

-- Generic open by target.interactions list
function SimpleMenu:open(target)
    local options = {}
    for _, interactionKey in ipairs((target and target.interactions) or {}) do
        local definition = interactions[interactionKey] or nil
        if definition then
            table.insert(options, {
                label = definition.label,
                action = function()
                    definition.action({
                        target = target,
                        closeMenu = function()
                            self.activeMenu = nil
                            self.menuCooldown = true
                        end,
                        showMessage = function(text, opts)
                            self:showMessage(text, opts)
                        end
                    })
                end
            })
        elseif self.InteractionModule and self.PlayerModule then
            -- If only InteractionModule is desired, allow label as key
            table.insert(options, {
                label = tostring(interactionKey),
                action = function()
                    local actor = self.PlayerModule:getPlayerParty()
                    self.InteractionModule.trigger(actor, target, interactionKey)
                    self:close()
                end
            })
        end
    end
    table.insert(options, { label = "Leave", action = function() self:close() end })
    self:initBorder()
    self.activeMenu = { target = target, options = options, selected = 1 }
    self.text = nil
end

function SimpleMenu:show(target, text)
     local options = {}
    for _, interactionKey in ipairs((target and target.interactions) or {}) do
        local definition = interactions[interactionKey] or nil
        if definition then
            table.insert(options, {
                label = definition.label,
                action = function()
                    definition.action({
                        target = target,
                        closeMenu = function()
                            self.activeMenu = nil
                            self.menuCooldown = true
                        end
                    })
                end
            })
        elseif self.InteractionModule and self.PlayerModule then
            -- If only InteractionModule is desired, allow label as key
            table.insert(options, {
                label = tostring(interactionKey),
                action = function()
                    local actor = self.PlayerModule:getPlayerParty()
                    self.InteractionModule.trigger(actor, target, interactionKey)
                    self:close()
                end
            })
        end
    end
    table.insert(options, { label = "Leave", action = function() self:close() end })
    self:initBorder()
    self.activeMenu = { target = target, options = options, selected = 1 }
    self.text = text;
end

-- Show a simple message with custom options (each option: {label, action})
function SimpleMenu:showMessage(text, options)
    self:initBorder()
    local opts = options or { { label = "Close", action = function() self:close() end } }
    self.activeMenu = { target = { name = '' }, options = opts, selected = 1, text = text }
    self.menuCooldown = false  -- Reset cooldown so message stays visible
end

function SimpleMenu:draw(w, h)
    if not self.activeMenu then return end

    local text = self.activeMenu.text
    local hasText = text and text ~= ""
    local isMessage = hasText and (#self.activeMenu.options == 0 or (#self.activeMenu.options == 1 and self.activeMenu.options[1].label == "Close"))
    local isHorizontal = hasText and not isMessage

    local mw, mh
    if isMessage then
        -- 🟡 Dynamic sizing for message boxes
        local font = love.graphics.getFont()
        local wrapLimit = math.floor(w * 0.5)  -- half the screen width max
        local wrappedText, wrappedLines = font:getWrap(text, wrapLimit)
        mw = math.max(200, math.min(wrapLimit + 40, w - 100)) -- some padding
        mh = 60 + (#wrappedLines * font:getHeight() + 40)
    elseif isHorizontal then
        local optionWidth = 120
        mw = 40 + (optionWidth * #self.activeMenu.options)
        mh = 120
    else
        mw, mh = 300, 40 + 30 * #self.activeMenu.options
    end

    local mx, my = (w - mw) / 2, (h - mh) / 2
    local bgPad = self.borderTileSize - 2

    -- 🟡 Draw background and border
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', mx - bgPad, my - bgPad, mw + bgPad * 2, mh + bgPad * 2, 8, 8)
    if self.borderImg and self.borderQuads then
        love.graphics.setColor(1, 1, 1, 1)
        self:draw9SliceBorder(mx - self.borderTileSize, my - self.borderTileSize, mw + self.borderTileSize * 2, mh + self.borderTileSize * 2)
    end

    love.graphics.setColor(1, 1, 1)
    local currentY = my + 15

    -- 🟡 Message mode (centered multiline text)
    if isMessage then
        local font = love.graphics.getFont()
        local _, wrappedLines = font:getWrap(text, mw - 40)
        love.graphics.printf(text, mx + 20, currentY, mw - 40, 'center')
        currentY = currentY + (#wrappedLines * font:getHeight()) + 30
    elseif hasText then
        love.graphics.printf(text, mx, currentY, mw, 'center')
        currentY = currentY + 30
    else
        local title = (self.activeMenu.target and self.activeMenu.target.name) or ""
        if title ~= "" then
            love.graphics.printf(title .. (title ~= '' and " - " or "") .. "Choose an action:", mx, currentY, mw, 'center')
            currentY = currentY + 30
        end
    end

    -- 🟡 Options (below message)
    if #self.activeMenu.options > 0 then
        for i, opt in ipairs(self.activeMenu.options) do
            local y = currentY + (i-1) * 30
            if i == self.activeMenu.selected then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.printf(opt.label, mx + 20, y, mw - 40, 'center')
        end
    end

    love.graphics.setColor(1, 1, 1)
end


function SimpleMenu:onAction(action)
    if not self.activeMenu then return end
    if action == 'navigate_up' then
        self.activeMenu.selected = (self.activeMenu.selected - 2) % #self.activeMenu.options + 1
    elseif action == 'navigate_down' then
        self.activeMenu.selected = self.activeMenu.selected % #self.activeMenu.options + 1
    elseif action == 'activate' then
        local opt = self.activeMenu.options[self.activeMenu.selected]
        if opt and opt.action then
            local before = self.activeMenu
            opt.action()
            if self.activeMenu == before then
                self:close()
            end
        end
    elseif action == 'cancel' then
        self:close()
    end
end

function SimpleMenu:close()
    self.activeMenu = nil
    self.menuCooldown = true
end

return SimpleMenu
