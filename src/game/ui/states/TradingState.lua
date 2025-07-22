local TradingState = {}

local PartyModule = require('src.game.modules.PartyModule')
local GameState = require('src.game.GameState')
local InputModule = require('src.game.modules.InputModule')

function TradingState:enter(tradingPartner)
  self.playerParty = PartyModule.parties[1]
  if not self.playerParty.gold then self.playerParty.gold = 500 end
  self.trader = tradingPartner

  self.playerInventory = self.playerParty.inventory or {}
  self.traderInventory = self.trader.inventory or {}
  self.playerOffer = {}
  self.traderOffer = {}
  self.goldOffer = 0

  self.focus = "player_inv"
  self.playerInvIdx = 1
  self.traderInvIdx = 1
  self.playerOfferIdx = 1
  self.traderOfferIdx = 1
end

function TradingState:update(dt)
end

function TradingState:draw()
  local w, h = 640, 480
  love.graphics.clear(0.12, 0.12, 0.15, 1)

  love.graphics.printf("Your Inventory", 20, 20, 280, 'left')
  love.graphics.printf(self.trader.name .. "'s Goods", 340, 20, 280, 'left')

  love.graphics.setColor(0.2, 0.15, 0.15, 0.95)
  love.graphics.rectangle('fill', 20, 40, 280, 120, 8, 8)
  for i, item in ipairs(self.playerInventory) do
    local y = 44 + (i-1)*22
    if self.focus == "player_inv" and i == self.playerInvIdx then
      love.graphics.setColor(1, 1, 0, 0.4)
      love.graphics.rectangle('fill', 24, y-2, 272, 20, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(item.name .. (item.quantity and (" x"..item.quantity) or ""), 28, y, 260, 'left')
  end

  love.graphics.setColor(0.15, 0.2, 0.15, 0.95)
  love.graphics.rectangle('fill', 340, 40, 280, 120, 8, 8)
  for i, item in ipairs(self.traderInventory) do
    local y = 44 + (i-1)*22
    if self.focus == "trader_inv" and i == self.traderInvIdx then
      love.graphics.setColor(1, 1, 0, 0.4)
      love.graphics.rectangle('fill', 344, y-2, 272, 20, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(item.name .. (item.quantity and (" x"..item.quantity) or ""), 348, y, 260, 'left')
  end

  love.graphics.printf("Your Offer", 20, 170, 280, 'left')
  love.graphics.setColor(0.2, 0.18, 0.18, 0.95)
  love.graphics.rectangle('fill', 20, 190, 280, 80, 8, 8)
  for i, item in ipairs(self.playerOffer) do
    local y = 194 + (i-1)*22
    if self.focus == "player_offer" and i == self.playerOfferIdx then
      love.graphics.setColor(1, 1, 0, 0.4)
      love.graphics.rectangle('fill', 24, y-2, 272, 20, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(item.name .. (item.quantity and (" x"..item.quantity) or ""), 28, y, 260, 'left')
  end

  love.graphics.printf("Their Offer", 340, 170, 280, 'left')
  love.graphics.setColor(0.18, 0.2, 0.18, 0.95)
  love.graphics.rectangle('fill', 340, 190, 280, 80, 8, 8)
  for i, item in ipairs(self.traderOffer) do
    local y = 194 + (i-1)*22
    if self.focus == "trader_offer" and i == self.traderOfferIdx then
      love.graphics.setColor(1, 1, 0, 0.4)
      love.graphics.rectangle('fill', 344, y-2, 272, 20, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(item.name .. (item.quantity and (" x"..item.quantity) or ""), 348, y, 260, 'left')
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Your Gold: " .. self.playerParty.gold, 20, h - 30, w, 'left')
  love.graphics.printf("Balance: " .. self.goldOffer .. " gold", 240, h-50, 160, 'center')
  love.graphics.rectangle('line', 240, h-30, 80, 24)
  love.graphics.printf("Cancel", 240, h-26, 80, 'center')
  love.graphics.rectangle('line', 320, h-30, 80, 24)
  love.graphics.printf("Confirm", 320, h-26, 80, 'center')
end

function TradingState:keypressed(key)
  InputModule:handleKeyEvent(key, self)
end

function TradingState:onAction(action)
  if action == 'cancel' then GameState:pop() return end

  if self.focus == "player_inv" then
    if action == 'navigate_down' then self.playerInvIdx = math.min(#self.playerInventory, self.playerInvIdx + 1)
    elseif action == 'navigate_up' then self.playerInvIdx = math.max(1, self.playerInvIdx - 1)
    elseif action == 'switch_panel_next' then self.focus = "trader_inv"
    elseif action == 'activate' then
      local item = self.playerInventory[self.playerInvIdx]
      if item then
        table.insert(self.playerOffer, item)
        table.remove(self.playerInventory, self.playerInvIdx)
        self.playerInvIdx = math.max(1, math.min(self.playerInvIdx, #self.playerInventory))
      end
    end
  elseif self.focus == "trader_inv" then
    if action == 'navigate_down' then self.traderInvIdx = math.min(#self.traderInventory, self.traderInvIdx + 1)
    elseif action == 'navigate_up' then self.traderInvIdx = math.max(1, self.traderInvIdx - 1)
    elseif action == 'switch_panel_next' then self.focus = "player_offer"
    elseif action == 'activate' then
      local item = self.traderInventory[self.traderInvIdx]
      if item then
        table.insert(self.traderOffer, item)
        table.remove(self.traderInventory, self.traderInvIdx)
        self.traderInvIdx = math.max(1, math.min(self.traderInvIdx, #self.traderInventory))
      end
    end
  elseif self.focus == "player_offer" then
    if action == 'navigate_down' then self.playerOfferIdx = math.min(#self.playerOffer, self.playerOfferIdx + 1)
    elseif action == 'navigate_up' then self.playerOfferIdx = math.max(1, self.playerOfferIdx - 1)
    elseif action == 'switch_panel_next' then self.focus = "trader_offer"
    elseif action == 'activate' then
      local item = self.playerOffer[self.playerOfferIdx]
      if item then
        table.insert(self.playerInventory, item)
        table.remove(self.playerOffer, self.playerOfferIdx)
        self.playerOfferIdx = math.max(1, math.min(self.playerOfferIdx, #self.playerOffer))
      end
    end
  elseif self.focus == "trader_offer" then
    if action == 'navigate_down' then self.traderOfferIdx = math.min(#self.traderOffer, self.traderOfferIdx + 1)
    elseif action == 'navigate_up' then self.traderOfferIdx = math.max(1, self.traderOfferIdx - 1)
    elseif action == 'switch_panel_next' then self.focus = "player_inv"
    elseif action == 'activate' then
      local item = self.traderOffer[self.traderOfferIdx]
      if item then
        table.insert(self.traderInventory, item)
        table.remove(self.traderOffer, self.traderOfferIdx)
        self.traderOfferIdx = math.max(1, math.min(self.traderOfferIdx, #self.traderOffer))
      end
    end
  end
end

return TradingState 