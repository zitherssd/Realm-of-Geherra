local GameState = require('src.game.GameState')
local OverworldState = require('src.game.OverworldState')
local PartyModule = require('src.game.modules.PartyModule')
local LocationsModule = require('src.game.modules.LocationsModule')
local UnitModule = require('src.game.modules.UnitModule')
local ItemModule = require('src.game.modules.ItemModule')

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
            UnitModule.create("knight"),
            UnitModule.create("knight"),
        },
        inventory = {
            ItemModule.create("iron_sword"),
            ItemModule.create("leather_armor"),
            ItemModule.create("bread", 5),
        }
    }
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
end

function Game:keypressed(key)
    GameState:keypressed(key)
end

function Game:mousepressed(x, y, button)
    GameState:mousepressed(x, y, button)
end

function Game:mousereleased(x, y, button)
    GameState:mousereleased(x, y, button)
end

return Game 