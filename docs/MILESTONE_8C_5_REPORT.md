# Milestone 8C.5 — Unified inventory system

Completed 2026-10-29. Scope stops at inventory unification; 8D was not started.

## 1. Representations found

- Actors: item-ID-to-quantity maps, with equipment separately stored as slot-to-ID
  references and wear in `itemDurability[itemId]`. Some tests already supplied lists.
- Parties: lists of item-instance tables, shared cargo independent of their leaders.
- Traders and caravan stock: lists of copied item definitions; NPCs switched format
  using `inventoryFormat`. Shops already used the shared transfer helper.
- Generated interactive rewards: `Item.new` objects with metatable stack methods;
  merging checked only the item ID. Their field defaults differ from item definitions.
- Battlefield remains: `loot.items` held resource wrappers containing `item`, source
  IDs, source kind/index/slot and durability. Interaction fixtures instead used plain
  items, and collection appended those items directly.
- `InventorySystem` supported both maps and lists, with separate transfer branches;
  actor loot accounting assumed maps and aggregated by item ID.
- Services currently transfer treasury currency rather than consume inventory items.
  Population creates actors and stock through Unit/NPCFactory/TraderSystem.

## 2. Canonical representation and rationale

Every owner has `owner.inventory = Inventory.new()`: a dense list of plain item
instances with a string `id`, quantity and any existing instance data. This retains
party/trader/UI conventions and supports multiple same-ID items without losing state.
No inventory class, owner dispatch, new dependency or second authoritative inventory
was introduced. Helpers create explicit quantities; existing omitted quantity means one.

## 3. Shared API

`new`, `getInventory` (live listing), `addItem`, `removeItem`, `getItemCount`, `hasItem`,
`transferItem`, `transferAll`, `replaceListContents`, `isValid`, `stackable`,
`itemSignature`, `copyInventory`, `deepClone` live in the existing InventorySystem.
Existing owner-based call signatures remain, including PartySystem's delegating API.

Remove/transfer accepts a row index, actual source instance, or an ID selecting the
first matching stack. Omitted quantity means the full selected stack. An oversized
request fails rather than choosing other metadata variants. Count/has aggregate all
stacks of the ID. Mutations reject malformed lists, invalid IDs, and nonpositive,
fractional or nonfinite quantities. Transfers reject shared source/destination lists.
Full transfers preflight all additions and use the shared single-stack transfer.
Prepared battle loot uses shared additions and an in-place list commit after accounting.

## 4. Ownership rules

Actor possessions, actor equipment, party shared cargo and remains stock have distinct
owners. Membership/leadership changes never merge or transfer actor cargo. Leadership
death/replacement preserves party cargo and treasury. Explicit transfers are required
between owners. Locations can use the same API later without implementing a new store.

## 5. Metadata and equipment preservation

Stack merging compares every field except quantity, including nested metadata,
enchantments and durability. Different state stays separate. Instance/definition
`stackable = false` creates single-item rows. `instanceId` prevents merging and repeat
identity within a destination. Metadata is deeply copied across transfer boundaries;
returned transfer snapshots do not alias destination or source metadata.

Existing equipment slot IDs and requirements remain. `equipmentItems[slot]` retains
additional instance state while equipped. Equip/unequip returns the existing ID plus
the full item snapshot. Click, drag, and equipment swaps preserve this state; moving
one item out of a stack consumes one. Existing shield wear is incorporated when the
item is read or unequipped. Result application drops state for broken slots. Breaking
an equipped shield no longer tries to delete an unrelated spare from personal cargo.
Initial troop equipment is never copied into personal inventory.

## 6. Migration

Unit and Party initialize the same storage. NPC stock, debug stock, party wrappers,
shop transfers, generated loot and loot screens use it. Actor casualty resources now
identify and validate each source inventory row, including metadata-distinct variants.
Equipment source metadata is also validated. Existing encounter guards prevent double
application. Loot policy/probabilities, retained/stolen/destroyed allocation and generated
reward defaults remain intact.

