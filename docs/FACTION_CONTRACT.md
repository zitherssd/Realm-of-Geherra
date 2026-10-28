# Faction identity contract

Established by the F1 cleanup on 2026-10-28. This contract reconciles identifiers and content references; it does not define diplomacy, political hierarchy, reputation storage, or new recruitment balance.

## Canonical identities

[src/data/factions.lua](../src/data/factions.lua) returns the table loaded by the existing [faction manifest](../src/data/population/factions/index.lua). Population, recruitment and encounters use that same identity set. There is no second presentation catalog or faction-ID alias resolver. Records remain in `src/data/population/factions/`; their existing population defaults/overrides and retained presentation metadata live together.

| Faction ID | Meaning in the current game | Default site culture | Existing recruitment policy |
| --- | --- | --- | --- |
| `menari` | Existing Menari collective affiliation | `generic` | Menari pools |
| `dacians` | Existing Dacian collective affiliation | `generic` | Dacian pools |
| `hyperboreans` | Existing Hyperborean collective affiliation | `generic` | Hyperborean pools |
| `pelasgian_clan` | The authored Pelasgian political group, with its own fort overrides | `pelasgian` | Former `pelasgians` tribal roster |
| `minotaur_clan` | The authored Minotaur political group | `minotaur` | Neutral fallback, unchanged |
| `bandits` | Existing bandit-group affiliation | `generic` | Neutral fallback, unchanged |
| `undead` | Existing Undead Forces affiliation used by encounters/ruin battles | `generic` | Neutral fallback, unchanged |
| `neutral` | Unaligned sentinel; not a political organization | `generic` | Neutral pools |

The original default campaign ownership list remains `menari`, `dacians`, `hyperboreans`, `neutral`. Registering `undead` does not add undead settlements to generation. Clan IDs were already active in the debug campaign, explicit sites, population fixtures and NPC factories. No active faction ID was renamed; the orphan recruitment key `pelasgians` was changed to `pelasgian_clan`.

Menari, Dacians and Hyperboreans have broader demographic/mythic descriptions, but are already operational affiliation IDs. Keeping those IDs does not assert that each people forms one centralized state. Splitting them into additional political groups requires authored groups and is outside this cleanup.

## Culture and affiliation stay independent

