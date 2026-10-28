local CampaignRuntime = require("src.game.campaign.campaign_runtime")
-- Focused 7B commissioning fixture; no invented profession execution.
local Ecs = require("src.ecs.world")
local Unit = require("src.ecs.assemblages.unit")
local Party = require("src.ecs.assemblages.party")
local Location = require("src.ecs.assemblages.location")
local Locations = require("src.systems.location_system")
local Parties = require("src.systems.party_system")
local Map = require("src.world.map")
local Goals = require("src.systems.goal_system")
local Activities = require("src.systems.world_activity_system")
local Services = require("src.systems.service_system")
local Knowledge = require("src.systems.knowledge_system")
local Events = require("src.systems.world_events")
local Recovery = require("src.systems.recovery")
local Viewer = require("src.ui.screens.service_viewer")
local WorldState = require("src.game.states.world_state")
local GameContext = require("src.game.game_context")
local Input = require("src.core.input")
local Time = require("src.systems.time_system")
local Scenario = {}

local function setup()
    local world, map = Ecs.init(), Map.new("services")
    local home = Location.create(world, nil, "Near settlement")
    local far = Location.create(world, nil, "Distant healer town")
    home.x, home.y, far.x, far.y = 100, 100, 800, 100
    map:addLocation(home); map:addLocation(far)
    local function actor(name, location)
        local a = Unit.create(world, "soldier")
        a:ensure("memory")
        a.name, a.hp, a.maxHp, a.treasury = name, 100, 100, 100
        Locations.addNPC(location or home, a)
        return a
    end
    local healer, customer, employer = actor("Witch"), actor("Customer"), actor("Employer")
    Goals.configure(healer, {{type = "provide_service"}, {type = "rest_and_recover"}}, {heal = true})
    Goals.configure(customer, {{type = "rest_and_recover"}}, {})
    local context = {world = world, map = map}
    return world, map, home, far, actor, healer, customer, employer, context
end

