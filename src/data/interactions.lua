local GameState = require('src.game.GameState')
local PartyManagementState = require('src.game.ui.states.PartyManagementState')
local TradingState = require('src.game.ui.states.TradingState')
local GridBattleState = require('src.game.GridBattleState')
local PartyModule = require('src.game.modules.PartyModule')
local PlayerModule = require('src.game.modules.PlayerModule')
local ItemModule = require('src.game.modules.ItemModule')
local stages = require('src.data.stages')

local interactions = {
  armyInspect = {
    label = "Inspect Army",
    action = function(context)
      GameState:push(PartyManagementState)
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
        local playerParty = PlayerModule.getPlayerParty()
        local enemyParty = context.target
        local defaultStage = {} -- You can expand this later
        GameState:push(GridBattleState:new(), playerParty, enemyParty, stages.default)
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
  -- Add more interactions as needed
}

-- Special camping/campfire table
interactions.camp = {
  name = "Camp",
  interactions = {"armyInspect", "wait"}
}

return interactions 