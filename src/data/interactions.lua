local GameState = require('src.game.GameState')
local PartyManagementState = require('src.game.ui.states.PartyManagementState')
local TradingState = require('src.game.ui.states.TradingState')
local BattleState = require('src.game.battle.BattleState')
local PartyModule = require('src.game.modules.PartyModule')
local PlayerModule = require('src.game.modules.PlayerModule')
local ItemModule = require('src.game.modules.ItemModule')
local stages = require('src.data.stages')
local UnitModule = require('src.game.modules.UnitModule')
local TimeModule = require('src.game.modules.TimeModule')
local PartyInventoryState = require('src.game.ui.states.PartyInventoryState')

local interactions = {
  armyInspect = {
    label = "Inspect Army",
    action = function(context)
      GameState:push(PartyManagementState)
    end
  },
  equipmentInspect = {
    label = "Inspect Equipment",
    action = function(context)
      GameState:push(PartyInventoryState)
    end
  },
  wait = {
    label = "Wait",
    action = function(context)
      print("You wait for a while.")
    end
  },
  leaveCamp = {
    label = "Leave Camp",
    action = function(context)
      if context and context.closeMenu then context.closeMenu() end
    end
  },
  trade = {
    label = "Trade",
    action = function(context)
      if context and context.target then
        GameState:push(TradingState, context.target)
      end
    end
  },
  fight = {
    label = "Fight",
    action = function(context)
      if context and context.target then
        local playerParty = PlayerModule:getPlayerParty()
        local enemyParty = context.target
        GameState:push(BattleState, playerParty, enemyParty, stages.default)
      end
    end
  },
  trade_fishing_village = {
    label = "Trade (Fishing Village)",
    action = function(context)
      local trader = context.target
      if not trader.stock then
        trader.stock = {
          ItemModule.create("fish", 10),
          ItemModule.create("bread", 5),
          ItemModule.create("cheese", 2),
        }
      end
      GameState:push(TradingState, trader)
    end
  },
  recruit_village = {
    label = "Recruit",
    action = function(context)
      local loc = context and context.target
      if not loc then return end
      -- If on cooldown, defer message to caller
      if loc._recruitCooldownUntilDay and TimeModule:getDay() < loc._recruitCooldownUntilDay then
        if context.showMessage then
          context.showMessage("The villagers are not ready to recruit again yet.", {
            { label = "Close", action = function() end }
          })
        end
        return
      end

      local roll = love.math.random(1,100)
      local recruitedUnits = {}
      if roll < 35 then
        recruitedUnits = UnitModule.createMultiple("peasant", love.math.random(2,5))
      elseif roll > 75 then
        recruitedUnits = UnitModule.createMultiple("militia", love.math.random(2,4))
      end

      -- Set cooldown for at least 3 days after attempt
      loc._recruitCooldownUntilDay = TimeModule:getDay() + 3

      if #recruitedUnits > 0 then
        local unitName = (recruitedUnits[1] and recruitedUnits[1].name) or "units"
        if context.showMessage then
          context.showMessage("You recruit " .. #recruitedUnits .. " " .. unitName .. ".", {
            {
              label = "Recruit",
              action = function()
                for _, unit in ipairs(recruitedUnits) do
                  PartyModule.addUnit(unit)
                end
              end
            },
            { label = "Cancel", action = function() end }
          })
        end
      else
        if context.showMessage then
          context.showMessage("You didn't manage to recruit anyone.", {
            { label = "Close", action = function() end }
          })
        end
      end
    end
  },
  recruit_castle = {
    label = "Recruit",
    action = function(context)
      local loc = context and context.target
      if not loc then return end
      -- If on cooldown, defer message to caller
      if loc._recruitCooldownUntilDay and TimeModule:getDay() < loc._recruitCooldownUntilDay then
        if context.showMessage then
          context.showMessage("The villagers are not ready to recruit again yet.", {
            { label = "Close", action = function() end }
          })
        end
        return
      end

      local roll = love.math.random(1,100)
      local recruitedUnits = {}
      if roll < 35 then
        recruitedUnits = UnitModule.createMultiple("knight", love.math.random(1,3))
      elseif roll > 75 then
        recruitedUnits = UnitModule.createMultiple("militia", love.math.random(3,5))
      end

      -- Set cooldown for at least 3 days after attempt
      loc._recruitCooldownUntilDay = TimeModule:getDay() + 3

      if #recruitedUnits > 0 then
        local unitName = (recruitedUnits[1] and recruitedUnits[1].name) or "units"
        if context.showMessage then
          context.showMessage("You recruit " .. #recruitedUnits .. " " .. unitName .. ".", {
            {
              label = "Recruit",
              action = function()
                for _, unit in ipairs(recruitedUnits) do
                  PartyModule.addUnit(unit)
                end
              end
            },
            { label = "Cancel", action = function() end }
          })
        end
      else
        if context.showMessage then
          context.showMessage("You didn't manage to recruit anyone.", {
            { label = "Close", action = function() end }
          })
        end
      end
    end
  }


  -- Add more interactions as needed
}

-- Special camping/campfire table
interactions.camp = {
  name = "Camp",
  interactions = {"equipmentInspect", "armyInspect", "wait", }
}

return interactions 