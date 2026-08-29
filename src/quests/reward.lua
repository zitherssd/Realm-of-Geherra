-- quests/reward.lua
-- Quest reward definitions

local Reward = {}

function Reward.new(rewardType)
    local self = {
        type = rewardType or "gold",
        amount = 0,
        items = {},
        reputation = {},
        unlocks = {}
    }
    return self
end

function Reward:addGold(amount)
    self.amount = self.amount + amount
end

function Reward:addItem(itemId, quantity)
    self.items[itemId] = (self.items[itemId] or 0) + quantity
end

function Reward:addReputation(factionId, amount)
    self.reputation[factionId] = (self.reputation[factionId] or 0) + amount
end

function Reward:addUnlock(unlockId)
    table.insert(self.unlocks, unlockId)
end

return Reward
