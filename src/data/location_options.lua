-- src/data/location_options.lua
-- Defines reusable option templates for locations

local locationOptions = {
    recruit_soldiers = {
        action = "recruit",
        label = "Recruit Soldiers",
        units = {"Soldier", "Knight"}
    },
    recruit_villagers = {
        action = "recruit",
        label = "Recruit Villagers",
        units = {"Peasant", "Militia"}
    },
    shop_basic = {
        action = "shop",
        label = "Shop",
        items = {"Health Potion", "Weapon Upgrade", "Armor Upgrade"}
    },
    trade_goods = {
        action = "trade",
        label = "Trade Goods",
        items = {"Grain", "Wool"}
    },
    tavern = {
        action = "tavern",
        label = "Tavern"
    },
    info = {
        action = "info",
        label = "Location Info"
    },
    leave = {
        action = "leave",
        label = "Leave Location"
    }
}

return locationOptions