local GameState = require('src.game.GameState')
local PartyManagementState = require('src.game.ui.states.PartyManagementState')
local TradingState = require('src.game.ui.states.TradingState')

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
        print("You start a battle with " .. (context.target.name or "an enemy party") .. ".")
        -- Here you would push your BattleState, e.g.:
        -- GameState:push(BattleState, context.target)
      end
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