Remains use `site.inventory`, and dialogue/collection reads it. Resource provenance is
retained in `history.resourceAllocations`; those records are historical snapshots and
are never treated as available stock. Gold/corpses/event/encounter metadata remain.
Compatible collection stacks merge, while metadata variants remain separate.
Remains snapshots write schema 2 and restore schemas 1/2. The schema-1 adapter handles
both resource wrappers and plain items, preserving durability and wrapper history,
then removes `loot.items`. Invalid legacy lists fail before publishing restored state.
Fixtures are explicitly migrated, rather than automatically converting actor maps.

## 7. Treasury

Party/actor numeric treasury and remains `loot.gold` remain separate from inventory.
`transferGold`, shop payments, caravan investment/trade/delivery, raid gold accounting,
and service fees keep their existing rules. Generated drop item values/weights retain
`Item.new` defaults. No prices, currency model or economy rules were added.

## 8. Files changed by this milestone

The checkout already contained uncommitted 8C injury work. Those changes were retained;
this list identifies only files edited for 8C.5 (some also contain pre-existing edits).

- `docs/CAMPAIGN_ARCHITECTURE.md`
- `docs/MILESTONE_8C_5_REPORT.md`
- `src/ecs/assemblages/unit.lua`
- `src/ecs/assemblages/party.lua`
- `src/game/game_initializer.lua`
- `src/game/states/shop_state.lua`
- `src/systems/battle/combat_system.lua`
- `src/systems/battlefield/battlefield_interaction.lua`
- `src/systems/battlefield/battlefield_remains_system.lua`
- `src/systems/battlefield/battlefield_resource_collection.lua`
- `src/systems/campaign/campaign_battle_result_applier.lua`
- `src/systems/items/inventory_system.lua`
- `src/systems/items/equipment_system.lua`
- `src/systems/items/loot_application.lua`
- `src/systems/items/loot_generator_system.lua`
- `src/systems/items/loot_resolver.lua`
- `src/systems/items/trader_system.lua`
- `src/systems/population/npc_factory.lua`
- `src/ui/screens/inventory_screen.lua`
- `src/ui/screens/loot_screen.lua`
- `tests/unit/battle_knowledge_scenario.lua`
- `tests/unit/battlefield_interaction_scenario.lua`
- `tests/unit/battlefield_remains_scenario.lua`
- `tests/unit/campaign_architecture_milestone_1_scenario.lua`
- `tests/unit/campaign_battle_resolution_scenario.lua`
- `tests/unit/knowledge_search_scenario.lua`
- `tests/unit/loot_resolver_scenario.lua`
- `tests/unit/main.lua`
- `tests/unit/raid_encounter_scenario.lua`
- `tests/unit/travel_activity_scenario.lua`
- `tests/unit/unified_inventory_scenario.lua`

## 9. Verification

Executed with LÖVE 11.5 using `C:\Program Files\LOVE\lovec.exe`.
All 41 scenario files were executed individually so early baseline failures could not
hide later coverage. **35 passed; six failures reproduce the pre-edit baseline.**
Navigation tests pass. The normal aggregate runner still stops at the baseline
`party_speed_scenario` failure. No unrelated assertions were weakened.
`git diff --check` passes (Git reports existing line-ending normalization warnings).

The new `unified_inventory_scenario` exercises all owner kinds, add/remove/count/has,
stack merging, single-item rows, distinct durability and nested metadata, detached
transfer results, partial/full transfers, insufficient/invalid requests, alias checks,
repeat-transfer prevention, atomic full-transfer rejection, leader replacement/death,
equip/unequip, swapping same-ID gear with different durability/metadata, shield wear
and spare preservation, generated loot stacking/default values, LootScreen idempotence,
shop buy/sell treasury behavior, casualty metadata tamper rejection, repeated loot-plan
application, and schema-1 remains migration. Existing scenarios additionally cover
interactive/headless rewards, remains, raid accounting, caravans/delivery, services,
population, NPC goals and persistent injuries.

Passing scenarios:

