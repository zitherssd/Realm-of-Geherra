-- Location module (was Town)
-- Handles location interaction menus and services

local ArmyUnit = require('src.army_unit')
local locationTypes = require('src.data.location_types')

local Location = {}

function Location:new()
    local instance = {
        currentLocation = nil,
        player = nil,
        menuState = "main",
        selectedIndex = 1,
        recruitableUnits = {},
        mainMenu = {},
        shopItems = {},
        tradeItems = {},
    }
    setmetatable(instance, {__index = self})
    return instance
end

function Location:enter(location, player)
    self.currentLocation = location
    self.player = player
    self.menuState = "main"
    self.selectedIndex = 1
    -- Set mainMenu based on location type options
    local options = locationTypes[location.type] and locationTypes[location.type].options or {}
    self.mainMenu = options
    -- Precompute recruitableUnits, shopItems, tradeItems for each option
    for _, opt in ipairs(options) do
        if opt.action == "recruit" then
            self.recruitableUnits = opt.units or {}
        elseif opt.action == "shop" then
            self.shopItems = opt.items or {}
        elseif opt.action == "trade" then
            self.tradeItems = opt.items or {}
        end
    end
    print("Entered " .. location.name)
end

function Location:generateRecruitableUnits()
    self.recruitableUnits = {}
    
    -- Use locationTypes for location/settlement type definitions instead of local tables.
    local unitsByLocationType = locationTypes.unitsByType
    
    local availableUnits = unitsByLocationType[self.currentLocation.type] or {"Peasant"}
    
    for _, unitType in ipairs(availableUnits) do
        local unitInfo = ArmyUnit.getTypeInfo(unitType)
        table.insert(self.recruitableUnits, {
            type = unitType,
            cost = unitInfo.cost,
            description = unitInfo.description
        })
    end
end

function Location:update(dt)
    -- Location-specific updates can go here
end

function Location:draw()
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw location header
    love.graphics.setColor(1, 1, 1)
    local headerText = self.currentLocation.name .. " (" .. self.currentLocation.type .. ")"
    love.graphics.print(headerText, 50, 50, 0, 2, 2)
    
    -- Draw location description
    love.graphics.print(self.currentLocation.description, 50, 100)
    love.graphics.print("Population: " .. self.currentLocation.population, 50, 120)
    
    -- Draw current menu
    if self.menuState == "main" then
        self:drawMainMenu()
    elseif self.menuState == "recruit" then
        self:drawRecruitMenu()
    elseif self.menuState == "shop" then
        self:drawShopMenu()
    elseif self.menuState == "trade" then
        self:drawTradeMenu()
    elseif self.menuState == "tavern" then
        self:drawTavernMenu()
    elseif self.menuState == "info" then
        self:drawInfoMenu()
    end
    
    -- Draw player stats
    self:drawPlayerStats()
    
    -- Draw instructions
    love.graphics.print("Use UP/DOWN to navigate, ENTER to select, ESC to go back", 50, love.graphics.getHeight() - 50)
end

function Location:drawMainMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Location Menu:", 50, 160)
    for i, option in ipairs(self.mainMenu) do
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        love.graphics.setColor(color)
        local prefix = (i == self.selectedIndex and "> " or "  ")
        love.graphics.print(prefix .. option.label, 70, 180 + i * 25)
    end
end

function Location:drawRecruitMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Recruit Units:", 50, 160)
    local playerGold = self.player:getStats().gold
    love.graphics.print("Your Gold: " .. playerGold, 50, 180)
    for i, unitType in ipairs(self.recruitableUnits) do
        local unitInfo = ArmyUnit.getTypeInfo(unitType)
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        if playerGold < unitInfo.cost then
            color = {0.5, 0.5, 0.5}
        end
        love.graphics.setColor(color)
        local prefix = (i == self.selectedIndex) and "> " or "  "
        local text = string.format("%s%s - %d gold", prefix, unitType, unitInfo.cost)
        love.graphics.print(text, 70, 200 + i * 25)
        if i == self.selectedIndex then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("    " .. (unitInfo.description or ""), 90, 220 + i * 25)
        end
    end
end

function Location:drawShopMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Shop:", 50, 160)
    local playerGold = self.player:getStats().gold
    love.graphics.print("Your Gold: " .. playerGold, 50, 180)
    for i, itemName in ipairs(self.shopItems) do
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        -- For now, just display item name; you can expand with item data
        love.graphics.setColor(color)
        local prefix = (i == self.selectedIndex) and "> " or "  "
        local text = string.format("%s%s", prefix, itemName)
        love.graphics.print(text, 70, 200 + i * 25)
    end
end

function Location:drawTradeMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Trade:", 50, 160)
    for i, itemName in ipairs(self.tradeItems) do
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        love.graphics.setColor(color)
        local prefix = (i == self.selectedIndex) and "> " or "  "
        local text = string.format("%s%s", prefix, itemName)
        love.graphics.print(text, 70, 200 + i * 25)
    end
end

