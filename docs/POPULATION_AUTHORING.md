# Typed location and population authoring

Every piece of content has one owner. A location definition describes the place and
its interactions. A population profile describes the people and parties that start
there. Changing the population does not change the location's actions or rules.

## Where to edit

| What you want to change | Authoring directory |
|---|---|
| Placement, location names, discovery, supported behavior, action buttons | `src/data/locations/` |
| Which residents, personal parties or garrisons spawn | `src/data/population/locations/` |
| Character stats, equipment, starting gold, goals, capabilities, default retinue | `src/data/npc_archetypes/` |
| Cultural names and role mappings | `src/data/population/cultures/`, `src/data/names/` |
| Political defaults and population/garrison overrides | `src/data/population/factions/` |
| Retinue composition, funds, supplies and initial placement | `src/data/population/parties/` |
| Default campaign faction list | `src/data/population/settings.lua` |
| What an action actually does | `src/systems/location_actions.lua` or an individual action module |

Add new data files to their directory's `index.lua`. IDs must match filenames.
The removed `location_npc_spawn_rules.lua` and `location_population_config.lua` are
no longer alternative data sources. Terrain settings remain in `world_generation.lua`.
The old `static_locations.lua` is still an unwired collection of design notes.

## Named types in Lua

Definitions now use checked constructors:

```lua
local LocationDefinition = require("src.data.types.location_definition")
return LocationDefinition.new {
    -- Fields checked against the named LocationDefinition type.
}
```

The type modules are in `src/data/types/`: `LocationDefinition`, `LocationRules`,
`LocationAction`, `PopulationProfile`, `PopulationRule`, `NpcArchetype`, `PartyTemplate`,
`CultureDefinition`, `FactionPopulationDefinition` and `NamePoolDefinition`.
Each provides `.new(value)`, `.validate(value)` and `.is(value)`.

The constructors reject missing required fields, unknown fields, incorrect value
kinds, malformed arrays, invalid ranges and unsupported enum values. Nested errors
include their path, for example:

```text
LocationDefinition[fort].rules.caravanStop: expected boolean
```

`population/catalog.lua` separately validates references: an archetype, population
profile, culture, party, capability, item or action ID must actually exist. Validation
runs when definitions load and again at campaign initialization boundaries.

LuaDoc annotations describe the same named records for Lua Language Server editors,
providing field completion, tooltips and editor type diagnostics without changing
LÖVE's LuaJIT runtime or adding a build/transpilation step. This is runtime-validated
structural data, not C# compiler enforcement: arbitrary later table assignments are
not intercepted, and plain cloned/deserialized records are checked with `.validate`.
The campaign entities remain normal ECS entities rather than a parallel class system.

## One location file owns the place

The real `locations/fort.lua` has this shape (names shortened here):

```lua
local LocationDefinition = require("src.data.types.location_definition")
return LocationDefinition.new {
    id = "fort", displayName = "Fort", mapMarker = "castle",
    placement = {
        weight = 0, siteSizes = {"major"},
        biomeWeights = {forest = 2, hills = 5, mountain = 3, plains = 2},
    },
    population = {min = 100, max = 400},
    prosperity = {min = 20, max = 60},
    visibility = {min = 90, max = 130},
    populationProfile = "fort",
    rules = {
        caravanStop = true,
        recoveryStop = true,
        recruitmentPool = "castle",
    },
    actions = {{label = "Request Audience", action = "requestAudience"}},
    roadWorthy = true, hidden = false,
    names = {"Hornwatch", "Bronzewall", "Highwall Fort"},
}
```

A generated fort has `location.type == "fort"`; it does not pretend to be a castle.
There is no `gameplayType`. Rules have these concrete consumers:

| Field | Behavior |
|---|---|
| `rules.caravanStop` | Caravan sponsors/destinations must support this rule |
| `rules.recoveryStop` | Injured travelers seek these locations; automatic local recovery healing requires it |
| `rules.recruitmentPool` | Selects the existing faction-specific recruitment pool when recruitment runs |
| `actions` | Determines the actual buttons offered by this location |
| `hidden` / `visibility` | Controls initial discovery and spotting difficulty |
| `roadWorthy` | Includes the site in normal road tracing |
| `mapMarker` | Selects an existing location background asset; it does not imply behavior |

`src/systems/location_rules.lua` is the shared policy lookup used by goals, caravans,
services, recruitment and the debug fixture. There are no separate town/village/castle
eligibility lists in those systems. There are no `facilities` flags: market/tavern/
barracks booleans previously had no gameplay consumer and are now rejected as unknown
fields. Merchants, healers, tavern keepers and garrisons still come from population;
existing NPC services and dialogue implement their interactions.