local function immediate()
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    CampaignRuntime.updateGoals(1, map)
    assert(Services.isProviding(healer, context))
    assert(#Services.listProviders(context) == 1)
    customer.hp = 35
    local total = customer.treasury + healer.treasury
    assert(Services.perform(healer, customer, "heal", context))
    assert(customer.hp == 75 and customer.treasury == 90 and healer.treasury == 110)
    assert(total == customer.treasury + healer.treasury and Events.count(world) == 0)
    assert(Services.perform(healer, customer, "heal", context) and customer.hp == 100)
    assert(not Services.perform(healer, customer, "heal", context))
    customer.hp, customer.treasury = 40, Services.healPrice
    assert(Services.canPerform(healer, customer, "heal", context))
    customer.treasury = 0 -- Funds changed between query and execution.
    local providerGold = healer.treasury
    assert(not Services.perform(healer, customer, "heal", context))
    assert(customer.hp == 40 and healer.treasury == providerGold)
    local amount = Services.healAmount
    Services.healAmount = 0 / 0
    assert(not Services.canPerform(healer, customer, "heal", context))
    Services.healAmount = amount
    customer.hp = 0
    assert(not Services.perform(healer, customer, "heal", context) and customer.hp == 0)
    customer.hp, customer.treasury = 40, 0
    CampaignRuntime.updateGoals(1, map)
    assert(customer.hp == 40 and customer.npc_goals.goals[1].status == "active")
    Recovery.update(1, map)
    assert(customer.hp > 40 and customer.lastRecovery.mode == "resting")
    customer.hp, customer.treasury = 40, 100
    customer.npc_goals.goals[1].healingRetrySeconds = 0
    CampaignRuntime.updateGoals(1, map)
    assert(customer.hp == 80 and customer.treasury == 90)
    local hp = customer.hp
    CampaignRuntime.updateGoals(1, map)
    assert(customer.hp == hp and customer.treasury == 90, "healing purchase loop")
    CampaignRuntime.updateGoals(0, map)
    assert(customer.npc_goals.goals[1].healingRetrySeconds == Services.healingRetrySeconds - 1)
    healer.hp = 40
    CampaignRuntime.updateGoals(1, map)
    assert(not Services.isProviding(healer, context) and healer.npc_goals.capabilities.heal)
    assert(#Services.listProviders(context) == 0)
    healer.hp = 100
    CampaignRuntime.updateGoals(1, map)
    assert(Services.isProviding(healer, context))
    -- Important stationed followers offer locally, without commanding the party.
    local party = Party.create(world, "Healer party", employer.id)
    Locations.removeNPC(home, employer); Locations.removeNPC(home, healer)
    Parties.addActor(party, employer); Parties.addActor(party, healer)
    party.x, party.y, party.treasury = home.x, home.y, 200
    map:addParty(party); map:stationParty(home, party)
    CampaignRuntime.updateGoals(1, map)
    customer.hp = 40
    assert(Services.findLocalProviders(customer, "heal", context)[1] == healer)
    assert(Services.perform(healer, customer, "heal", context) and party.treasury == 210)
    party.activeEncounterId = "battle"
    assert(not Services.perform(healer, customer, "heal", context))
    party.activeEncounterId = nil
    -- Player uses the identical transaction and the party's actual treasury.
    local player = actor("Player")
    player:ensure("player")
    Locations.removeNPC(home, player)
    local playerParty = Party.create(world, "Player", player.id)
    Parties.addActor(playerParty, player)
    playerParty.x, playerParty.y, playerParty.treasury = home.x, home.y, 100
    map:addParty(playerParty)
    player.hp = 40
    assert(Services.perform(healer, player, "heal", context))
    assert(player.hp == 80 and playerParty.treasury == 90 and party.treasury == 220)
    -- Stale independent membership cannot offer a traveling party member's skills.
    assert(map:addParty(party))
    home.npcs[#home.npcs + 1] = healer
    assert(#Services.listProviders(context) == 0)
    local generic = Unit.create(world, "soldier")
    Locations.addNPC(home, generic)
    Goals.configure(generic, {{type = "provide_service"}}, {heal = true})
    CampaignRuntime.updateGoals(1, map)
    assert(generic.npc_goals.evaluationMode == "inactive" and not Services.isProviding(generic, context))
end

local function playerDialogue()
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    local player = actor("Player")
    player:ensure("player")
    Locations.removeNPC(home, player)
    local party = Party.create(world, "Player", player.id)
    Parties.addActor(party, player)
    party.x, party.y, party.treasury = home.x, home.y, 100
    map:addParty(party)
    GameContext.data.player, GameContext.data.playerParty, GameContext.data.currentMap = player, party, map
    CampaignRuntime.updateGoals(1, map, party)
    player.hp = 40
    local Dialogue = require("src.game.states.dialogue_state")
    local UI = require("src.ui.ui_manager")
    local States = require("src.core.state_manager")
    Dialogue.enter({target = healer, location = home, dialogueTree = {
        lines = {{text = "Greetings.", options = {{text = "Leave", next = "end"}}}}
    }})
    local screen = UI.getActiveScreen()
    local choice
    for _, option in ipairs(screen.lines[1].options) do
        if option.action == "purchase_healing" then choice = option end
    end
    assert(choice and choice.text:find("10 gold", 1, true))
    local originalSwap, response = States.swap
    States.swap = function(name, params) assert(name == "dialogue"); response = params end
    screen.onChoice(choice)
    assert(player.hp == 80 and party.treasury == 90 and healer.treasury == 110)
    assert(response.dialogueTree.lines[1].text:find("Restored 40 HP", 1, true))
    -- A previously displayed choice must revalidate affordability on click.
    party.treasury = 0
    screen.onChoice(choice)
    assert(player.hp == 80 and healer.treasury == 110)
    assert(response.dialogueTree.lines[1].text:find("unaffordable", 1, true))
    States.swap = originalSwap
    Dialogue.exit()
end

local function commissioning()
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    local worker = actor("Applicant")
    Goals.configure(worker, {{type = "provide_service"}, {type = "rest_and_recover"}}, {heal = true, travel = true})
    local request = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal", data = {note = "API lifecycle only"}}, context))
    local second = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    assert(request.id ~= second.id and Events.count(world) == 2)
    assert(not Knowledge.knows(worker, request.offerEventId))
    CampaignRuntime.updateGoals(1, map)
    assert(Services.getRequest(request.id, context).status == "open", "omniscient employment discovery")
    assert(Knowledge.learn(worker, request.offerEventId, {"service"}))
    local partial = Knowledge.getKnownEvent(worker, request.offerEventId)
    assert(partial.serviceId == request.id and not partial.employerId and not partial.locationId and not partial.status)
    CampaignRuntime.updateGoals(1, map)
    assert(Services.getRequest(request.id, context).status == "open")
    assert(Knowledge.learn(worker, request.offerEventId, {"employer", "location"}))
    CampaignRuntime.updateGoals(1, map)
    local assigned = Services.getRequest(request.id, context)
    assert(assigned.status == "assigned" and assigned.assignedActorId == worker.id)
    assert(Services.selectedGoal(worker).type == "fulfill_obligation")
    assert(#worker.npc_goals.goals == 3 and worker.npc_goals.goals[1].type == "provide_service")
    assert(not Services.assign(request.id, healer, context))
    assert(not Services.assign(second.id, worker, context))
    assert(not pcall(Goals.configure, worker, {}, {}), "configuration erased accepted work")
    local immutable = Events.get(world, request.offerEventId)
    assert(immutable.status == "open" and not immutable.assignedActorId)
    worker.hp, worker.treasury = 40, 0
    CampaignRuntime.updateGoals(1, map)
    assert(Services.selectedGoal(worker).type == "rest_and_recover")
    assert(worker.npc_goals.goals[3].serviceId == request.id and Services.hasObligation(worker, context))
    worker.hp = 100
    CampaignRuntime.updateGoals(1, map)
    assert(Services.selectedGoal(worker).type == "fulfill_obligation")
    assert(Services.complete(request.id, context))
    local count = Events.count(world)
    assert(Services.complete(request.id, context) and Events.count(world) == count)
    assert(not Services.cancel(request.id, context))
    assert(worker.npc_goals.goals[3].status == "satisfied")
    CampaignRuntime.updateGoals(1, map)
    assert(Services.selectedGoal(worker).type == "provide_service")
    assert(Knowledge.learn(worker, second.offerEventId, {"service", "employer", "location"}))
    CampaignRuntime.updateGoals(10, map)
    assert(Services.getRequest(second.id, context).status == "assigned")
    assert(Services.cancel(second.id, context))
    count = Events.count(world)
    assert(Services.cancel(second.id, context) and Events.count(world) == count)
    CampaignRuntime.updateGoals(1, map)
    assert(not Services.hasObligation(worker, context) and Services.selectedGoal(worker).type == "provide_service")
    local snapshot = Services.getRequest(request.id, context)
    snapshot.status, snapshot.data.note = "open", "changed"
    assert(Services.getRequest(request.id, context).status == "completed")
    assert(Services.getRequest(request.id, context).data.note == "API lifecycle only")
    local removed = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    employer:destroy()
    Services.update(context)
    assert(Services.getRequest(removed.id, context).status == "cancelled")
    assert(not Services.isAvailable(removed.id, context))
    local newEmployer = actor("Replacement")
    local fresh = assert(Services.createRequest(newEmployer, {type = "fixture", requiredCapability = "heal"}, context))
    assert(fresh.id ~= removed.id and Services.getRequest(removed.id, context).status == "cancelled")
    -- Pending removal of an assigned worker safely closes its job.
    worker.hp = 100
    CampaignRuntime.updateGoals(10, map)
    assert(Services.assign(fresh.id, worker, context))
    worker:destroy()
    Services.update(context)
    assert(Services.getRequest(fresh.id, context).status == "cancelled")
    assert(not pcall(Services.createRequest, newEmployer,
        {type = "fixture", requiredCapability = "heal", data = {actor = newEmployer}}, context))
    local another = Ecs.init()
    assert(Ecs.getIdAllocator(another):allocate("service") == "service_1")
    Ecs.campaign = world
    return world, map, context
end

local function travelAndKnowledge()
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    -- The nearer settlement has no healer; travel must still choose it.
    Locations.removeNPC(home, healer); Locations.addNPC(far, healer)
    Locations.removeNPC(home, customer)
    local party = Party.create(world, "Injured traveler", customer.id)
    Parties.addActor(party, customer)
    party.x, party.y, party.treasury = 300, 100, 100
    map:addParty(party)
    customer.hp = 40
    Goals.configure(customer, {{type = "rest_and_recover"}}, {travel = true})
    CampaignRuntime.updateGoals(1, map)
    assert(party.world_activity.type == "travel" and party.world_activity.params.destinationLocationId == home.id)
    assert(not customer.npc_goals.goals[1].healingRetrySeconds or customer.npc_goals.goals[1].healingRetrySeconds == 0)
    assert(customer.hp == 40 and party.treasury == 100)
    for _ = 1, 15 do CampaignRuntime.updateGoals(1, map); Activities.update(1, map) end
    assert(Services.getLocation(customer, context) == home and party.treasury == 100)
    assert(party.world_activity.type == "rest" and party.world_activity.status == "active")
    -- Return a healer locally and retry only after elapsed world time.
    Locations.removeNPC(far, healer); Locations.addNPC(home, healer)
    CampaignRuntime.updateGoals(30, map)
    assert(customer.hp == 80 and party.treasury == 90)
    -- Known remote employment reuses travel and checks live state on arrival.
    local applicant = actor("Remote applicant", far)
    Goals.configure(applicant, {{type = "provide_service"}}, {heal = true, travel = true})
    Locations.removeNPC(far, applicant)
    local applicants = Party.create(world, "Applicants", applicant.id)
    Parties.addActor(applicants, applicant)
    applicants.x, applicants.y = far.x, far.y
    map:addParty(applicants); map:stationParty(far, applicants)
    local offer = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    CampaignRuntime.updateGoals(1, map)
    assert(not applicants.world_activity or applicants.world_activity.status ~= "active")
    Knowledge.learn(applicant, offer.offerEventId, {"service", "employer", "location"})
    CampaignRuntime.updateGoals(1, map)
    assert(applicants.world_activity.type == "travel")
    assert(Services.cancel(offer.id, context))
    for _ = 1, 35 do CampaignRuntime.updateGoals(1, map); Activities.update(1, map) end
    assert(Services.getLocation(applicant, context) == home)
    assert(not Services.hasObligation(applicant, context))
    local closure = Services.getRequest(offer.id, context).closureEventId
    assert(Knowledge.knows(applicant, closure), "stale applicant did not learn current status")
    local nextOffer = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    Knowledge.learn(applicant, nextOffer.offerEventId, {"service", "employer", "location"})
    CampaignRuntime.updateGoals(10, map)
    assert(Services.getRequest(nextOffer.id, context).assignedActorId == applicant.id)
    assert(Services.cancel(nextOffer.id, context))
    local independent = actor("Independent applicant", far)
    Goals.configure(independent, {{type = "provide_service"}}, {heal = true})
    local open = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    Knowledge.learn(independent, open.offerEventId, {"service", "employer", "location"})
    CampaignRuntime.updateGoals(1, map)
    assert(independent.npc_goals.goals[1].reason == "independent_resident_cannot_travel")
end

local function viewer()
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    CampaignRuntime.updateGoals(1, map)
    local v = Viewer.new(world, map)
    assert(#v.rows == 0)
    v:draw() -- Empty actual LÖVE renderer.
    local request = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal", data = {note = "Read-only viewer fixture"}}, context))
    v:refresh()
    assert(#v.rows == 1 and v.selectedId == request.id)
    v:draw()
    local count = Events.count(world)
    v:keypressed("tab")
    assert(#v.rows == 1 and v.rows[1].id == healer.id)
    v:draw()
    healer.hp = 40
    CampaignRuntime.updateGoals(1, map)
    v:refresh()
    assert(#v.rows == 0)
    v:keypressed("tab"); v:keypressed("3")
    assert(#v.rows == 0)
    assert(Events.count(world) == count and Services.getRequest(request.id, context).status == "open")
    -- Exercise scrolling and bounded rendering with a populated list.
    for index = 1, 15 do
        assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal",
            data = {number = index, note = string.rep("Detail scrolling fixture. ", 40)}}, context))
    end
    v:refresh(); v:keypressed("1")
    local left = v:layout()
    v:mousepressed(left.x + 20, left.y + v.rowHeight + 10, 1)
    assert(v.selectedId == v.rows[2].id)
    local getPosition = love.mouse.getPosition
    love.mouse.getPosition = function() return left.x + 20, left.y + 20 end
    v:wheelmoved(-12)
    love.mouse.getPosition = getPosition
    assert(v.scroll > 0)
    v:draw()
    -- Optional real renderer snapshots, outside the repository.
    local snapshotDirectory = os.getenv("GEHERRA_SERVICE_SNAPSHOTS")
    if snapshotDirectory then
        local originalWidth, originalHeight = love.graphics.getDimensions()
        healer.hp = 100
        CampaignRuntime.updateGoals(1, map)
        for _, size in ipairs({{800, 600}, {1024, 768}, {1280, 720}}) do
            love.window.setMode(size[1], size[2], {resizable = true})
            v:refresh()
            for _, mode in ipairs({"requests", "providers", "empty"}) do
                v.tab = mode == "providers" and "providers" or "requests"
                v.filter = mode == "empty" and "assigned" or "all"
                v:selectRows()
                local canvas = love.graphics.newCanvas(size[1], size[2])
                love.graphics.setCanvas(canvas)
                v:draw()
                love.graphics.setCanvas()
                local image = canvas:newImageData():encode("png")
                local file = assert(io.open(snapshotDirectory .. "/services-" .. mode .. "-" .. size[1] .. ".png", "wb"))
                file:write(image:getString()); file:close()
                canvas:release()
            end
        end
        love.window.setMode(originalWidth, originalHeight)
    end
    local viewerWorker = actor("Viewer worker")
    Goals.configure(viewerWorker, {{type = "provide_service"}}, {heal = true})
    CampaignRuntime.updateGoals(1, map)
    assert(Services.assign(request.id, viewerWorker, context))
    v:refresh(); v:keypressed("3")
    assert(#v.rows == 1 and v.rows[1].assignedActorId == viewerWorker.id)
    v:draw()
    assert(Services.complete(request.id, context))
    v:refresh(); v:keypressed("4")
    assert(#v.rows == 1 and v.rows[1].status == "completed")
    v:draw()
    -- Exercise actual world input routing, pause and close behavior.
    WorldState.currentMap = map
    WorldState.debugOverlay = require("src.ui.screens.debug_overlay").new()
    local player = actor("Viewer player")
    player:ensure("player")
    Locations.removeNPC(home, player)
    local party = Party.create(world, "Viewer party", player.id)
    Parties.addActor(party, player)
    map:addParty(party)
    GameContext.data.playerParty = party
    Input.init()
    assert(WorldState.keypressed("f3"))
    assert(WorldState.serviceViewer and WorldState.blocksPointerInput())
    local before = Time.getDay() * 24 + Time.getHour()
    WorldState.update(30)
    assert(before == Time.getDay() * 24 + Time.getHour())
    WorldState.keypressed("f3")
    assert(not WorldState.serviceViewer)
    WorldState.keypressed("f3"); WorldState.keypressed("escape")
    assert(not WorldState.serviceViewer)
    WorldState.keypressed("f2")
    assert(WorldState.eventViewer)
    WorldState.keypressed("f3")
    assert(WorldState.serviceViewer and not WorldState.eventViewer)
    WorldState.keypressed("escape")
    Time.setPaused(false)
end

-- Interactive fixture in the existing scenario runner; no campaign generation changes.
function Scenario.preview()
    love.window.setMode(1024, 768, {resizable = true})
    love.window.setTitle("Geherra 7B service viewer fixture")
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    local worker = actor("Commission applicant")
    Goals.configure(worker, {{type = "provide_service"}, {type = "rest_and_recover"}}, {heal = true})
    for index = 1, 16 do
        local request = assert(Services.createRequest(employer, {
            type = "fixture", requiredCapability = "heal",
            data = {fixture = true, note = "Commission lifecycle only; no profession executor.", number = index}
        }, context))
        if index <= 3 then
            Knowledge.learn(worker, request.offerEventId, {"service", "employer", "location"})
            CampaignRuntime.updateGoals(10, map)
            if index == 1 then Services.complete(request.id, context)
            elseif index == 2 then Services.cancel(request.id, context) end
        end
    end
    WorldState.currentMap = map
    GameContext.data.currentMap = map
    WorldState.camera = require("src.world.camera").new(1024, 768)
    WorldState.debugOverlay = require("src.ui.screens.debug_overlay").new()
    WorldState.eventViewer = nil
    WorldState.serviceViewer = Viewer.new(world, map)
    Input.init()
    love.draw = function()
        love.graphics.clear(0.12, 0.15, 0.12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("7B fixture | F1 inspector | F2 history | F3 services | Close window to exit", 20, 20)
        WorldState.debugOverlay:draw(map)
        if WorldState.eventViewer then WorldState.eventViewer:draw() end
        if WorldState.serviceViewer then WorldState.serviceViewer:draw() end
    end
    love.keypressed = function(key, _, repeated)
        if key == "f1" then
            require("src.core.state_manager").keypressed(key, repeated)
            WorldState.debugModeChanged()
            if require("src.debug.mode").enabled then WorldState.debugOverlay:inspect("unit", healer.id) end
        else WorldState.keypressed(key, repeated) end
    end
    love.textinput = WorldState.textinput
    love.mousepressed = WorldState.mousepressed
    love.wheelmoved = WorldState.wheelmoved
end

local function obligationAuthority()
    local world, map, home, far, actor, healer, customer, employer, context = setup()
    CampaignRuntime.updateGoals(1, map)
    local request = assert(Services.createRequest(employer, {type = "fixture", requiredCapability = "heal"}, context))
    local selected = Services.selectedGoal(healer)
    local add = Goals.addGoal
    Goals.addGoal = function() error("Service assignment must not call the evaluator") end
    local ok, result = pcall(Services.assign, request.id, healer, context)
    Goals.addGoal = add
    assert(ok and result)
    assert(Services.selectedGoal(healer) == selected, "Contract acceptance selected a goal")
    local obligation = healer.npc_goals.goals[3]
    assert(obligation.type == "fulfill_obligation" and obligation.status == "pending")
    assert(Goals.addGoal(healer, {type = "fulfill_obligation", serviceId = request.id}) == obligation)
    assert(#healer.npc_goals.goals == 3, "Accepted responsibility was duplicated")
    healer.hp = 30
    Goals.update(1, map)
    assert(Services.selectedGoal(healer).type == "rest_and_recover" and Services.hasObligation(healer, context))
    healer.hp = 100
    Goals.update(1, map)
    assert(Services.selectedGoal(healer) == obligation)
    assert(Services.cancel(request.id, context))
    assert(obligation.status == "satisfied" and obligation.resolvedStatus == "cancelled")
    assert(not Services.selectedGoal(healer))
    assert(not pcall(Goals.addGoal, healer, {type = "fulfill_obligation", serviceId = request.id}))
end

function Scenario.run()
    obligationAuthority()
    immediate()
    playerDialogue()
    commissioning()
    travelAndKnowledge()
    viewer()
end
return Scenario
