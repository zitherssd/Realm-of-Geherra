---
name: trader-npcs
description: >
  Add trader NPCs to Geherra-Realms and use the reusable shop/trading system: merchant
  stock, buy/sell for gold, spawn rules, and the auto-added "Show me your wares" dialogue
  option. Use when adding a merchant, trader, shopkeeper, fish trader, blacksmith, or any
  NPC that should sell or buy items, or when wiring a shop into a settlement.
license: Apache-2.0
compatibility: Geherra-Realms (LÖVE 11.x, Lua 5.1 / LuaJIT)
metadata:
  engine: love2d
  category: disciplines
  difficulty: beginner
---

# Trader NPCs & the Trading System

Add new trader/merchant NPCs to Geherra-Realms and hook them into the reusable shop
screen. **Any NPC with a non-empty `inventory` automatically becomes a merchant** — the
"Show me your wares." dialogue option and the buy/sell screen appear with no per-NPC
shop code.

## When to use

- Adding a new merchant/trader/shopkeeper (fish trader, blacksmith, apothecary, ...).
- Making an existing NPC sell items, buy items, or both.
- Wiring a shop into a settlement or a guaranteed shop NPC.
- Debugging a missing "Show me your wares" option or broken buy/sell.

**When *not* to use:** editing item definitions (`data/items.lua`), quest-giver dialogue,
or non-shop inventory UI — those are separate concerns.

## Core workflow (add a trader)

1. **Add a troop definition** in `data/units/npcs/npc_units.lua` (`id`, `name`, `type`,
   `tags = {"civilian", "merchant"}`, `sprite`, `stats`, `equipment`). `data/troops.lua`
   aggregates it automatically.
2. **Give it stock** — `npc.inventory` is a plain list of item tables (same shape as
   `party.inventory`); each entry is an item-def copy with an optional `quantity`
   (units available before the slot empties). Enable selling with
   `npc.buysFromPlayers = true`; `npc.sellPriceFactor` (default 1.0) sets the sell price
   as a fraction of `value`.
3. **Spawn it**:
   - *Guaranteed / always present*: inject it in `game/game_initializer.lua` after
     `LocationPopulationSystem.populate(...)` and call
     `LocationSystem.addNPC(location, troop)` (`systems/locations/location_system.lua`).
   - *Chance-based per location type*: add `{ troopType = "<type>", count = n, chance = c }`
     to `data/location_npc_spawn_rules.lua` — and give the def a `stock` list so
     `spawnLocationNpcs` can fill its inventory (see
     [reference](./references/trader-example.md)).
4. **The shop option appears automatically.** `dialogue_state.lua` prepends
   "Show me your wares." to the first line of any NPC whose `inventory` is non-empty.
   No dialogue authoring is required. Optional: set `npc.dialogueId` to a custom greeting
   node in `data/dialogues/` (register it via `mergeDialogueSet` in `data/dialogue.lua`).

## How the trading system works

- **Screen:** `ui/screens/shop_screen.lua` shows two grids — merchant stock (buy) and
  player inventory (sell). Both scroll with the mouse wheel (`InventoryGrid:enableScroll()`).
- **Buy:** `PartySystem.withdrawTreasury(playerParty, value)` →
  `PartySystem.addItemDefCopy(playerParty, item, 1)` → merchant stock decrements
  (`quantity` or entry removed).
- **Sell** (only if `buysFromPlayers`): remove one unit from the player's inventory →
  `addToStock(merchant.inventory, item)` (the item goes INTO the trader's stock) →
  `PartySystem.addTreasury(playerParty, floor(value * sellPriceFactor))`.
- **State wiring:** the `open_shop` dialogue action runs
  `StateManager.push("shop", { merchant = target, location = location })`; when the shop
  closes, `DialogueState.resume()` re-shows the conversation.

## Gotchas

- **Never store shared catalog tables in an inventory.** Use
  `PartySystem.addItemDefCopy(playerParty, def, qty)` (`systems/parties/party_system.lua`) for
  the player and the copy helper in the [reference](./references/trader-example.md) for
  merchants — it shallow-copies and stacks by id. Mutating a shared `data/items.lua`
  table corrupts it for the whole game.
- **Sell price** = `floor(value * sellPriceFactor)`; buy price = `value`. Use
  `sellPriceFactor = 0.5..0.7` for realistic traders.
- **Auto-inject scope:** the option is added only to the first (greeting) line and only
  when `#inventory > 0`; system dialogue nodes pass no target and are unaffected.
- **Spawn changes need a new game** — locations are generated once in `initNewGame`.

## Worked examples

- [Fish trader & blacksmith — full code](./references/trader-example.md)