Placement selection uses `weight × biomeWeights[biome]`; an unlisted biome has
multiplier 1, and multiplier 0 excludes it. `siteSizes` filters candidates against
`site.siteSize`; absent metadata means major for the current painted generator.
Weight 0 means explicit placement only. Trading Town currently has weight 1; Fort
and Wizard Tower have weight 0. Aggregate population does not create that many actors.

## Population profiles contain people and parties only

```lua
local PopulationProfile = require("src.data.types.population_profile")
return PopulationProfile.new {
    id = "fort",
    residents = {
        {id = "commander", role = "fort_commander", count = 1},
        {id = "healer", role = "healer", count = 1, chance = 0.5},
        {id = "quartermaster", role = "quartermaster", count = 1},
    },
    garrison = {
        role = "fort_guard", leaderSlot = "commander",
        count = {min = 8, max = 16}, treasury = 100,
    },
}
```

`actions` in a population profile is now a type error. A faction or scenario can
replace the inhabitants of a fort while it keeps its fort rules and buttons.

Counts are nonnegative integers or inclusive `{min, max}` ranges. Chance defaults
to 1 and is checked per attempted actor. Each slot needs a unique ID and a `role`
or explicit `archetype`. Optional `enabled = false` suppresses it. Optional `when`
supports min/max prosperity/population, culture, faction, a list of eligible biomes,
and required tags. Conditions combine with AND, except the biome list accepts any
listed biome. Tags are flags such as `{trade = true}`. Conditions gate initial
creation; later changes do not replace people.

Culture maps roles to archetypes, with generic role fallback. The specialized
Minotaur/Pelasgian cultures currently provide complete fort role sets; extend their
maps for culturally specific civilian professions. Faction `residentOverrides` use
profile ID then slot ID, replacing fields in that slot rather than adding duplicates.
Faction `garrisonRoles` take precedence for garrison troops. Civilian culture remains
independent of ownership. Changing ownership does not automatically repopulate a place.

## Characters, names and parties

Archetypes use `NpcArchetype.new { ... }`. They select an existing `troopType`, title,
important flag, starting treasury, goals and capabilities. Optional stats/attributes
accept integer ranges, equipment accepts item IDs or lists of choices, and `namePool`
can override culture naming. Sprite/equipment choices use the seeded population RNG.
Troop shop stock and starting actor data are copied, not shared with mutable actors.

Important actors get permanent IDs, memory and ordinary goals. Names come from their
culture's pool, checking archetype ID, troop type, then `default`; the result is stored
on `actor.name` once. Names can repeat; IDs distinguish actors. Ordinary troops have
empty goals/capabilities and no personal NPC memory.

An archetype can define its party directly. The actual Minotaur chieftain now includes:

```lua
party = {
    nameSuffix = "Retinue", placement = "stationed",
    treasury = {min = 50, max = 100}, supplies = 100, hostile = false,
    members = {
        {id = "minotaurs", troopType = "gaia_minotaur_naked",
            count = {min = 3, max = 4}, chance = 1},
        {id = "warhammers", troopType = "gaia_minotaur_warhammer",
            count = {min = 2, max = 4}, chance = 1},
        {id = "warrior", troopType = "gaia_minotaur_warrior_commander",
            count = 1, chance = 0.5},
    },
},
```

This always creates 3–4 plain Minotaurs and 2–4 warhammer Minotaurs, plus a 50% chance
of one warrior. The chieftain is additional to these followers. `chance = 1` means
100%, `0.5` means 50%, and `0` means absent. Chance is checked **per attempted unit**:
`count = 4, chance = 0.5` produces 0–4 followers, not a single coin toss for a whole
four-unit group. Fixed counts and ranges work the same way for each entry.

Each member entry selects exactly one `troopType`, `archetype` or cultural `role`.
`troopType` directly chooses an existing ordinary unit template with its own stats,
appearance and equipment. It needs no extra NPC archetype file, receives a unique
actor ID, and has no personal NPC memory/goals. Use `archetype` for an important
follower such as a healer; use `role` for culture-specific substitution. Entry `id`
is just a stable configuration/RNG key such as `warhammers`, not an actor ID.

Inline parties use the checked `PartyDefinition` and `PartyMember` types. For a
composition shared by several archetypes, `party = "warrior_retinue"` still references
a separate template. That reusable file uses `PartyTemplate.new` and adds an ID:

