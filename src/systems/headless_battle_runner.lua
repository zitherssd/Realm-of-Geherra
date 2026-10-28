-- Runs the shared battle simulation to a terminal outcome without presentation.

local BattleSimulation = require("src.game.battle.battle_simulation")

local HeadlessBattleRunner = {}

local DEFAULT_MAX_TICKS = 4000

local function requireStableId(value, description)
    local valueType = type(value)
    if valueType ~= "string" and valueType ~= "number" then
        error(description .. " must have a string or number ID", 3)
    end
    if valueType == "number" and (value ~= value or value == math.huge or value == -math.huge) then
        error(description .. " ID must be a finite number", 3)
    end
end

local function validateParties(partyA, partyB)
    if type(partyA) ~= "table" or type(partyB) ~= "table" then
        error("HeadlessBattleRunner.run requires two parties", 3)
    end

    requireStableId(partyA.id, "Party A")
    requireStableId(partyB.id, "Party B")
    if partyA.id == partyB.id then
        error("Battle parties must have different IDs", 3)
    end

    if type(partyA.actors) ~= "table" or type(partyB.actors) ~= "table" then
        error("Both parties must have actor rosters", 3)
    end

    local seenActorIds = {}
    for _, party in ipairs({partyA, partyB}) do
        for _, actor in ipairs(party.actors) do
            if type(actor) ~= "table" then
                error("Party actor entries must be tables", 3)
            end
            requireStableId(actor.id, "Party actor")
            if actor.stats ~= nil and type(actor.stats) ~= "table" then
                error("Party actor stats must be a table", 3)
            end
            if actor.skills ~= nil and type(actor.skills) ~= "table" then
                error("Party actor skills must be a table", 3)
            end
            if actor.equipment ~= nil and type(actor.equipment) ~= "table" then
                error("Party actor equipment must be a table", 3)
            end
            if actor.statusEffects ~= nil and type(actor.statusEffects) ~= "table" then
                error("Party actor status effects must be a table", 3)
            end
            if seenActorIds[actor.id] then
                error("Battle actor IDs must be unique across both parties", 3)
            end
            seenActorIds[actor.id] = true
        end
    end
end

local function getMaxTicks(options)
    local maxTicks = options.maxTicks
    if maxTicks == nil then
        maxTicks = DEFAULT_MAX_TICKS
    end
    if type(maxTicks) ~= "number" or maxTicks < 0 or maxTicks % 1 ~= 0 then
        error("maxTicks must be a non-negative integer", 3)
    end
    return maxTicks
end

local Encounter = {}
Encounter.__index = Encounter

local function completeEncounter(encounter, outcome, winnerPartyId)
    encounter.result = encounter.simulation:buildResult(
        outcome,
        winnerPartyId
    )
    encounter.state = "completed"
    return encounter.result
end

function Encounter:advance(tickCount)
    if self.state ~= "active" then
        error("Cannot advance an encounter in state " .. self.state, 2)
    end
    if type(tickCount) ~= "number" or tickCount < 0 or tickCount % 1 ~= 0 then
        error("tickCount must be a non-negative integer", 2)
    end

    local outcome, winnerPartyId = self.simulation:getOutcome()
    if outcome then
        return completeEncounter(self, outcome, winnerPartyId)
    end

    local ticksToRun = math.min(tickCount, self.maxTicks - self.simulation.context.data.tick)
    for _ = 1, ticksToRun do
        self.simulation:tick()
        outcome, winnerPartyId = self.simulation:getOutcome()
        if outcome then
            return completeEncounter(self, outcome, winnerPartyId)
        end
    end

    if self.simulation.context.data.tick >= self.maxTicks then
        return completeEncounter(self, "timeout", nil)
    end

    return nil
end

function Encounter:getResult()
    return self.result
end

function Encounter:cleanup()
    if self.state == "cleaned" then
        return
    end
    self.simulation:destroy()
    self.simulation = nil
    self.state = "cleaned"
end

function HeadlessBattleRunner.start(partyA, partyB, options)
    if options == nil then
        options = {}
    elseif type(options) ~= "table" then
        error("HeadlessBattleRunner.start options must be a table", 2)
    end
    validateParties(partyA, partyB)
    local maxTicks = getMaxTicks(options)
    local encounter = setmetatable({
        partyA = partyA,
        partyB = partyB,
        maxTicks = maxTicks,
        simulation = BattleSimulation.new(partyA, partyB, false),
        state = "active",
        result = nil
    }, Encounter)
    return encounter
end

function HeadlessBattleRunner.run(partyA, partyB, options)
    local encounter = HeadlessBattleRunner.start(partyA, partyB, options)
    local ok, result = xpcall(function()
        return encounter:advance(encounter.maxTicks)
    end, debug.traceback)

    encounter:cleanup()
    if not ok then
        error(result, 0)
    end
    return result
end

HeadlessBattleRunner.DEFAULT_MAX_TICKS = DEFAULT_MAX_TICKS

return HeadlessBattleRunner
