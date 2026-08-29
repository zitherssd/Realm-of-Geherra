-- ui/screens/shop_screen.lua
-- Trading screen: buy from the merchant's stock, sell to the merchant
-- (selling only when merchant.buysFromPlayers is true).

local ShopScreen = {}
ShopScreen.__index = ShopScreen

local Button = require("src.ui.widgets.button")
local Tooltip = require("src.ui.widgets.tooltip")
local InventoryGrid = require("src.ui.widgets.inventory_grid")

-- Add one unit of an item definition to a merchant's stock, stacking onto an
-- existing entry with the same id. Used when selling so the item goes into the
-- trader's inventory instead of vanishing.
local function addToStock(stock, itemDef)
    if not stock or not itemDef then return end

    for _, existing in ipairs(stock) do
        if existing.id == itemDef.id then
            existing.quantity = (existing.quantity or 1) + 1
            return
        end
    end

    local copy = {}
    for k, v in pairs(itemDef) do
        copy[k] = v
    end
    copy.quantity = 1
    table.insert(stock, copy)
end

function ShopScreen.new(playerParty, merchant, onClose)
    local self = setmetatable({}, ShopScreen)

    self.playerParty = playerParty
    self.merchant = merchant
    self.onClose = onClose

    self.merchantStock = merchant.inventory or {}
    self.playerInventory = playerParty.inventory
    self.allowSell = merchant.buysFromPlayers or false
    self.sellPriceFactor = merchant.sellPriceFactor or 1.0

    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()

    -- Two grids side by side
    local margin = 40
    local gap = 20
    local gridW = math.floor((self.width - margin * 2 - gap) / 2)
    local gridH = math.floor(self.height * 0.62)
    local gridY = 90

    self.stockGrid = InventoryGrid.new(
        "Stock",
        self.merchantStock,
        margin, gridY, gridW, gridH, 72,
        function(item, index) self:buyItem(index) end,
        { title = "Stock", capacity = "Merchant" }
    )
    self.stockGrid:enableScroll()

    self.invGrid = InventoryGrid.new(
        "Your Inventory",
        self.playerInventory,
        margin + gridW + gap, gridY, gridW, gridH, 72,
        self.allowSell and (function(item, index) self:sellItem(index) end) or nil,
        {
            title = "Your Inventory",
            capacity = "Capacity",
            gold = function() return self.playerParty:getTreasury() or 0 end
        }
    )
    self.invGrid:enableScroll()

    self.closeBtn = Button.new("Close", self.width / 2 - 50, self.height - 70, 100, 40, function()
        if self.onClose then self.onClose() end
    end)

    self.tooltip = Tooltip.new(280)

    -- Cached fonts
    self.titleFont = love.graphics.newFont(26)
    self.messageFont = love.graphics.newFont(16)

    -- Keyboard selection state
    self.focus = "stock" -- "stock" or "inv"
    self.gridCols = math.floor((gridW - self.stockGrid.padding) / self.stockGrid.rowHeight)
    if self.gridCols < 1 then self.gridCols = 1 end

    return self
end

--------------------------------------------------------------------------------
-- Trading logic
--------------------------------------------------------------------------------

function ShopScreen:buyItem(index)
    local item = self.merchantStock[index]
    if not item then return false end

    local price = item.value or 0
    if not self.playerParty:withdrawTreasury(price) then
        self.lastMessage = "You can't afford " .. (item.name or "that") .. "."
        self.lastMessageTimer = 2.5
        return false
    end

    -- Give the player a fresh copy of the item
    self.playerParty:addItemDefCopy(item, 1)

    -- Deplete the merchant's stock
    if item.quantity and item.quantity > 1 then
        item.quantity = item.quantity - 1
    else
        table.remove(self.merchantStock, index)
    end

    self.lastMessage = "Bought " .. (item.name or "item") .. " for " .. price .. " gold."
    self.lastMessageTimer = 2.5
    return true
end

function ShopScreen:sellItem(index)
    if not self.allowSell then return false end

    local item = self.playerInventory[index]
    if not item then return false end

    local price = math.floor((item.value or 0) * self.sellPriceFactor)

    -- Remove the item from the player's inventory
    if item.quantity and item.quantity > 1 then
        item.quantity = item.quantity - 1
    else
        table.remove(self.playerInventory, index)
    end

    -- The sold item goes into the merchant's stock
    addToStock(self.merchantStock, item)

    self.playerParty:addTreasury(price)
    self.lastMessage = "Sold " .. (item.name or "item") .. " for " .. price .. " gold."
    self.lastMessageTimer = 2.5
    return true
