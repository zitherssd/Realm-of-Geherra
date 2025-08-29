local TradingState = {}

local PartyModule = require('src.game.modules.PartyModule')
local GameState = require('src.game.GameState')
local InputModule = require('src.game.modules.InputModule')
local ItemModule = require('src.game.modules.ItemModule')
local InventoryPanel = require('src.game.ui.InventoryPanel')

function TradingState:enter(tradingPartner)
  self.playerParty = PartyModule.parties[1]
  if not self.playerParty.gold then self.playerParty.gold = 500 end
  self.trader = tradingPartner

  self.playerInventory = self.playerParty.inventory or {}
  self.traderInventory = self.trader.stock or {}
  self.playerOffer = {}
  self.traderOffer = {}
  self.goldOffer = 0

  self.focus = "player_inv"
  self.playerInvIdx = 1
  self.traderInvIdx = 1
  self.playerOfferIdx = 1
  self.traderOfferIdx = 1
  self.buttonIdx = 1 -- 1 = Cancel, 2 = Confirm
  self.lastPanelFocus = "player_inv"
end

function TradingState:update(dt)
end

function TradingState:getOfferValue(offer)
  local total = 0
  for _, item in ipairs(offer) do
    if item.value then
      if item.stackable and item.quantity then
        total = total + item.value * item.quantity
      else
        total = total + item.value
      end
    end
  end
  return total
end

function TradingState:draw()
  local w, h = 640, 480
  love.graphics.clear(0.12, 0.12, 0.15, 1)

  love.graphics.printf("Your Inventory", 20, 20, 280, 'left')
  love.graphics.printf(self.trader.name .. "'s Goods", 340, 20, 280, 'left')

  -- Inventory panels
  local invW, invH = 280, 120
  InventoryPanel:draw(self.playerInventory, self.playerInvIdx, 20, 40, invW, invH, self.focus == "player_inv")
  InventoryPanel:draw(self.traderInventory, self.traderInvIdx, 340, 40, invW, invH, self.focus == "trader_inv")

  love.graphics.printf("Your Offer", 20, 170, 280, 'left')
  InventoryPanel:draw(self.playerOffer, self.playerOfferIdx, 20, 190, invW, 80, self.focus == "player_offer")

  love.graphics.printf("Their Offer", 340, 170, 280, 'left')
  InventoryPanel:draw(self.traderOffer, self.traderOfferIdx, 340, 190, invW, 80, self.focus == "trader_offer")

  -- Calculate and display balance
  local playerValue = self:getOfferValue(self.playerOffer)
  local traderValue = self:getOfferValue(self.traderOffer)
  local balance = playerValue - traderValue
  local balanceText = ""
  if balance > 0 then
    balanceText = "You receive: " .. balance .. " gold"
  elseif balance < 0 then
    balanceText = "You pay: " .. math.abs(balance) .. " gold"
  else
    balanceText = "Even trade"
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Your Gold: " .. self.playerParty.gold, 20, h - 30, w, 'left')
  love.graphics.printf(balanceText, 240, h-50, 160, 'center')
  -- Draw buttons with highlight if focused
  if self.focus == "buttons" then
    love.graphics.setColor(self.buttonIdx == 1 and {1,1,0,0.7} or {1,1,1,1})
    love.graphics.rectangle('line', 240, h-30, 80, 24)
    love.graphics.printf("Cancel", 240, h-26, 80, 'center')
    love.graphics.setColor(self.buttonIdx == 2 and {1,1,0,0.7} or {1,1,1,1})
    love.graphics.rectangle('line', 320, h-30, 80, 24)
    love.graphics.printf("Confirm", 320, h-26, 80, 'center')
    love.graphics.setColor(1,1,1,1)
  else
  love.graphics.rectangle('line', 240, h-30, 80, 24)
  love.graphics.printf("Cancel", 240, h-26, 80, 'center')
  love.graphics.rectangle('line', 320, h-30, 80, 24)
  love.graphics.printf("Confirm", 320, h-26, 80, 'center')
  end
end

function TradingState:keypressed(key)
  InputModule:handleKeyEvent(key, self)
end