```lua
return PartyTemplate.new {
    id = "warrior_retinue", nameSuffix = "Retinue", placement = "stationed",
    treasury = {min = 50, max = 100}, supplies = 100, hostile = false,
    members = {{id = "warriors", role = "retinue_warrior", count = {min = 4, max = 8}}},
}
```

Resident slots can replace an inline or named default, or use `party = false` to
remain independent. Faction slot overrides have highest precedence. A party override
replaces the whole composition; it does not silently merge member lists.

Member counts are additional to the actual leader. Multiple entries can mix troops
and important followers; member rules support counts, chance and conditions. Nested
parties are rejected. `stationed` keeps the party at its settlement; `world` registers
it on the map at that location's valid position. Placement issues no movement order:
existing leader goals decide what happens. Existing service eligibility still applies.
All initialized member gold moves into party treasury alongside explicit template funds.

A garrison suppresses its commander's default personal retinue, so one actor never
commands two initial parties. Explicitly requesting both is rejected. The commander
slot must be guaranteed and unique. All membership uses normal location/party APIs.
Population happens once per location/campaign and never rerolls on a visit.

## Adding a new action: the Wizard Tower example

The implemented `locations/wizard_tower.lua` uses its own `wizard_tower` ID, not a
shrine alias. It is hidden, has no caravan/recovery stop eligibility, and explicitly
lists:

```lua
actions = {{label = "Examine the tower", action = "examineWizardTower"}},
```

Its separate population profile creates one `tower_wizard` actor. The background
currently reuses the shrine artwork, which has no effect on gameplay eligibility.
The action registration is in `src/systems/location_action_registry.lua`:

```lua
Actions.register("examineWizardTower",
    "src.systems.location_actions.examine_wizard_tower", "execute")
```

The individual module exports `execute(location)` and opens an ordinary description
dialogue for the actual location. It adds no spell-teaching or research mechanics.
Existing action implementations remain in `location_actions.lua`; new implementations
can have individual modules. Unknown action IDs fail catalog validation; missing handler
functions fail startup validation. There is no silent no-op fallback.

To add another action, implement its module/function, register its unique action ID,
and list that ID in the location's `actions`. To reuse an action at another place,
only add its existing ID to that location definition.

## Scenario placement and verification

The existing initializer accepts site overrides. For example:

```lua
require("src.game.game_initializer").initNewGame({
    debugCampaign = "normal",
    siteOverrides = {
        debug_site_C3 = {definition = "wizard_tower", name = "The Veiled Spire"},
    },
})
```

The normal menu/CLI performs its own world-state transition; a synchronous caller
in an initialized development session can then call `StateManager.swap("world")`.
Source sites can supply definition/culture/faction/populationProfile/name/prosperity/
population/tags; `siteOverrides` wins. Explicit definitions bypass the placement lottery.
The debug board deliberately reveals locations and retains its fixed grid roads, so use
an ordinary campaign or the focused visibility test when checking hidden discovery.

The unchanged debug launch is:

```powershell
& 'C:\Program Files\LOVE\love.exe' . --debug-campaign
& 'C:\Program Files\LOVE\lovec.exe' tests/unit location_types_scenario
& 'C:\Program Files\LOVE\lovec.exe' tests/unit population_scenario
& 'C:\Program Files\LOVE\lovec.exe' tests/unit retinue_scenario
```

A3 demonstrates a Minotaur chieftain with a personal retinue; B3 demonstrates a
Pelasgian fort garrison. F1 shows actual type IDs, supported stop rules, action counts,
archetypes, party membership and resources. Seeded per-site/per-slot streams preserve
fresh-launch reproducibility. No offers, knowledge, obligations, battles or caravan
outcomes are fabricated by these definitions.

Verification on 2026-10-27: **28 of 29 scenarios passed independently**. The inline-party
test checks the requested troop counts across 32 seeds, optional warrior presence/absence,
fresh-launch reproducibility, non-shared data, direct troop identity/membership, inline
slot overrides, and invalid compositions. The known
`headless_battle_scenario` timeout persists at line 152 (4000 ticks, nil winner).
`world_encounter_scenario` and `battlefield_remains_scenario` pass. The new typed-location
scenario verifies strict field/range/enum checks, real recovery and caravan eligibility,
explicit recruitment pools, hidden discovery, action dispatch and missing-handler errors.
It was rerun after the final test additions and passes. `git diff --check` passes.
Rendering checks are automated; a complete human walkthrough is not claimed.
