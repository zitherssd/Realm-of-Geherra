-- Town module
-- Handles town interaction menus and services

local ArmyUnit = require('src.army_unit')

local Town = {}

function Town:new()
    local instance = {
        currentTown = nil,
        party = nil,
        menuState = "main", -- "main", "recruit", "shop", "tavern", "info"
        selectedIndex = 1,
        recruitableUnits = {},
        
        -- Menu options
        mainMenu = {
            {text = "Recruit Units", action = "recruit"},
            {text = "Shop", action = "shop"},
            {text = "Tavern", action = "tavern"},
            {text = "Town Info", action = "info"},
            {text = "Leave Town", action = "leave"}
        },
        
        -- Shop items (basic implementation)
        shopItems = {
            {name = "Health Potion", price = 20, description = "Restores health"},
            {name = "Weapon Upgrade", price = 50, description = "Improves weapon"},
            {name = "Armor Upgrade", price = 75, description = "Improves armor"}
        }
    }
    
    setmetatable(instance, {__index = self})
    return instance
end

function Town:enter(town, party)
    self.currentTown = town
    self.party = party
    self.menuState = "main"
    self.selectedIndex = 1
    
    -- Generate recruitable units based on town type
    self:generateRecruitableUnits()
    
    print("Entered " .. town.name)
end

function Town:generateRecruitableUnits()
    self.recruitableUnits = {}
    
    -- Different town types offer different units
    local unitsByTownType = {
        village = {"Peasant", "Militia"},
        city = {"Militia", "Soldier", "Archer"},
        port = {"Soldier", "Archer", "Crossbowman"},
        fortress = {"Soldier", "Knight", "Crossbowman"}
    }
    
    local availableUnits = unitsByTownType[self.currentTown.type] or {"Peasant"}
    
    for _, unitType in ipairs(availableUnits) do
        local unitInfo = ArmyUnit.getTypeInfo(unitType)
        table.insert(self.recruitableUnits, {
            type = unitType,
            cost = unitInfo.cost,
            description = unitInfo.description
        })
    end
end

function Town:update(dt)
    -- Town-specific updates can go here
end

function Town:draw()
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw town header
    love.graphics.setColor(1, 1, 1)
    local headerText = self.currentTown.name .. " (" .. self.currentTown.type .. ")"
    love.graphics.print(headerText, 50, 50, 0, 2, 2)
    
    -- Draw town description
    love.graphics.print(self.currentTown.description, 50, 100)
    love.graphics.print("Population: " .. self.currentTown.population, 50, 120)
    
    -- Draw current menu
    if self.menuState == "main" then
        self:drawMainMenu()
    elseif self.menuState == "recruit" then
        self:drawRecruitMenu()
    elseif self.menuState == "shop" then
        self:drawShopMenu()
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

function Town:drawMainMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Town Menu:", 50, 160)
    
    for i, option in ipairs(self.mainMenu) do
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        love.graphics.setColor(color)
        love.graphics.print((i == self.selectedIndex and "> " or "  ") .. option.text, 70, 180 + i * 25)
    end
end

function Town:drawRecruitMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Recruit Units:", 50, 160)
    
    local playerGold = self.party:getStats().gold
    love.graphics.print("Your Gold: " .. playerGold, 50, 180)
    
    for i, unit in ipairs(self.recruitableUnits) do
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        if playerGold < unit.cost then
            color = {0.5, 0.5, 0.5} -- Gray out unaffordable units
        end
        
        love.graphics.setColor(color)
        local prefix = (i == self.selectedIndex) and "> " or "  "
        local text = string.format("%s%s - %d gold", prefix, unit.type, unit.cost)
        love.graphics.print(text, 70, 200 + i * 25)
        
        -- Show description for selected unit
        if i == self.selectedIndex then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("    " .. unit.description, 90, 220 + i * 25)
        end
    end
end

function Town:drawShopMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Shop:", 50, 160)
    
    local playerGold = self.party:getStats().gold
    love.graphics.print("Your Gold: " .. playerGold, 50, 180)
    
    for i, item in ipairs(self.shopItems) do
        local color = (i == self.selectedIndex) and {1, 1, 0} or {1, 1, 1}
        if playerGold < item.price then
            color = {0.5, 0.5, 0.5}
        end
        
        love.graphics.setColor(color)
        local prefix = (i == self.selectedIndex) and "> " or "  "
        local text = string.format("%s%s - %d gold", prefix, item.name, item.price)
        love.graphics.print(text, 70, 200 + i * 25)
        
        if i == self.selectedIndex then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("    " .. item.description, 90, 220 + i * 25)
        end
    end