- `battle_knowledge_scenario`
- `battle_simulation_scenario`
- `battlefield_interaction_scenario`
- `battlefield_remains_scenario`
- `campaign_architecture_milestone_1_scenario`
- `campaign_battle_resolution_scenario`
- `campaign_battle_result_scenario`
- `campaign_identity_milestone_2_scenario`
- `caravan_scenario`
- `combat_regression_scenario`
- `data_definitions_scenario`
- `debug_campaign_scenario`
- `debug_mode_scenario`
- `dynamic_importance_scenario`
- `faction_identity_scenario`
- `headless_battle_scenario`
- `injury_scenario`
- `inline_party_scenario`
- `investigation_scenario`
- `knowledge_scenario`
- `knowledge_search_scenario`
- `location_types_scenario`
- `loot_resolver_scenario`
- `npc_goals_scenario`
- `population_scenario`
- `raid_encounter_scenario`
- `raid_visibility_scenario`
- `retinue_scenario`
- `roam_activity_scenario`
- `services_scenario`
- `travel_activity_scenario`
- `travel_knowledge_scenario`
- `unified_inventory_scenario`
- `world_activity_scenario`
- `world_events_scenario`

Baseline failures, present before and after this work:

- `campaign_runtime_scenario`: line 92, clock/simulation conversion assertion.
- `party_speed_scenario`: line 9, party movement speed assertion.
- `personality_return_home_scenario`: line 26 (called from 101), 5.3333333333333 versus 12.
- `recovery_scenario`: line 165, ordinary goal did not resume.
- `world_encounter_scenario`: line 48 (called from 79), clock did not return elapsed game hours.
- `world_time_sync_scenario`: line 201, world-hour to world-second conversion is incorrect.

Reproduce the focused scenario from the repository root:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' tests/unit unified_inventory_scenario
```

## 10. Known limitations

- Full save/load and hot migration of an already running campaign are outside scope.
  Runtime actor maps are rejected; they are not guessed or silently converted.
- Equipped state retains the established slot-ID map and the existing item-ID wear
  map used by shield combat. General per-slot combat wear for additional equipment
  types is not introduced. Slot snapshots retain distinct instance metadata.
- ID-selected removal/transfer operates on one stack. Use an index or instance when
  selecting a particular variant; multi-variant consumption policy belongs to callers.
- Metadata is expected to be plain game data. Existing loot/remains boundaries retain
  serialization checks; the generic helper does not add a new metadata schema system.
- Rendered live gameplay was not manually inspected. Screen methods and interactions
  were exercised by scenario tests; visual verification steps are below.

## 11. Remaining legacy operations

No runtime `inventoryFormat`, actor-map branch, or `loot.items` stock reader remains.
`loot.items` exists only in the explicit schema-1 restore adapter and its test.
`src/entities/item.lua` retains its old stack methods; inventory callers no longer use
them. Its constructor remains to preserve generated reward fields. Read-only list
access remains in UI/debug displays, loot planning, cargo checks and tests. Constructors,
stock refresh and fixtures still assign complete lists; actual item movement uses the
shared helper, with prepared battle consequences committed through its replace helper.
No temporary actor/party dual-format adapter remains.

## 12. Manual verification

1. Start a new/debug game with `love .`. Open inventory with I. Click and drag gear
   between cargo and compatible equipment slots; swap occupied slots and reject an
   incompatible swap. Confirm quantities and requirements behave as before.
2. For worn or metadata-bearing gear supplied through the shared API, equip and
   unequip it and inspect the returned item. Swap two same-ID daggers with distinct
   state. Confirm each retains its own state and no equipped copy remains in cargo.
3. Buy and sell debug-trader stock. Confirm one item moves per action and treasury
   follows existing buy/sell prices. Observe caravan trade/delivery without a leader
   cargo alias or unexpected treasury changes.
4. Finish a player battle, take one reward and Take All; repeat Take All. Confirm
   rewards move once and party treasury is credited once by existing reward handling.
5. Let an NPC/raid battle finish. Inspect generated remains and search for supplies.
   Confirm item variants, quantities, gold, corpse records and event history survive;
   repeat collection and confirm it grants nothing.
6. Replace/remove a party leader and confirm shared cargo remains on the party.
   Check NPC generation and existing service interactions. No injury treatment,
   Healing Herbs, markets or 8D behavior is added by this milestone.