function Location:drawTavernMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tavern:", 50, 160)
    love.graphics.print("The tavern is bustling with activity.", 50, 200)
    love.graphics.print("You hear rumors of distant lands and treasures.", 50, 220)
    love.graphics.print("(Future: Quests, information, recruitment)", 50, 260)
end

function Location:drawInfoMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Location Information:", 50, 160)
    
    local info = {
        "Name: " .. self.currentLocation.name,
        "Type: " .. self.currentLocation.type,
        "Population: " .. self.currentLocation.population,
        "Description: " .. self.currentLocation.description,
        "",
        "Available Services:",
        "- Unit Recruitment",
        "- Basic Shop",
        "- Tavern (Information)"
    }
    
    for i, line in ipairs(info) do
        love.graphics.print(line, 50, 180 + i * 20)
    end
end

function Location:drawPlayerStats()
    -- Draw player info on the right side
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', love.graphics.getWidth() - 250, 50, 200, 200)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Player Stats:", love.graphics.getWidth() - 240, 60)
    
    local stats = self.player:getStats()
    local statTexts = {
        "Gold: " .. stats.gold,
        "Strength: " .. stats.strength,
        "Agility: " .. stats.agility,
        "Vitality: " .. stats.vitality,
        "Leadership: " .. stats.leadership,
        "",
        "Army Size: " .. #self.player.army,
        "Army Strength: " .. self.player:getArmyStrength()
    }
    
    for i, text in ipairs(statTexts) do
        love.graphics.print(text, love.graphics.getWidth() - 240, 80 + i * 15)
    end
end

function Location:keypressed(key)
    if key == 'up' then
        self:navigateUp()
    elseif key == 'down' then
        self:navigateDown()
    elseif key == 'return' then
        self:selectOption()
    elseif key == 'escape' then
        self:goBack()
    end
end

function Location:navigateUp()
    if self.menuState == "main" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
    elseif self.menuState == "recruit" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
    elseif self.menuState == "shop" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
    end
end

function Location:navigateDown()
    if self.menuState == "main" then
        self.selectedIndex = math.min(#self.mainMenu, self.selectedIndex + 1)
    elseif self.menuState == "recruit" then
        self.selectedIndex = math.min(#self.recruitableUnits, self.selectedIndex + 1)
    elseif self.menuState == "shop" then
        self.selectedIndex = math.min(#self.shopItems, self.selectedIndex + 1)
    end
end

function Location:selectOption()
    if self.menuState == "main" then
        local option = self.mainMenu[self.selectedIndex]
        if option.action == "recruit" then
            self.menuState = "recruit"
            self.selectedIndex = 1
        elseif option.action == "shop" then
            self.menuState = "shop"
            self.selectedIndex = 1
        elseif option.action == "trade" then
            self.menuState = "trade"
            self.selectedIndex = 1
        elseif option.action == "tavern" then
            self.menuState = "tavern"
            self.selectedIndex = 1
        elseif option.action == "info" then
            self.menuState = "info"
            self.selectedIndex = 1
        elseif option.action == "leave" then
            self:leave()
        end
    end
end

function Location:recruitUnit()
    if self.selectedIndex <= #self.recruitableUnits then
        local unit = self.recruitableUnits[self.selectedIndex]
        
        -- Check if player has enough gold
        if self.player:spendGold(unit.cost) then
            -- Check if player can lead more units
            if #self.player.army < self.player:canLeadUnits() then
                self.player:addUnit(unit.type)
                print("Recruited " .. unit.type .. " for " .. unit.cost .. " gold")
            else
                -- Refund gold if can't lead more units
                self.player:addGold(unit.cost)
                print("Cannot recruit more units. Leadership limit reached.")
            end
        else
            print("Not enough gold to recruit " .. unit.type)
        end
    end
end

function Location:buyItem()
    if self.selectedIndex <= #self.shopItems then
        local item = self.shopItems[self.selectedIndex]
        
        if self.player:spendGold(item.price) then
            -- Basic item effects
            if item.name == "Health Potion" then
                -- Heal army units
                for _, unit in ipairs(self.player.army) do
                    unit:heal(10)
                end
                print("Used Health Potion - Army healed")
            elseif item.name == "Weapon Upgrade" then
                self.player:increasestat("strength", 1)
                print("Weapon upgraded - Strength increased")
            elseif item.name == "Armor Upgrade" then
                self.player:increasestat("vitality", 1)
                print("Armor upgraded - Vitality increased")
            end
        else
            print("Not enough gold to buy " .. item.name)
        end
    end
end

function Location:goBack()
    if self.menuState == "main" then
        self:leave()
    else
        self.menuState = "main"
        self.selectedIndex = 1
    end
end

function Location:leave()
    -- This will be handled by the Game module
    print("Leaving " .. self.currentLocation.name)
end

function Location:mousepressed(x, y, button)
    -- Future: Add mouse support for menus
end

function Location:mousereleased(x, y, button)
    -- Future: Add mouse support for menus
end

return Location