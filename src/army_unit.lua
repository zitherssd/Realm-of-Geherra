-- ArmyUnit module
-- Handles different unit types with stats and equipment

local ArmyUnit = {}

-- Unit type definitions
local unitTypes = require('src.data.unit_types')
local Inventory = require('src.inventory')

function ArmyUnit:new(unitType)
    local template = unitTypes[unitType]
    if not template then
        error("Unknown unit type: " .. tostring(unitType))
    end
    
    local instance = {
        type = unitType,
        attack = template.attack,
        defense = template.defense,
        maxHealth = template.health,
        currentHealth = template.health,
        attack_damage = template.attack, -- Add this for battle logic
        attack_range = template.attack_range or 30, -- Default if not present
        cost = template.cost,
        description = template.description,
        
        -- Equipment
        equipment = {
            main_hand = nil,
            off_hand = nil,
            body = nil,
            head = nil,
            accessory = nil
        },
        
        -- Status effects (for future expansion)
        statusEffects = {},
        
        -- Experience/Level system (for future expansion)
        experience = 0,
        level = 1
    }
    
    setmetatable(instance, {__index = self})
    return instance
end

function ArmyUnit:getCombatRating()
    -- Calculate overall combat effectiveness
    local healthRatio = self.currentHealth / self.maxHealth
    return math.floor((self.attack + self.defense) * healthRatio)
end

function ArmyUnit:getInfo()
    return {
        type = self.type,
        attack = self.attack,
        defense = self.defense,
        health = self.currentHealth .. "/" .. self.maxHealth,
        weapon = self.weapon,
        armor = self.armor,
        description = self.description,
        combatRating = self:getCombatRating()
    }
end

function ArmyUnit:takeDamage(damage)
    self.currentHealth = math.max(0, self.currentHealth - damage)
    return self.currentHealth <= 0
end

function ArmyUnit:heal(amount)
    self.currentHealth = math.min(self.maxHealth, self.currentHealth + amount)
end

function ArmyUnit:isAlive()
    return self.currentHealth > 0
end

function ArmyUnit:equipItem(player, item)
    Inventory.equipItem(player, self, item)
end

function ArmyUnit:unequipItem(player, slot)
    Inventory.unequipItem(player, self, slot)
end

function ArmyUnit:addExperience(exp)
    -- For future expansion - experience system
    self.experience = self.experience + exp
    
    -- Simple level up system
    local expForNextLevel = self.level * 100
    if self.experience >= expForNextLevel then
        self.level = self.level + 1
        self.experience = self.experience - expForNextLevel
        
        -- Increase stats on level up
        self.attack = self.attack + 1
        self.defense = self.defense + 1
        self.maxHealth = self.maxHealth + 5
        self.currentHealth = self.maxHealth
        
        return true -- Level up occurred
    end
    
    return false
end

function ArmyUnit:getUpgradeCost()
    -- Cost to upgrade this unit to next tier
    local upgradePaths = {
        ["Peasant"] = {next = "Militia", cost = 10},
        ["Militia"] = {next = "Soldier", cost = 20},
        ["Soldier"] = {next = "Knight", cost = 75},
        ["Archer"] = {next = "Crossbowman", cost = 20}
    }
    
    return upgradePaths[self.type]
end

function ArmyUnit:upgrade()
    local upgradeInfo = self:getUpgradeCost()
    if upgradeInfo then
        -- Create new unit of upgraded type
        local upgradedUnit = ArmyUnit:new(upgradeInfo.next)
        
        -- Transfer some experience
        upgradedUnit.experience = math.floor(self.experience / 2)
        
        return upgradedUnit
    end
    
    return nil
end

function ArmyUnit:getTotalStats()
    local total = {attack = self.attack, defense = self.defense, health = self.maxHealth}
    for _, item in pairs(self.equipment) do
        if item and item.stats then
            for k, v in pairs(item.stats) do
                total[k] = (total[k] or 0) + v
            end
        end
    end
    return total
end

-- Static function to get all available unit types
function ArmyUnit.getAvailableTypes()
    local types = {}
    for unitType, _ in pairs(unitTypes) do
        table.insert(types, unitType)
    end
    return types
end

-- Static function to get unit type info
function ArmyUnit.getTypeInfo(unitType)
    return unitTypes[unitType]
end

return ArmyUnit