end

function Town:drawTavernMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tavern:", 50, 160)
    love.graphics.print("The tavern is bustling with activity.", 50, 200)
    love.graphics.print("You hear rumors of distant lands and treasures.", 50, 220)
    love.graphics.print("(Future: Quests, information, recruitment)", 50, 260)
end

function Town:drawInfoMenu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Town Information:", 50, 160)
    
    local info = {
        "Name: " .. self.currentTown.name,
        "Type: " .. self.currentTown.type,
        "Population: " .. self.currentTown.population,
        "Description: " .. self.currentTown.description,
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

function Town:drawPlayerStats()
    -- Draw party info on the right side
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', love.graphics.getWidth() - 250, 50, 200, 200)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Party Stats:", love.graphics.getWidth() - 240, 60)
    
    local stats = {
        "Morale: " .. (self.party.morale or 0),
        "Movement Speed: " .. (self.party.movement_speed or 0),
        "Healing Rate: " .. (self.party.healing_rate or 0),
        "Biome: " .. (self.party.current_biome or 'unknown'),
        "",
        -- Add more party stats as needed
    }
    
    for i, text in ipairs(stats) do
        love.graphics.print(text, love.graphics.getWidth() - 240, 80 + i * 15)
    end
end

function Town:keypressed(key)
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

function Town:navigateUp()
    if self.menuState == "main" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
    elseif self.menuState == "recruit" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
    elseif self.menuState == "shop" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
    end
end

function Town:navigateDown()
    if self.menuState == "main" then
        self.selectedIndex = math.min(#self.mainMenu, self.selectedIndex + 1)
    elseif self.menuState == "recruit" then
        self.selectedIndex = math.min(#self.recruitableUnits, self.selectedIndex + 1)
    elseif self.menuState == "shop" then
        self.selectedIndex = math.min(#self.shopItems, self.selectedIndex + 1)
    end
end

function Town:selectOption()
    if self.menuState == "main" then
        local option = self.mainMenu[self.selectedIndex]
        if option.action == "recruit" then
            self.menuState = "recruit"
            self.selectedIndex = 1
        elseif option.action == "shop" then
            self.menuState = "shop"
            self.selectedIndex = 1
        elseif option.action == "tavern" then
            self.menuState = "tavern"
        elseif option.action == "info" then
            self.menuState = "info"
        elseif option.action == "leave" then
            self:leave()
        end
    elseif self.menuState == "recruit" then
        self:recruitUnit()
    elseif self.menuState == "shop" then
        self:buyItem()
    end
end

function Town:recruitUnit()
    if self.selectedIndex <= #self.recruitableUnits then
        local unit = self.recruitableUnits[self.selectedIndex]
        
        -- Check if party has enough gold
        if self.party:spendGold(unit.cost) then
            -- Check if party can lead more units
            if #self.party.army < self.party:canLeadUnits() then
                self.party:addUnit(unit.type)
                print("Recruited " .. unit.type .. " for " .. unit.cost .. " gold")
            else
                -- Refund gold if can't lead more units
                self.party:addGold(unit.cost)
                print("Cannot recruit more units. Leadership limit reached.")
            end
        else
            print("Not enough gold to recruit " .. unit.type)
        end
    end
end

function Town:buyItem()
    if self.selectedIndex <= #self.shopItems then
        local item = self.shopItems[self.selectedIndex]
        
        if self.party:spendGold(item.price) then
            -- Basic item effects
            if item.name == "Health Potion" then
                -- Heal army units
                for _, unit in ipairs(self.party.army) do
                    unit:heal(10)
                end
                print("Used Health Potion - Army healed")
            elseif item.name == "Weapon Upgrade" then
                self.party:increasestat("strength", 1)
                print("Weapon upgraded - Strength increased")
            elseif item.name == "Armor Upgrade" then
                self.party:increasestat("vitality", 1)
                print("Armor upgraded - Vitality increased")
            end
        else
            print("Not enough gold to buy " .. item.name)
        end
    end
end

function Town:goBack()
    if self.menuState == "main" then
        self:leave()
    else
        self.menuState = "main"
        self.selectedIndex = 1
    end
end

function Town:leave()
    -- This will be handled by the Game module
    print("Leaving " .. self.currentTown.name)
end

function Town:mousepressed(x, y, button)
    -- Future: Add mouse support for menus
end

function Town:mousereleased(x, y, button)
    -- Future: Add mouse support for menus
end

return Town