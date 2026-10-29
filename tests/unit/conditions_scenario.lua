local Conditions = require("src.systems.actors.conditions")
local Stats = require("src.systems.actors.effective_stats")
local Injury = require("src.systems.actors.injury_system")
local BattleUnit = require("src.ecs.assemblages.battle_unit")
local Ecs = require("src.ecs.world")
local CanAct = require("src.systems.battle.battle_unit_system")
local Execution = require("src.systems.battle.execution_system")
local Combat = require("src.systems.battle.combat_system")
local Items = require("src.data.items")
local Test = {}
function Test.run()
    local actor = {stats = {attack = 10, defense = 0, strength = 12, precision = 10, battle_speed = 20},
        injuryProfile = "humanoid", hp = 100, equipment = {mainHand = "club"}}
    local burn = Conditions.apply(actor, "burn", {duration = 80}, "test")
    assert(burn.damagePerTick == 1 and burn.tickEvery == 20)
    burn.tickCounter = 19
    burn.remaining = 5
    burn = Conditions.apply(actor, "burn", 40)
    assert(burn.remaining == 40 and burn.tickCounter == 19 and burn.damagePerTick == 1)
    Conditions.apply(actor, "stun", {duration = 10, canAct = true})
    actor.globalCooldown = 0
    assert(CanAct.canAct(actor))
    local buff = {duration = 40, lifetime = "persistent", policy = "stack", maxStacks = 2,
        effects = {attack = 3, defense = -5, strength = 2, precision = 5, protection_fire = 4}}
    Conditions.apply(actor, "buff", buff)
    Conditions.apply(actor, "buff", buff)
    Conditions.apply(actor, "buff", buff)
    assert(Stats.get(actor, "attack") == 18 and Stats.get(actor, "defense") == 1)
    assert(Stats.get(actor, "strength") == 16 and Stats.get(actor, "precision") == 20)
    assert(Stats.protection(actor, "fire") == 8)
    local injury = {id = "", bodyPart = ""}
    for id, definition in pairs(require("src.data.injuries").definitions) do
        if definition.effects.attack then
            for _, part in ipairs(Injury.profile(actor).bodyParts) do
                if part.category == definition.category then injury = {id = id, bodyPart = part.id}; break end
            end
            if injury.id ~= "" then break end
        end
    end
    assert(Conditions.apply(actor, injury.id, injury))
    assert(not Conditions.apply(actor, injury.id, injury), "Duplicate injury accepted")
    assert(Conditions.metadata(actor, injury.id, injury.bodyPart).lifetime == "persistent")
    local expected = 18 + Injury.definition(actor, injury).effects.attack
    assert(Stats.get(actor, "attack") == expected)
    local world = Ecs.startBattle()
    local unit = BattleUnit.create(world, actor, 100, 100, "player")
    assert(Stats.get(unit, "attack") == expected, "Equipment or injury counted twice")
    Conditions.apply(unit, "forever", {lifetime = "permanent", effects = {battle_speed = 2}})
    assert(Stats.get(unit, "battle_speed") == 22)
    local saved = Conditions.persistentStatuses(unit)
    assert(saved.buff and saved.forever and not saved.burn and not saved.stun)
    saved.buff.remaining = 1
    assert(unit.statusEffects.buff.remaining == 40)
    Conditions.apply(unit, "buff", {duration = 3, policy = "replace", effects = {attack = 1}})
    assert(unit.statusEffects.buff.stacks == 1 and unit.statusEffects.buff.tickCounter == 0)
    assert(Conditions.remove(unit, injury.id, injury.bodyPart))
    assert(Stats.get(unit, "attack") == 13)
    unit.statusEffects = {burn = {remaining = 0, damagePerTick = 99, tickEvery = 1}}
    local hp = unit.hp
    local execution = Execution()
    execution.pool = {unit}
    execution:update({data = {unitList = {}, projectiles = {}}})
    assert(unit.hp == hp and not unit.statusEffects.burn, "Expired status activated")
    print("Unified conditions foundation PASS")
end
return Test

