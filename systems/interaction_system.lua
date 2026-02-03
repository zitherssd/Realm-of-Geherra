-- systems/interaction_system.lua
--
-- Builds and resolves interactions for encounters.

local InteractionSystem = {}

local MODULE_DEFINITIONS = {
    trade = { id = "trade", label = "Trade", effects = { { type = "trade" } } },
    recruit = { id = "recruit", label = "Recruit", effects = { { type = "recruit" } } },
    rest = { id = "rest", label = "Rest", effects = { { type = "rest", hours = 6 } } },
    quests = { id = "quests", label = "Quests", effects = { { type = "quests" } } },
    fight = { id = "fight", label = "Fight", transition = { scene = "battle" } },
    bribe = { id = "bribe", label = "Bribe", effects = { { type = "bribe" } } },
    explore = { id = "explore", label = "Explore", effects = { { type = "explore" } } },
    raid = { id = "raid", label = "Raid", effects = { { type = "raid" } } },
}

local function clone_interaction(template)
    local interaction = {
        id = template.id,
        label = template.label,
        description = template.description,
        effects = template.effects and { table.unpack(template.effects) } or {},
        transition = template.transition,
    }
    return interaction
end

function InteractionSystem.build_interactions(encounter)
    if encounter.type == "party" then
        return {
            {
                id = "fight",
                label = "Fight",
                transition = { scene = "battle" },
            },
            {
                id = "trade",
                label = "Trade",
                effects = { { type = "trade" } },
            },
            {
                id = "ignore",
                label = "Ignore",
                effects = { { type = "ignore" } },
            },
        }
    end

    local interactions = {}
    local modules = (encounter.target and encounter.target.data and encounter.target.data.interaction_modules) or {}
    for _, module_id in ipairs(modules) do
        local template = MODULE_DEFINITIONS[module_id]
        if template then
            table.insert(interactions, clone_interaction(template))
        end
    end

    table.insert(interactions, {
        id = "leave",
        label = "Leave",
        effects = { { type = "leave" } },
    })

    return interactions
end

function InteractionSystem.resolve(interaction, context)
    if interaction.transition and interaction.transition.scene == "battle" then
        return { transition = interaction.transition, close_encounter = true }
    end

    if interaction.effects then
        for _, effect in ipairs(interaction.effects) do
            if effect.type == "rest" and context and context.time then
                context.time:advance_hours(effect.hours or 6)
            end
        end
    end

    return { close_encounter = true }
end

return InteractionSystem
