# Worked example: fish trader & blacksmith

Two complete ways to add a merchant using the reusable trading system. Both need a
**new game** to take effect (locations generate once in `initNewGame`).

## A. Guaranteed merchant (injected in `game/game_initializer.lua`)

Add the troop def to `data/units/npcs/npc_units.lua`:

```lua
["fish_trader"] = {
    id = "fish_trader",
    name = "Fish Trader",
    type = "fish_trader",
    tags = {"civilian", "merchant"},
    sprite = "assets/sprites/units/town.png",
    stats = { health = 28, defense = 4, speed = 7 },
    equipment = { mainHand = "dagger" }
},
```

Build stock with **fresh copies** (never the shared `data/items.lua` tables), then
inject after `LocationPopulationSystem.populate(...)` in `game/game_initializer.lua`:

```lua
-- Reusable stock builder — copies each item def so the shared catalog is untouched.
local function buildStock(entries)
    local stock = {}
    for _, entry in ipairs(entries or {}) do
        local def = Items[entry.id]
        if def then
            local copy = {}
            for k, v in pairs(def) do copy[k] = v end
            copy.quantity = entry.quantity or 1
            table.insert(stock, copy)
        end
    end
    return stock
end

-- after starterLocation is resolved:
local fishTrader = Unit.create(EcsWorld.campaign, "fish_trader")
fishTrader.name = "Mara, the Fishmonger"
fishTrader.buysFromPlayers = true      -- allow selling to her
fishTrader.sellPriceFactor = 0.6       -- she pays 60% of an item's value
fishTrader.inventory = buildStock({
    { id = "club", quantity = 8 },
    { id = "quarterstaff", quantity = 5 },
    { id = "health_potion", quantity = 10 }
})
LocationSystem.addNPC(starterLocation, fishTrader)
```

## B. Chance-spawned merchant (spawn rule + def `stock`)

1. Add a spawn rule to `data/location_npc_spawn_rules.lua` (e.g. under `village` → `npcs`):

   ```lua
   { troopType = "blacksmith", count = 1, chance = 0.6 },
   ```

2. Add the troop def with a `stock` list to `data/units/npcs/npc_units.lua`:

   ```lua
   ["blacksmith"] = {
       id = "blacksmith",
       name = "Blacksmith",
       type = "blacksmith",
       tags = {"civilian", "merchant"},
       sprite = "assets/sprites/units/town2.png",
       stats = { health = 30, defense = 6, speed = 6 },
       equipment = { mainHand = "warhammer" },   -- id must exist in data/items.lua
       stock = {
           { id = "iron_sword", quantity = 3 },
           { id = "spear", quantity = 4 },
           { id = "wooden_shield", quantity = 3 },
           { id = "helmet", quantity = 2 }
       }
   },
   ```

3. Teach `spawnLocationNpcs` to fill the inventory from `stock`. In
   `systems/population/location_population_system.lua`, add the requires at the top and populate
   right after `npc.name = generateNpcName(...)`:

   ```lua
   local TroopsData = require("data.troops")
   local Items = require("data.items")

   -- inside spawnLocationNpcs, after: npc.name = generateNpcName(...)
   local def = TroopsData[rule.troopType]
   if def and def.stock then
       npc.inventory = {}
       for _, entry in ipairs(def.stock) do
           local itemDef = Items[entry.id]
           if itemDef then
               local copy = {}
               for k, v in pairs(itemDef) do copy[k] = v end
               copy.quantity = entry.quantity or 1
               table.insert(npc.inventory, copy)
           end
       end
   end
   ```

Option B's `stock`-based population is the recommended pattern for many traders;
Option A is ideal for a single guaranteed NPC (e.g. the debug trader).

## C. Custom greeting dialogue (optional)

The location screen opens `npc.dialogueId or (npc.troopType .. "_greeting")`, falling
back to `npc_greeting`. The "Show me your wares." option is auto-added to the first line
regardless, so a custom greeting only changes the flavor text.

1. On the spawned troop set `npc.dialogueId = "fish_trader_greeting"`.
2. Add a node — e.g. `data/dialogues/fish_trader.lua`:

```lua
return {
    ["fish_trader_greeting"] = {
        id = "fish_trader_greeting",
        speaker = "Mara, the Fishmonger",
        lines = {
            {
                text = "Fresh from the river, and fair prices for your own goods.",
                options = {
                    { text = "Maybe later.", next = "end" }
                }
            }
        }
    }
}
```

3. Register it in `data/dialogue.lua`:

```lua
mergeDialogueSet(dialogueRegistry, require("data.dialogues.fish_trader"))
```

"Show me your wares." is still auto-injected as the first option on that greeting line.
