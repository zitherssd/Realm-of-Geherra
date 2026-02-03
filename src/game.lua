local GameState = require('src.game.GameState')
local OverworldState = require('src.game.overworld.OverworldState')
local PartyModule = require('src.game.modules.PartyModule')
local PlayerModule = require('src.game.modules.PlayerModule')
local LocationsModule = require('src.game.modules.LocationsModule')
local UnitModule = require('src.game.modules.UnitModule')
local ItemModule = require('src.game.modules.ItemModule')
local SimpleMenu = require('src.game.ui.SimpleMenu')
local InputModule = require('src.game.modules.InputModule')

local locationData = require('src.data.locations')
local staticPartyData = require('src.data.static_parties')

local Game = {}

function Game:init()
    -- Player party (special, defined in code)
    local playerParty = {
        id = "player",
        name = "Player's Company",
        position = { x = 200, y = 300 },
        interactions = {"talk"},
        units = {
            UnitModule.create("player"),  -- Player-controlled unit
            UnitModule.create("barbarian_leader"),
            UnitModule.create("knight"),
            UnitModule.create("knight"),
        },
        inventory = {
            ItemModule.create("iron_sword"),
            ItemModule.create("leather_armor"),
            ItemModule.create("bread", 5),
        }
    }
    PlayerModule.playerParty = playerParty
    PlayerModule.playerUnit = playerParty.units[1]
    -- Load static parties from data and expand unitsRaw
    local parties = { playerParty }
    for _, party in ipairs(staticPartyData) do
        party.units = {}
        if party.unitsRaw then
            for _, u in ipairs(party.unitsRaw) do
                for i = 1, u.count do
                    table.insert(party.units, UnitModule.create(u.template))
                end
            end
            party.unitsRaw = nil
        end
        table.insert(parties, party)
    end
    PartyModule.parties = parties
    -- Load locations from data
    LocationsModule.locations = locationData
    -- Start in OverworldState
    GameState:push(OverworldState)
end

function Game:update(dt)
    GameState:update(dt)
end

function Game:draw()
    GameState:draw()
    -- Always draw SimpleMenu (it handles if open internally)
    SimpleMenu:draw(love.graphics.getWidth(), love.graphics.getHeight())
end

function Game:keypressed(key)
    -- If SimpleMenu is open, route inputs through InputModule to SimpleMenu
    if SimpleMenu:isOpen() then
        InputModule:handleKeyEvent(key, {
            onAction = function(self, action)
                SimpleMenu:onAction(action)
            end
        })
        return  -- Don't pass to GameState if SimpleMenu handled it
    end
    GameState:keypressed(key)
end

function Game:mousepressed(x, y, button)
    GameState:mousepressed(x, y, button)
end

function Game:mousereleased(x, y, button)
    GameState:mousereleased(x, y, button)
end

return Game 