end

--------------------------------------------------------------------------------
-- Update / Draw
--------------------------------------------------------------------------------

function ShopScreen:update(dt)
    self.stockGrid:update(dt)
    self.invGrid:update(dt)
    self.closeBtn:update(dt)
    self.tooltip:update(dt)
    if self.lastMessageTimer then
        self.lastMessageTimer = self.lastMessageTimer - dt
    end
end

function ShopScreen:draw()
    love.graphics.setColor(0.05, 0.05, 0.05, 1)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)

    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Trading with " .. (self.merchant.name or "Merchant"), 0, 20, self.width, "center")

    if self.lastMessage and self.lastMessageTimer and self.lastMessageTimer > 0 then
        love.graphics.setFont(self.messageFont)
        love.graphics.setColor(1, 0.9, 0.4, 1)
        love.graphics.printf(self.lastMessage, 0, 58, self.width, "center")
    end

    self.stockGrid:draw()
    self.invGrid:draw()
    self.closeBtn:draw()

    -- Tooltip for hovered item
    local hoveredStock = self.stockGrid:getHoveredItem()
    local hoveredInv = self.invGrid:getHoveredItem()
    local hovered = hoveredStock or hoveredInv

    if hovered then
        local value = hovered.value or 0
        local text = (hovered.name or "???") .. "\n" .. (hovered.description or "")
        if hoveredStock then
            text = text .. "\n\nClick to buy for " .. value .. " gold"
        elseif hoveredInv and self.allowSell then
            local sellPrice = math.floor(value * self.sellPriceFactor)
            text = text .. "\n\nClick to sell for " .. sellPrice .. " gold"
        end
        self.tooltip:setText(text)
        local mx, my = love.mouse.getPosition()
        self.tooltip:setPosition(mx, my)
        self.tooltip:show()
    else
        self.tooltip:hide()
    end
    self.tooltip:draw()
end

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------

function ShopScreen:_currentGrid()
    if self.focus == "inv" then
        return self.invGrid, #self.playerInventory
    end
    return self.stockGrid, #self.merchantStock
end

function ShopScreen:_switchFocus()
    if self.focus == "stock" then
        self.focus = "inv"
        self.invGrid:setSelectedIndex(1)
    else
        self.focus = "stock"
        self.stockGrid:setSelectedIndex(1)
    end
end

function ShopScreen:keypressed(key)
    if key == "escape" then
        if self.onClose then self.onClose() end
        return
    end

    if key == "tab" then
        self:_switchFocus()
        return
    end

    local grid, maxIndex = self:_currentGrid()
    if maxIndex <= 0 then return end

    local idx = grid.selectedIndex or 1

    if key == "up" then
        idx = math.max(1, idx - self.gridCols)
    elseif key == "down" then
        idx = math.min(maxIndex, idx + self.gridCols)
    elseif key == "left" then
        if idx > 1 then
            idx = idx - 1
        elseif self.focus == "inv" then
            self:_switchFocus()
            return
        end
    elseif key == "right" then
        if idx < maxIndex then
            idx = idx + 1
        elseif self.focus == "stock" then
            self:_switchFocus()
            return
        end
    elseif key == "return" or key == "space" or key == "kpenter" then
        if self.focus == "stock" then
            self:buyItem(idx)
        elseif self.allowSell then
            self:sellItem(idx)
        end
        return
    end

    grid:setSelectedIndex(idx)
end

function ShopScreen:wheelmoved(dx, dy)
    local mx, my = love.mouse.getPosition()
    local stock = self.stockGrid
    local inv = self.invGrid
    if mx >= stock.x and mx <= stock.x + stock.w and my >= stock.y and my <= stock.y + stock.h then
        stock:wheelmoved(dx, dy)
    elseif mx >= inv.x and mx <= inv.x + inv.w and my >= inv.y and my <= inv.y + inv.h then
        inv:wheelmoved(dx, dy)
    end
end

return ShopScreen