The current [culture manifest](../src/data/population/cultures/index.lua) defines `generic`, `pelasgian`, and `minotaur`. These select names and cultural role mappings; they are not faction IDs. The old plural `pelasgians` was a broad people/lore label, not a registered political group. It is neither a culture-ID alias nor an alias for membership in the clan. Its original description/color are retained in the [legacy lore archive](DATA_DEFINITION_CONCEPTS.md#legacy-faction-lore).

A location's `faction` denotes ownership/affiliation. Its `culture` is independently authored; site generation uses the owning faction's `defaultCulture` only when the site does not supply a culture. A Minotaur-culture fort owned by `pelasgian_clan` therefore keeps Minotaur residents and a Minotaur commander. The clan's existing garrison-role override still supplies Pelasgian veteran guards, and its guaranteed-healer override still applies. No culture is inferred from a faction ID's spelling or from a troop's `type`.

[NpcFactory](../src/systems/population/npc_factory.lua) retains its existing explicit context behavior: `faction` defaults to `neutral` and `culture` defaults to `generic` when omitted. The population factories supply both resolved values. Personal retinue/garrison parties inherit the originating location's faction. Directly assembled troops need not carry personal affiliation; party affiliation can supply context, as it already does for encounters and battlefield history. This batch does not force every party member to share a political identity or rewrite memberships on ownership changes.

## Recruitment selection and fallbacks

[RecruitmentSystem.roll](../src/systems/locations/recruitment_system.lua) uses:

1. `location.faction`, defaulting to `neutral` only when absent. Unknown IDs are rejected; a typo must not silently recruit neutral soldiers.
2. The faction's authored pool table, or the neutral table if that known faction has none.
3. The location definition's existing `rules.recruitmentPool`, or `default` if omitted.
4. That table's selected pool, or its required `default` pool.

Recruitment follows political policy, not local culture. For example, a `pelasgian_clan` fort uses its authored castle roster (`pelas_skirmisher`) even if local residents have Minotaur culture. A culturally Pelasgian location owned by `menari` uses Menari pools. Fort/castle and trading-town/town pool mappings remain unchanged. No new Minotaur, bandit or undead roster was invented; existing neutral fallback is preserved for those groups. The roll probabilities, recruitment counts, costs, and troop definitions are unchanged.

## Definition boundaries and consumers

| Boundary / consumer | Contract |
| --- | --- |
| Faction manifest and [existing faction type](../src/data/types/faction.lua) | Key/embedded-ID equality; required default culture; optional retained `name`, `description`, and numeric color metadata. |
| [Catalog.validate](../src/data/population/catalog.lua) | Validates faction IDs/default cultures, existing garrison/resident overrides, faction conditions, campaign default faction references, recruitment faction/troop references and nonempty default pools, encounter-pool factions and quest party-spawn factions. |
| [Location population planning](../src/systems/population/location_population_system.lua) | Validates explicit site/override faction and culture before creating any locations; culture override remains independent of ownership. |
| [NPC factory](../src/systems/population/npc_factory.lua) | Validates explicit faction/culture context against those same catalogs. |
| [Recruitment](../src/data/recruitment.lua) and recruitment system | Canonical faction keys; neutral fallback for known groups without a roster; unknown faction rejection. |
| [Encounter templates](../src/data/encounters.lua), [quest starts](../src/data/quests.lua), [location actions](../src/systems/locations/location_actions.lua) | Keep the existing `neutral`, `bandits`, and `undead` IDs and compositions. No spawn weights, troop counts or hostility rules changed. |
| [Starter parties](../src/game/game_initializer.lua), [debug campaign](../src/debug/campaign_fixture.lua), [caravans](../src/systems/services/caravan_system.lua) | Existing assignments/copies already use canonical IDs; no initialization changes were needed. |

Reference checks were added to the existing catalog validation pass, not a new registry/schema framework or a restriction on arbitrary historical snapshot restoration. The plain faction entry point loads record shapes/manifest IDs without depending on the population catalog, avoiding a recruitment/population import cycle.

## Retained information and unresolved decisions

Names, colors and descriptions for `menari`, `dacians`, `hyperboreans`, `neutral`, `bandits`, and `undead` are copied unchanged into the canonical records. The two existing clans receive specific display names. The entire old faction catalog is also preserved verbatim in the lore archive, including the broad Pelasgian description; no historical color was arbitrarily assigned to a specific clan. Presentation metadata remains optional because a new political group need not invent a color/lore entry to participate in population generation.

`retrieve_amulet.rewards.reputation.kingdom` remains an unresolved legacy reputation-source label, not a newly invented faction. The existing reputation API accepts arbitrary source strings. Deciding whether that old quest should reward Menari standing, a new authored kingdom, or another source needs quest-design intent; this cleanup does not change rewards or claim to resolve that separate namespace. Likewise the membership/reputation overlap (F2) and faction-derived hostility (F3) remain outside F1.

No automatic migration of external `pelasgians` faction data is provided: authors must choose an actual political group and a separate culture. The game's general save module is still a stub; existing serializer/history formats were not changed.

## Verification and change scope

[faction_identity_scenario.lua](../tests/unit/faction_identity_scenario.lua) checks all eight IDs, shared catalog identity, retained metadata, invalid references and missing/empty recruit pools, all fallback paths, culture-independent recruitment, mixed-culture occupation, faction garrison/resident overrides, NPC context validation, and rejection of invalid sites before partial generation. The existing population scenario also passes independently.

The full suite passes: **34 scenarios plus navigation tests**, including the prior data-definition regression scenario. Command: `& 'C:\Program Files\LOVE\lovec.exe' 'D:\Projects\Realm-of-Geherra\tests\unit'`.

Changed production files are the faction entry point, existing faction manifest/records/type (plus the new `undead.lua` record), recruitment data/system and population catalog validation. The new regression scenario is registered in `tests/unit/main.lua`. Documentation updates are this contract, the audit status, population authoring guidance and the legacy lore archive. No diplomacy, archetype, inventory, reputation-storage or hostility implementation changed.