function TradingState:getPanelCols(panelW)
  local gridCell, gridPad = 56, 8
  return math.floor((panelW + gridPad) / (gridCell + gridPad))
end

function TradingState:onAction(action)
  if action == 'cancel' then GameState:pop() return end

  local invW, invH = 280, 120
  local offerH = 80
  local function nav(idx, items, drow, dcol, panelW, panelH)
    local cols = self:getPanelCols(panelW)
    local rows = math.ceil(#items / cols)
    local row = math.floor((idx-1) / cols)
    local col = (idx-1) % cols
    row = math.max(0, math.min(rows-1, row + drow))
    col = math.max(0, math.min(cols-1, col + dcol))
    local newIdx = row * cols + col + 1
    if newIdx > #items then newIdx = #items end
    if newIdx < 1 then newIdx = 1 end
    return newIdx, row, col, cols, rows
  end

  -- Helper to switch focus if at edge
  local function tryPanelEdgeNav(panel, idx, drow, dcol, panelW, panelH)
    local cols = self:getPanelCols(panelW)
    local rows = math.ceil(#panel / cols)
    local row = math.floor((idx-1) / cols)
    local col = (idx-1) % cols
    if drow == 1 and row == rows-1 then return true end -- at bottom
    if drow == -1 and row == 0 then return true end -- at top
    if dcol == 1 and col == cols-1 then return true end -- at right edge
    if dcol == -1 and col == 0 then return true end -- at left edge
    return false
  end

  if self.focus == "player_inv" then
    if action == 'navigate_down' then
      if tryPanelEdgeNav(self.playerInventory, self.playerInvIdx, 1, 0, invW, invH) then
        self.focus = "player_offer"; self.lastPanelFocus = "player_inv"; return
      end
      self.playerInvIdx = nav(self.playerInvIdx, self.playerInventory, 1, 0, invW, invH)
    elseif action == 'navigate_up' then
      if tryPanelEdgeNav(self.playerInventory, self.playerInvIdx, -1, 0, invW, invH) then
        self.focus = "buttons"; self.buttonIdx = 1; self.lastPanelFocus = "player_inv"; return
      end
      self.playerInvIdx = nav(self.playerInvIdx, self.playerInventory, -1, 0, invW, invH)
    elseif action == 'navigate_right' then
      if tryPanelEdgeNav(self.playerInventory, self.playerInvIdx, 0, 1, invW, invH) then
        self.focus = "trader_inv"; self.lastPanelFocus = "player_inv"; return
      end
      self.playerInvIdx = nav(self.playerInvIdx, self.playerInventory, 0, 1, invW, invH)
    elseif action == 'navigate_left' then
      -- wrap to trader_inv if at left edge
      if tryPanelEdgeNav(self.playerInventory, self.playerInvIdx, 0, -1, invW, invH) then
        self.focus = "trader_inv"; self.lastPanelFocus = "player_inv"; return
      end
      self.playerInvIdx = nav(self.playerInvIdx, self.playerInventory, 0, -1, invW, invH)
    elseif action == 'switch_panel_next' then self.focus = "trader_inv"
    elseif action == 'activate' then
      local item = self.playerInventory[self.playerInvIdx]
      if item then
        if item.stackable and item.quantity and item.quantity > 1 then
          local offerItem = ItemModule.removeFromInventory(self.playerInventory, item.template, 1)
          if offerItem then
            ItemModule.addToInventory(self.playerOffer, offerItem)
          end
          self.playerInvIdx = math.max(1, math.min(self.playerInvIdx, #self.playerInventory))
        else
        table.remove(self.playerInventory, self.playerInvIdx)
          ItemModule.addToInventory(self.playerOffer, item)
        self.playerInvIdx = math.max(1, math.min(self.playerInvIdx, #self.playerInventory))
        end
      end
    end
  elseif self.focus == "trader_inv" then
    if action == 'navigate_down' then
      if tryPanelEdgeNav(self.traderInventory, self.traderInvIdx, 1, 0, invW, invH) then
        self.focus = "trader_offer"; self.lastPanelFocus = "trader_inv"; return
      end
      self.traderInvIdx = nav(self.traderInvIdx, self.traderInventory, 1, 0, invW, invH)
    elseif action == 'navigate_up' then
      if tryPanelEdgeNav(self.traderInventory, self.traderInvIdx, -1, 0, invW, invH) then
        self.focus = "buttons"; self.buttonIdx = 2; self.lastPanelFocus = "trader_inv"; return
      end
      self.traderInvIdx = nav(self.traderInvIdx, self.traderInventory, -1, 0, invW, invH)
    elseif action == 'navigate_left' then
      if tryPanelEdgeNav(self.traderInventory, self.traderInvIdx, 0, -1, invW, invH) then
        self.focus = "player_inv"; self.lastPanelFocus = "trader_inv"; return
      end
      self.traderInvIdx = nav(self.traderInvIdx, self.traderInventory, 0, -1, invW, invH)
    elseif action == 'navigate_right' then
      if tryPanelEdgeNav(self.traderInventory, self.traderInvIdx, 0, 1, invW, invH) then
        self.focus = "player_inv"; self.lastPanelFocus = "trader_inv"; return
      end
      self.traderInvIdx = nav(self.traderInvIdx, self.traderInventory, 0, 1, invW, invH)
    elseif action == 'switch_panel_next' then self.focus = "player_offer"
    elseif action == 'activate' then
      local item = self.traderInventory[self.traderInvIdx]
      if item then
        if item.stackable and item.quantity and item.quantity > 1 then
          local offerItem = ItemModule.removeFromInventory(self.traderInventory, item.template, 1)
          if offerItem then
            ItemModule.addToInventory(self.traderOffer, offerItem)
          end
          self.traderInvIdx = math.max(1, math.min(self.traderInvIdx, #self.traderInventory))
        else
        table.remove(self.traderInventory, self.traderInvIdx)
          ItemModule.addToInventory(self.traderOffer, item)
        self.traderInvIdx = math.max(1, math.min(self.traderInvIdx, #self.traderInventory))
        end
      end
    end
  elseif self.focus == "player_offer" then
    if action == 'navigate_up' then
      if tryPanelEdgeNav(self.playerOffer, self.playerOfferIdx, -1, 0, invW, offerH) then
        self.focus = "player_inv"; self.lastPanelFocus = "player_offer"; return
      end
      self.playerOfferIdx = nav(self.playerOfferIdx, self.playerOffer, -1, 0, invW, offerH)
    elseif action == 'navigate_down' then
      if tryPanelEdgeNav(self.playerOffer, self.playerOfferIdx, 1, 0, invW, offerH) then
        self.focus = "buttons"; self.buttonIdx = 1; self.lastPanelFocus = "player_offer"; return
      end
      self.playerOfferIdx = nav(self.playerOfferIdx, self.playerOffer, 1, 0, invW, offerH)
    elseif action == 'navigate_right' then
      if tryPanelEdgeNav(self.playerOffer, self.playerOfferIdx, 0, 1, invW, offerH) then
        self.focus = "trader_offer"; self.lastPanelFocus = "player_offer"; return
      end
      self.playerOfferIdx = nav(self.playerOfferIdx, self.playerOffer, 0, 1, invW, offerH)
    elseif action == 'navigate_left' then
      self.playerOfferIdx = nav(self.playerOfferIdx, self.playerOffer, 0, -1, invW, offerH)
    elseif action == 'switch_panel_next' then self.focus = "trader_offer"
    elseif action == 'activate' then
      local item = self.playerOffer[self.playerOfferIdx]
      if item then
        if item.stackable and item.quantity and item.quantity > 1 then
          local invItem = ItemModule.removeFromInventory(self.playerOffer, item.template, 1)
          if invItem then
            ItemModule.addToInventory(self.playerInventory, invItem)
          end
          self.playerOfferIdx = math.max(1, math.min(self.playerOfferIdx, #self.playerOffer))
        else
        table.remove(self.playerOffer, self.playerOfferIdx)
          ItemModule.addToInventory(self.playerInventory, item)
        self.playerOfferIdx = math.max(1, math.min(self.playerOfferIdx, #self.playerOffer))
        end
      end
    end
  elseif self.focus == "trader_offer" then
    if action == 'navigate_up' then
      if tryPanelEdgeNav(self.traderOffer, self.traderOfferIdx, -1, 0, invW, offerH) then
        self.focus = "trader_inv"; self.lastPanelFocus = "trader_offer"; return
      end
      self.traderOfferIdx = nav(self.traderOfferIdx, self.traderOffer, -1, 0, invW, offerH)
    elseif action == 'navigate_down' then
      if tryPanelEdgeNav(self.traderOffer, self.traderOfferIdx, 1, 0, invW, offerH) then
        self.focus = "buttons"; self.buttonIdx = 2; self.lastPanelFocus = "trader_offer"; return
      end
      self.traderOfferIdx = nav(self.traderOfferIdx, self.traderOffer, 1, 0, invW, offerH)
    elseif action == 'navigate_left' then
      if tryPanelEdgeNav(self.traderOffer, self.traderOfferIdx, 0, -1, invW, offerH) then
        self.focus = "player_offer"; self.lastPanelFocus = "trader_offer"; return
      end
      self.traderOfferIdx = nav(self.traderOfferIdx, self.traderOffer, 0, -1, invW, offerH)
    elseif action == 'navigate_right' then
      self.traderOfferIdx = nav(self.traderOfferIdx, self.traderOffer, 0, 1, invW, offerH)
    elseif action == 'switch_panel_next' then self.focus = "player_inv"
    elseif action == 'activate' then
      local item = self.traderOffer[self.traderOfferIdx]
      if item then
        if item.stackable and item.quantity and item.quantity > 1 then
          local invItem = ItemModule.removeFromInventory(self.traderOffer, item.template, 1)
          if invItem then
            ItemModule.addToInventory(self.traderInventory, invItem)
          end
          self.traderOfferIdx = math.max(1, math.min(self.traderOfferIdx, #self.traderOffer))
        else
        table.remove(self.traderOffer, self.traderOfferIdx)
          ItemModule.addToInventory(self.traderInventory, item)
        self.traderOfferIdx = math.max(1, math.min(self.traderOfferIdx, #self.traderOffer))
        end
      end
    end
  elseif self.focus == "buttons" then
    if action == 'navigate_left' then self.buttonIdx = math.max(1, self.buttonIdx - 1)
    elseif action == 'navigate_right' then self.buttonIdx = math.min(2, self.buttonIdx + 1)
    elseif action == 'navigate_up' then self.focus = self.lastPanelFocus or "player_inv"
    elseif action == 'activate' then
      if self.buttonIdx == 1 then
        -- Return all items in offers to their original inventories
        for i = #self.playerOffer, 1, -1 do
          local item = table.remove(self.playerOffer, i)
          ItemModule.addToInventory(self.playerInventory, item)
        end
        for i = #self.traderOffer, 1, -1 do
          local item = table.remove(self.traderOffer, i)
          ItemModule.addToInventory(self.traderInventory, item)
        end
        GameState:pop() -- Cancel
      elseif self.buttonIdx == 2 then -- Confirm
        -- Trade confirmation logic
        -- 1. Calculate gold balance BEFORE moving items
        local playerValue = self:getOfferValue(self.playerOffer)
        local traderValue = self:getOfferValue(self.traderOffer)
        local balance = playerValue - traderValue
        -- 2. Transfer trader's offered items to player
        for i = #self.traderOffer, 1, -1 do
          local item = table.remove(self.traderOffer, i)
          ItemModule.addToInventory(self.playerInventory, item)
        end
        -- 3. Transfer player's offered items to trader
        for i = #self.playerOffer, 1, -1 do
          local item = table.remove(self.playerOffer, i)
          ItemModule.addToInventory(self.traderInventory, item)
        end
        -- 4. Adjust gold
        if balance > 0 then
          -- Player receives gold
          self.playerParty.gold = (self.playerParty.gold or 0) + balance
          self.trader.gold = (self.trader.gold or 0) - balance
        elseif balance < 0 then
          -- Player pays gold
          self.playerParty.gold = (self.playerParty.gold or 0) + balance -- balance is negative
          self.trader.gold = (self.trader.gold or 0) - balance
        end
        GameState:pop()
      end
    end
  end
end

return TradingState 