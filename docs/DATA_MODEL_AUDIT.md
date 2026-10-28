# Data Definition and Configuration Semantics Audit

Audit date: 2026-10-28. Scope: authored game content, configuration, hydration, and the runtime records needed to establish their meaning. This is a static semantics audit, not a code-quality review or a general bug list. No source changes are proposed as part of this document.

### Conservative cleanup status (2026-10-28)

The findings below describe the pre-cleanup snapshot. The following independently scoped changes have since been implemented; other findings remain outside this batch:

- **L4:** removed the unread `visibility.hiddenLocationTypes` list, retaining `radiusDivisor` and all definition-level `hidden` flags. Archived the entire unwired static-location catalog in [design concepts](DATA_DEFINITION_CONCEPTS.md#handcrafted-locations); updated the location-assemblage comment and population-authoring reference.
- **T3:** archived the unused progression catalog verbatim in [progression proposals](DATA_DEFINITION_CONCEPTS.md#progression-proposals). The live progression system, proposed future mechanics and balance values are preserved; only the misleading executable catalog was removed.
- **I4 (marker only):** removed the three unread `questItem = true` flags. Quest item IDs, `type = "quest"`, values, weights, descriptions, potion effects, food definitions and all unfinished mechanics remain unchanged.
- **D1:** made the shared elder introduction name-neutral. Generated actor names and the existing speaker-heading behavior remain authoritative; dialogue options and relationship actions are unchanged.
- **C1:** extracted the manifest loader's existing key/ID assertion into `Registry.checkId`, reused by item, troop and dialogue aggregation and skill/quest table initialization. Existing duplicate checks and embedded IDs remain. Typed population manifests retain the same check. Statuses have no embedded ID; goal/capability registration constructs IDs from keys. The unused faction presentation catalog is left untouched, with its namespace/design questions deferred.

Consumer verification repeated repository searches for `hiddenLocationTypes`, `static_locations`, `data.progression` and `questItem`, then inspected visibility/population initialization, progression, item construction, registry aggregation and dialogue rendering/action consumers before edits. No runtime/test reader of the removed configuration or marker was found. Regression coverage is in [data-definition scenarios](../tests/unit/data_definitions_scenario.lua), including valid/invalid IDs, catalog validation coverage, malformed imported records and elder identity/interaction behavior. The full suite entry point is [tests/unit/main.lua](../tests/unit/main.lua).

Validation: the pre-change baseline passed all 32 scenarios plus navigation tests. After cleanup, the focused data-definition scenario and the full suite passed (33 scenarios plus navigation tests) using `& 'C:\Program Files\LOVE\lovec.exe' 'D:\Projects\Realm-of-Geherra\tests\unit'`. Both archived Lua snapshots were compared with their original Git contents and match apart from line endings/trailing whitespace. `git diff --check` passed. No manual gameplay session was performed.

Design decisions remain deferred: handcrafted coordinates/faction ownership, progression thresholds and unlock/scaling mechanics (including the old undefined `slash` ID), and whether key-only registries should eventually remove their embedded IDs. This batch validates existing representations rather than choosing new ones.

## Assessment and priorities

F1 follow-up (2026-10-28): implemented the [faction identity contract](FACTION_CONTRACT.md).
The faction entry point now shares the existing manifest table, including `undead`;
legacy presentation metadata is retained in those records and broad Pelasgian lore
is archived. Recruitment uses `pelasgian_clan`, rejects unknown IDs and preserves
neutral fallback for known groups without rosters. Existing catalog validation now
checks recruitment, campaign defaults, encounters and quest party-spawn faction
references. Culture overrides and faction-specific composition remain independent.
Focused tests and the full suite pass (34 scenarios plus navigation). The historical
F1 finding below describes the prior state; F2/F3 and legacy reputation-source
semantics remain deferred.

The model already has useful boundaries: location definitions describe kinds of places; population profiles describe initial occupants; cultures resolve roles; archetypes specialize troop templates; runtime entities own changing health, inventories, activities, and knowledge. Preserve these boundaries. The main problem is that several older catalogs and fallback paths still describe a different model, while some live fields promise effects that their consumers never implement.

Priority measures architectural significance, not crash severity:

- **P1:** contradictory authorities, lost authored meaning, or responsibilities that prevent independently meaningful content differences.
- **P2:** unclear contracts, inconsistent representations, or configuration whose apparent scope differs from its effective scope.
- **P3:** removable defaults, dormant metadata, or local naming cleanup.
- **Keep:** justified existing data; no removal or relocation recommended.

| Order | Finding | Smallest useful direction |
| --- | --- | --- |
| P1 | F1: faction namespaces disagree | Establish canonical faction IDs and explicitly distinguish culture from faction. |
| P1 | N1: archetype behavior leaks from troop identity | Let existing archetypes override merchant/quest/dialogue policy where actual variants need it. |
| P1 | T1: authored protections are not hydrated | Connect the existing intrinsic property to actors; do not delete meaningful resistances. |
| P1 | Q1–Q2: quest declarations exceed their effective contract | Remove/archive unsupported example declarations; make repeatability consistent. |
| P1 | L2–L3: location identity and cooldown authority overlap | Use one identity and one existing action cooldown definition. |
| P1 | I2: durability has competing representations | Keep capacity in definitions and choose one runtime durability owner. |
| P2 | S1–S3: skill/status fields mix implemented behavior and promises | Remove unsupported values and unused compatibility inputs; document ticks and override semantics. |
| P2 | W1–W3: world generation configuration describes different generators | Identify live configuration, retire orphan configuration, align biome IDs. |
| P2 | F2–F3, G1–G2, I1/I3, T2/T4, N2, Q3–Q4, D1–D2, R1 | Clarify each field's single meaning without introducing new frameworks. |
| P3 | L4, N3, T3, I4, W4, R2 | Delete dormant/default data where no meaningful variation is lost. |

## Method, evidence, and coverage

Definitions were inventoried under all of `src/data`, including every troop group imported by `troops.lua`, the typed population manifests, item groups, dialogues, goals outside `src/data`, and configuration embedded in systems. Traces follow manifests → validation → hydration → gameplay/UI readers. Repository searches include `src`, `tests`, entry points, and documentation. A copied value or debug display alone is distinguished from an operational gameplay read. “No consumer” means no consumer found in the checked-in Lua sources, not a claim about external mods or future plans.

File links are repository-relative; named functions identify the relevant code within each file. Tests are corroborating references and were inspected, not executed. The existing modification to `docs/ARCHITECTURAL_ASSESSMENT.md` is outside this audit and was left untouched.

| Domain / field groups covered | Definition and validation | Initialization and actual reads |
| --- | --- | --- |
| Locations: identity, labels/assets, placement, population/prosperity, visibility, profile, rules, actions, roads, names | [location definitions](../src/data/locations/index.lua); closed [location schema](../src/data/types/location_definition.lua), [rules](../src/data/types/location_rules.lua), [actions](../src/data/types/location_action.lua); cross-references in [Catalog.validate](../src/data/population/catalog.lua) | [LocationPopulation.populate/selectDefinition](../src/systems/population/location_population_system.lua), [location assemblage](../src/ecs/assemblages/location.lua); [location rules](../src/systems/locations/location_rules.lua), [location screen](../src/ui/screens/location_screen.lua), [visibility](../src/systems/parties/visibility_system.lua), [population matching](../src/systems/population/npc_population_system.lua) |
| Population rules: slot ID, role/archetype, count/chance, conditions, enabled, party; garrison role/leader/count/funds | [profiles](../src/data/population/locations/index.lua), [rule schema](../src/data/types/population_rule.lua), [profile schema](../src/data/types/population_profile.lua); catalog validates slot uniqueness, links, guaranteed commanders, and merged faction overrides | [Population.populate/matches](../src/systems/population/npc_population_system.lua); [NPC party factory](../src/systems/population/npc_party_factory.lua) |
| Archetypes: identity/template/title/importance, treasury, goals/capabilities, stats/attributes/equipment, names/dialogue, personal party | [archetypes](../src/data/npc_archetypes/index.lua), [schema](../src/data/types/npc_archetype.lua); `Catalog.validateArchetype` validates references and allowed stat/equipment keys, but not dialogue IDs | [NpcFactory.hydrate](../src/systems/population/npc_factory.lua); [goals](../src/systems/goals/goal_system.lua), [services](../src/systems/services/service_system.lua), [location screen](../src/ui/screens/location_screen.lua), population/party creation |
| Cultures, factions, names: default culture, roles, garrison roles, resident overrides, name-pool IDs and entries | [culture](../src/data/types/culture.lua), [faction population](../src/data/types/faction.lua), [names](../src/data/types/name_pool.lua); catalog validates mapped references and nonempty name arrays | `Catalog.resolveRole`; population and NPC factories; [generic name adapter](../src/data/names/generic.lua) imports the older name list |
| Party templates/members: ID, suffix, placement, treasury/supplies, hostile, members/selectors, count/chance/conditions/enabled | [party definition](../src/data/types/party_definition.lua), [template](../src/data/types/party_template.lua), [member](../src/data/types/party_member.lua); catalog validates selectors and links | [NpcPartyFactory.create](../src/systems/population/npc_party_factory.lua); [party assemblage](../src/ecs/assemblages/party.lua), party/activity/raid systems |
| Troops: ID/name/type/tags, sprite, stats, size/profile/sight, slots/equipment/skills/attributes, innate protections, stock/commerce, loot | [troop aggregator](../src/data/troops.lua) rejects duplicate keys; no complete troop field schema | [Unit.assemble](../src/ecs/assemblages/unit.lua), [NpcFactory](../src/systems/population/npc_factory.lua), [BattleUnit.assemble](../src/ecs/assemblages/battle_unit.lua); combat, rendering, traders, loot generation, quests |
| Items: ID/name/type/description, weight/value, slot(s), stats/protections, granted skill/modifiers, durability, requirements, effects/quest marker | [item aggregator](../src/data/items.lua) rejects duplicate keys; no item field schema; equipment checks requirements/slots at equip time | [equipment](../src/systems/items/equipment_system.lua), battle hydration/combat, [trader](../src/systems/items/trader_system.lua), [shop UI](../src/ui/screens/shop_screen.lua), [quest item construction](../src/systems/quests/quest_system.lua), loot/inventory helpers |
| Skills/statuses: ID/name/type/description, damage/healing/cost, timing/range/AOE/targeting, charges/projectile/on-hit effects; status duration/DOT/canAct | Plain [skills](../src/data/skills.lua) and [statuses](../src/data/statuses.lua); no closed schema | Battle assemblage, [effective skills](../src/systems/battle/combat_system.lua), [decision](../src/systems/battle/decision_system.lua), [execution](../src/systems/battle/execution_system.lua), [range](../src/systems/battle/range_utils.lua), [action gating](../src/systems/battle/battle_unit_system.lua), battle render/UI |
| Goals: type/priority and type-specific inputs; editor fields/defaults/labels/managed | [goal definitions](../src/systems/goals/goal_definitions.lua), `Registry.create/definition`; archetype catalog invokes constructor validation | `GoalSystem.configure` copies config into [npc_goals](../src/ecs/components/npc_goals.lua); goal, service, caravan and activity systems; debug forms |
| Quests/offers: template/giver, procedural/repeatable, objectives/selectors/counts, rewards, start actions; quest pool probability/expiry/cooldown | Plain [quests](../src/data/quests.lua) and [NPC pools](../src/data/npc_quest_pools.lua); no complete template/reference validator | [QuestSystem.activateQuest/generateProceduralQuestOffer/completeQuest](../src/systems/quests/quest_system.lua), [availability](../src/systems/quests/quest_availability_system.lua), [objective records](../src/systems/quests/objective.lua), [quest assemblage](../src/ecs/assemblages/quest.lua), dialogue/log UI |
| Dialogue: node ID/speaker/lines/options, routing, predicates, mutations, actions/costs/display | [registry](../src/data/dialogue.lua) rejects duplicate keys; no closed node/action/reference validator | [dialogue state](../src/game/states/dialogue_state.lua), [dialogue variables](../src/systems/social/dialogue_system.lua), [dialogue screen](../src/ui/screens/dialogue_screen.lua) |
| Encounters: tuning, threat bands, weighted pools, identity/hostility/dialogue, troop counts | Plain [encounters](../src/data/encounters.lua); no full catalog validation | [EncounterSystem.computeThreat/pickTemplate/spawnEncounterParty](../src/systems/campaign/encounter_system.lua); party AI/interaction |
| Progression, visibility, world generation, campaign defaults | [archived progression](DATA_DEFINITION_CONCEPTS.md#progression-proposals), [visibility](../src/data/visibility.lua), [world generation](../src/data/world_generation.lua), [population settings](../src/data/population/settings.lua); ordinary tables | Progression data has no reader; visibility divisor is read; [painted loader](../src/world/generation/painted_map_loader.lua) reads only its relevant subset; population reads `defaultFactions` |
| Other configuration/runtime records | [map generator CONFIG](../src/world/generation/map_generator.lua), recovery/service/goal/caravan constants, [conf.lua](../conf.lua); event/loot/remains serializers validate their own payloads | Owning systems and LÖVE; event, knowledge, activity and remains records are runtime products, not additional authored content catalogs |

### C1 — P2: catalog key versus embedded ID has inconsistent authority

**Classification: Inconsistent representation; Redundant or derivable.** The typed manifests use [Registry.load](../src/data/definition_registry.lua) to require that an entry's `id` equals its manifest key. [Items](../src/data/items.lua), [troops](../src/data/troops.lua), and [dialogues](../src/data/dialogue.lua) check duplicate outer keys but do not check embedded ID agreement; plain skills/quests have no equivalent registry check. This distinction matters: quest construction and troop lookup principally use outer keys, whereas item construction/rewards and combat's effective-skill lookup also use embedded IDs. There is no known current mismatch claimed here, but the representations can contradict each other without being rejected.

**Smallest improvement:** validate key/ID equality at existing aggregation boundaries wherever both are operationally needed. Remove an embedded ID only where all readers already use the key, as with the dialogue cleanup in D3. Do not independently re-key instances, and do not impose one new universal schema on every domain. The typed population catalog already demonstrates enough of the required pattern.

## Locations

### L1 — Keep: separate location capabilities are justified

**Classification: Justified existing data.** `rules.caravanStop`, `rules.recoveryStop`, `rules.recruitmentPool`, `roadWorthy`, and `hidden` need not be derivable from location identity or from each other.

**Trace:** [village](../src/data/locations/village.lua), [fort](../src/data/locations/fort.lua), [trading town](../src/data/locations/trading_town.lua), and the other definition files → typed rules/location schemas → `Catalog.validate` → [LocationRules](../src/systems/locations/location_rules.lua). `canHostCaravan` is read by [CaravanSystem](../src/systems/services/caravan_system.lua); `canRecover` by [GoalSystem.requestActivity](../src/systems/goals/goal_system.lua) and [Services.tryRecoveryHealing](../src/systems/services/service_system.lua); `recruitmentPool` by [RecruitmentSystem.roll](../src/systems/locations/recruitment_system.lua). `roadWorthy` selects road endpoints in `LocationPopulation.populate`; `hidden` initializes sticky `location.discovered`, subsequently updated by visibility.

These are authored capabilities/defaults, not ongoing state. Equal current booleans are not evidence of equivalence: a roadside stop can lack healing, and a hidden site can still have roads. A fort intentionally selects the castle recruit pool while retaining its own type, art and population. A recruitment pool selects troops; it does **not** grant a recruitment action. Recovery eligibility means the location can be selected for recovery/healing, not that a healer must be present or that passive healing is forbidden elsewhere.

**Smallest improvement:** retain the fields and document those meanings in `location_rules.lua` annotations. Describe `hidden` as “initially undiscovered.” Do not introduce a generalized service schema or infer any of these from `type`, `population > 0`, or the presence of one NPC. Existing [location-type tests](../tests/unit/location_types_scenario.lua) provide a place to preserve independent variation.

### L2 — P1: one location identity has several writable names

**Classification: Redundant or derivable; Inconsistent representation.**

**Trace:** definitions have one `id`; [LocationPopulation.populate](../src/systems/population/location_population_system.lua) accepts site `definition`, `definitionId`, and `locationType`, and override `definition`/`locationType`, with precedence. It sets both `location.definitionId` and `location.type` to the same value, then both site `definitionId` and `locationType`. Validation checks the selected ID, not agreement among aliases. [LocationRules.definition](../src/systems/locations/location_rules.lua) and the location UI prefer `definitionId`; [QuestSystem._resolvePickTarget](../src/systems/quests/quest_system.lua) reads `loc.type`.

The aliases have no demonstrated distinct semantics. A change to one can change quest eligibility without changing capabilities or art. This differs from a legitimate instance ID versus template ID distinction.

**Smallest improvement:** pick the existing `definitionId` as the canonical type reference, update quest/type consumers and site fixtures together, and remove aliases after updating checked-in callers. Until that cleanup, reject disagreeing inputs at population initialization. No new location taxonomy is needed. Relevant callers/fixtures include [debug campaign fixture](../src/debug/campaign_fixture.lua), [population scenarios](../tests/unit/population_scenario.lua), and [location-type scenarios](../tests/unit/location_types_scenario.lua).

### L3 — P1: action cooldown configuration is only partly authoritative

**Classification: Inconsistent representation; Misplaced responsibility.**

**Trace:** [village.actions](../src/data/locations/village.lua) declares `cooldown = {key = "lastRecruitDay", days = 5}`; ruins and shrine similarly declare keys/durations. The [action schema](../src/data/types/location_action.lua) and catalog validate shape/positive days. [LocationScreen.refreshButtons](../src/ui/screens/location_screen.lua) reads both key and duration to disable the button. [LocationActions.startRecruitmentDialogue](../src/systems/locations/location_actions.lua) separately checks literal `"lastRecruitDay", 5`; roll/hire/perform recruitment write that literal field. Explore/pray handlers likewise write their own known timestamp fields.

A definition edit can change UI availability without changing the handler's enforcement; renaming `key` can disconnect the UI from the timestamp. Cooldown duration is valid content policy, and the last-use day is correctly instance state. Their contract is duplicated.

**Smallest improvement:** have the existing handler/check path obtain the configured action cooldown and use the same key/days as the UI. Preserve per-definition durations. Do not add a cooldown service or new flags. If keys are intentionally fixed by action, validate that agreement instead of presenting them as arbitrary author choices.

### L4 — P3: obsolete hidden-type configuration and dormant location concepts

**Classification: Unused or obsolete; Redundant or derivable.**

**Trace:** [visibility.hiddenLocationTypes](../src/data/visibility.lua) has no reader; only `radiusDivisor` is read by [VisibilitySystem](../src/systems/parties/visibility_system.lua). Initial discovery comes from definition `hidden` in population initialization. The old list omits `wizard_tower`, which correctly works through the live definition. [Archived static_locations.lua](DATA_DEFINITION_CONCEPTS.md#handcrafted-locations) explicitly says it is unwired and has no `require` consumer; its `meta`, `allowedTypes`, coordinates, ownership, actions and NPC lists are concept notes, not validated live records.

**Smallest improvement:** delete `hiddenLocationTypes` and fix the stale location-assemblage comment pointing at it. Move handcrafted concepts to a design document if retained, rather than leaving them beside executable definitions. Do not implement a second static-location schema just to preserve unused notes.

### L5 — Keep: generation defaults, presentation and population composition have separate owners

**Classification: Justified existing data; Ambiguous semantics (names only).**

`population`, `prosperity`, and `visibility` are generation counts/ranges, validated through `Common.count`, rolled once in [LocationPopulation.populate](../src/systems/population/location_population_system.lua), then stored as instance population/prosperity/profile. Population/prosperity also feed `Population.matches`; population is not a census derived from the few simulated resident actors. `populationProfile` references an initial composition and may be overridden per site, so equality with a location ID is not redundant. `placement.weight/siteSizes/biomeWeights` govern generation eligibility; zero weight deliberately permits explicitly placed forts/towers without random generation. Missing biome bias means 1, not “forbidden.”

`displayName`, `mapMarker`, and `names` respectively drive type label, background asset and generated instance name. Fort/castle and tower/shrine demonstrate asset reuse, so deriving assets from identity would lose meaningful data. In particular, `mapMarker` is currently consumed as a location-screen background name; its name is broader/different than its demonstrated reader.

**Smallest improvement:** document `population` as abstract population and `visibility` as initial detection profile, or rename the latter `profile` to match its runtime meaning. Rename `mapMarker` to describe its actual background-asset role when touching its schema/UI together. Retain independently authored values and profiles. Fixed zero ranges can be scalar `0`; see N3 for the seeded-generation caveat on data cleanup.

## Factions, cultures and allegiance

### F1 — P1: faction identifiers have incompatible catalogs

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** [data/factions.lua](../src/data/factions.lua) defines presentation/lore entries including `pelasgians` and `undead`, but no checked-in Lua code requires it. The live [population faction manifest](../src/data/population/factions/index.lua) instead includes `pelasgian_clan` and `minotaur_clan`, excludes `pelasgians` and `undead`, and is validated by `Catalog.validate`. [RecruitmentData](../src/data/recruitment.lua) has `pelasgians` but no clan keys; [RecruitmentSystem.roll](../src/systems/locations/recruitment_system.lua) falls back to neutral for unknown factions. [encounter pools](../src/data/encounters.lua) can spawn `undead` parties directly without the population catalog. Generated site factions must pass that catalog. There is no validation joining these namespaces or checking recruit troop IDs.

A valid Pelasgian-clan settlement therefore uses neutral recruits, despite authored Pelasgian recruitment. The same string has different allowed values depending on creation route. The old catalog's `name/color/description` cannot currently supply presentation for the live clan IDs.

**Smallest improvement:** choose canonical faction IDs for these actual concepts, update recruitment and creation callers, and validate recruitment references against the chosen existing registry. Decide explicitly whether `pelasgians` denotes a culture or a political faction; do not silently equate every clan with a whole culture. If population factions intentionally cover only factions eligible to own sites, document that subset and validate it against the common ID set. Remove/archive the unused presentation catalog if it has no intended consumer, rather than keeping a second apparent authority. Preserve `defaultCulture` separately: cultural identity and ownership can differ.

### F2 — P2: `factions` means both membership and numeric reputation

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** [Unit.assemble](../src/ecs/assemblages/unit.lua) initializes `factions = {}`; [NpcFactory.hydrate](../src/systems/population/npc_factory.lua) sets scalar `npc.faction` and boolean `npc.factions[npc.faction] = true`. [FactionSystem](../src/systems/social/faction_system.lua) instead defines that map's values as numeric reputation. Its API has no operational call sites found (there is an unused import in world state). Quest rewards use the separate [ReputationSystem](../src/systems/social/reputation_system.lua) and `party.reputation`. [BattlefieldRemains.factionList](../src/systems/battlefield/battlefield_remains_system.lua) interprets truthy map entries or array entries as affiliations; even a negative numeric reputation is truthy in Lua.

**Smallest improvement:** keep numeric reputation in the already-used `reputation` map; retire the unused conflicting faction-reputation API. Document whether plural affiliations are actually needed alongside the scalar primary faction. If not, derive the corpse's affiliation list from that primary value rather than maintaining another live copy. If multiple affiliations are meaningful, retain them explicitly as membership and validate a single shape. Do not merge party reputation with actor membership.

### F3 — P2: `hostile` is not an override of faction-derived hostility

**Classification: Ambiguous semantics; Inconsistent representation.**

**Trace:** party templates require `hostile` in [PartyDefinition](../src/data/types/party_definition.lua), copied by [NpcPartyFactory](../src/systems/population/npc_party_factory.lua). Encounters also initialize `party.hostile`. [PartyInteractionSystem](../src/systems/parties/party_interaction_system.lua), [RaidActivity](../src/systems/world_activities/raid_activity.lua), and [GoalSystem.requestActivity](../src/systems/goals/goal_system.lua) use `hostile == true or faction == "bandits"`. Thus `hostile = false` does not make a bandit party peaceful.

**Smallest improvement:** clarify whether the boolean means “additional hostility” or authoritative party disposition. If peaceful bandit individuals are supported, make the explicit boolean authoritative and apply a faction default only when absent, updating the three existing decision points together. Otherwise document the additive meaning and omit redundant false values where permitted. Do not infer all hostility from faction or build diplomacy rules without a need.

## NPC archetypes, populations and parties

### N1 — P1: archetype meaning is partly controlled by the underlying troop

**Classification: Misplaced responsibility; Ambiguous semantics.**

**Trace:** [healer](../src/data/npc_archetypes/healer.lua) uses troop `elder`; [quartermaster](../src/data/npc_archetypes/quartermaster.lua) and [wealthy_merchant](../src/data/npc_archetypes/wealthy_merchant.lua) use `trader`; cultural specialists use different troops. `Catalog.validateArchetype` validates troop links but the [archetype schema](../src/data/types/npc_archetype.lua) exposes no stock or quest profile override. [NpcFactory.hydrate](../src/systems/population/npc_factory.lua) unconditionally obtains `stock`, buying/pricing/restock policy from the troop. [QuestAvailability.getProfileForNpc](../src/systems/quests/quest_availability_system.lua) calls `npc.troopType or npc.type` a role. [LocationScreen](../src/ui/screens/location_screen.lua) chooses explicit `dialogueId`, otherwise `<troopType>_greeting`.

Consequently a healer can inherit the elder's stock, offers and greeting; a quartermaster inherits trader behavior; culturally equivalent healers can behave differently merely because their combat bodies differ. This is active consumption, not unused data. Troop identity conflates combat template, social role and policy selection.

**Smallest improvement:** retain shared defaults, but let the existing archetype explicitly override the policies for the variants already present. Start with `dialogueId`, which already exists; have quest-profile lookup consider an existing archetype-specific entry before troop fallback. Move or override merchant stock/pricing on archetypes that actually need different businesses. Do not duplicate every troop field in every archetype, infer behavior from display titles, or create a generalized “profession” abstraction. Update factory, stock refresh and relevant tests together so refreshed stock uses the same owner as initial stock.

### N2 — P2: resident selectors can coexist, with silent precedence

**Classification: Inconsistent representation.**

**Trace:** [PopulationRule](../src/data/types/population_rule.lua) allows optional `role` and `archetype`; [Catalog.validateRule](../src/data/population/catalog.lua) requires at least one but accepts both. [Population.populate](../src/systems/population/npc_population_system.lua) uses `rule.archetype or resolveRole(...)`. Faction overrides shallow-merge fields, so an override adding a direct archetype retains the inherited role. By contrast, [PartyMember.validate](../src/data/types/party_member.lua) enforces exactly one `troopType/archetype/role` selector.

**Smallest improvement:** explicitly define an override of `archetype` as replacing role selection and clear the superseded selector during that existing merge, then require one effective selector. Alternatively retain documented explicit precedence, but do not describe the two as independent properties. Avoid merely adding exclusivity validation without adapting the merge, which would reject legitimate cultural/faction specializations.

### N3 — P3: explicit defaults add noise, but not all similar values are redundant

**Classification: Redundant or derivable.**

**Trace:** [fort_guard](../src/data/npc_archetypes/fort_guard.lua), [pelasgian_guard](../src/data/npc_archetypes/pelasgian_guard.lua), and [minotaur_guard](../src/data/npc_archetypes/minotaur_guard.lua) explicitly supply `treasury = 0`, `goals = {}`, `capabilities = {}`. These are optional and [NpcFactory](../src/systems/population/npc_factory.lua) already defaults them. Population rules frequently say `count = 1`; the population and party factories default omitted count/chance to 1. Party templates explicitly say `supplies = 100`, the factory default. Some fixed ranges use `{min = 0, max = 0}` although `Common.count` and `Registry.roll` accept scalar `0`.

**Smallest improvement:** omit optional identity defaults where readability gains are clear. Keep `important`, required `hostile`, and required location booleans until their schemas deliberately change; do not delete required values from data alone. Keep `party = false`: unlike omission it suppresses an archetype's default personal party. Keep nontrivial counts and chances. Keep stable rule/member IDs even when they resemble role names: they address faction overrides and seeded random streams. Data edits that alter random draw count/order must be checked for seeded-generation changes; scalar fixed ranges themselves do not add draws in `Registry.roll`.

### N4 — Keep: importance, role resolution, personal parties and garrisons are distinct

**Classification: Justified existing data.**

`important` is not equivalent to strength, being named, being a leader, or having goals. [NpcFactory](../src/systems/population/npc_factory.lua) uses it to create NPC/memory components, personal naming and goal configuration; `Catalog.validateArchetype/importantLeader` constrains goals and initial party leaders. An ordinary minotaur warrior can have “commander” in its troop ID without becoming an important social actor.

Culture `roles`, faction `defaultCulture`, `garrisonRoles` and `residentOverrides` have demonstrably separate reads in [Catalog.resolveRole](../src/data/population/catalog.lua), [Population.populate](../src/systems/population/npc_population_system.lua), and [NpcPartyFactory](../src/systems/population/npc_party_factory.lua). [Pelasgian clan](../src/data/population/factions/pelasgian_clan.lua) deliberately upgrades fort guards and guarantees a healer without changing every culturally Pelasgian place. A profile's garrison `leaderSlot` binds an existing resident; its `count` describes generated guards, not a duplicate resident count. Do not collapse these overrides into culture alone.

Archetype `party` is a default personal retinue; a resident rule can replace or suppress it. The profile garrison replaces that leader's default party. `placement` determines initial stationed/world registration, not whether movement goals exist. Named templates and inline parties both flow through existing party-definition validation and creation; inline minotaur composition is a meaningful local specialization, not grounds for mandatory reusable templates. See [inline-party](../tests/unit/inline_party_scenario.lua), [retinue](../tests/unit/retinue_scenario.lua), and [population](../tests/unit/population_scenario.lua) scenarios.

### N5 — Keep, with a naming clarification: population conditions are initial-generation conditions

**Classification: Justified existing data; Ambiguous semantics.**

`when.min/maxProsperity`, `min/maxPopulation`, `culture`, `faction`, `biomes` and `tags` are shape/range/reference checked by the catalog where supported, then read by [Population.matches](../src/systems/population/npc_population_system.lua). Location tags are a boolean map; condition tags are an array requiring every listed tag. The representations have different roles and need not be identical. Biome/tag vocabularies are not centrally validated.

Population runs once under `populationInitialized`; ownership or prosperity changes do not continuously reevaluate occupants. `count` is the number of attempts, with `chance` applied per attempt, not a guaranteed final count. These fields belong in composition data. **Smallest improvement:** document initialization-only semantics and “attempts” in authoring annotations. Preserve conditions, explicit disabling and ranges; do not add a respawn policy or dynamic population reconciler without a request.

## Troops, actors and progression

### T1 — P1: intrinsic protections are authored but never initialized

**Classification: Unused or obsolete (effective runtime input); Inconsistent representation.**

**Trace:** [dragon](../src/data/units/neutral/neutral_units.lua) declares `innateProtections`; [minotaur warrior](../src/data/units/gaia/gaia_minotaurs.lua) declares slashing -2, piercing 1, blunt 3. [Unit.assemble](../src/ecs/assemblages/unit.lua) initializes an all-zero map but never reads `data.innateProtections`. `NpcFactory` copies stats/attributes/equipment, not protections. [BattleUnit.assemble](../src/ecs/assemblages/battle_unit.lua), [CombatSystem.getTotalProtection](../src/systems/battle/combat_system.lua), and the [stats panel](../src/ui/widgets/stats_panel.lua) correctly read actor protections, so authored values are lost upstream. No complete troop validator detects that missing hydration.

**Smallest improvement:** copy this existing field into actors during unit hydration and check the declared examples. Keep signed values: the negative slashing value expresses vulnerability, not an invalid count. Resistance is an intrinsic troop property and belongs here; replacing it with system-side monster-ID checks would worsen ownership. This finding concerns the data contract, not a recommendation to rebalance combat.

### T2 — P2: troop `type` and `tags` appear more meaningful than they are

**Classification: Ambiguous semantics; Unused or obsolete.**

**Trace:** troop files mix `type = "pelasgian"`, `"beast"`, `"soldier"`, `"player"`, `"gaia_minotaurs"`, etc. [Unit.assemble](../src/ecs/assemblages/unit.lua) only uses `data.type` for player/companion memory creation; the template key becomes runtime `troopType`. It never copies `tags`, including the companion tag whose comment claims UI filtering. No troop-tag gameplay consumer was found. [NpcFactory](../src/systems/population/npc_factory.lua) later explicitly applies/removes memory from archetype importance. Corpse `species/race` fields are optional runtime reads in [BattlefieldRemains](../src/systems/battlefield/battlefield_remains_system.lua), not populated from this mixed troop type vocabulary.

**Smallest improvement:** remove unsupported troop tags and misleading comments unless a concrete consumer is required. Document/narrow the current `type` contract around its actual initialization role; do not pretend all its values form a species, culture or faction classification. Keep player/companion handling until the actual creation callers supply equivalent identity. Do not derive species automatically from these strings or introduce a taxonomy as part of cleanup.

### T3 — P3: progression configuration is an unused competing balance source

**Classification: Unused or obsolete; Redundant or derivable.**

**Trace:** [Archived data/progression.lua](DATA_DEFINITION_CONCEPTS.md#progression-proposals) declares `experienceTable`, `levelUpBonuses`, and `skillProgression` with `unlockLevel/scalingFactor`; no Lua module requires it. [ProgressionSystem](../src/systems/actors/progression_system.lua) computes `level * 100` and hardcodes +10 health. The catalog's defense/speed bonuses, thresholds and skill unlocks do not apply; `slash` is not a defined skill in the live skill table.

**Smallest improvement:** remove/archive the unused catalog, or wire only the progression values the game intentionally wants to use. Do not retain both descriptions as authoritative and do not implement an unlock/scaling framework just because stale fields exist. Actor level/experience and learned skills remain runtime state.

### T4 — P2: `speed` and health have narrower/different runtime meanings than their names suggest

**Classification: Ambiguous semantics; Redundant or derivable (health mirrors).**

**Trace:** [Unit.assemble](../src/ecs/assemblages/unit.lua) calls `stats.speed` world-map speed, while [PartySystem.getPartySpeed](../src/systems/parties/party_system.lua) averages literal 100 per actor and applies `party.speedModifier`. `stats.speed` is copied into battle stats and displayed by the stats panel, but does not drive the party travel formula; battle timing reads `battle_speed` in [ExecutionSystem](../src/systems/battle/execution_system.lua). Item `stats.speed` bonuses therefore affect displayed data, not demonstrated travel timing.

The same unit constructor initializes `stats.health`, `maxHp`, and current `hp`. [Recovery.maxHealth](../src/systems/actors/recovery.lua) prefers `maxHp`; battle hydration rebuilds maximum HP from stats; progression updates both. Current HP is distinct state, but two independently writable maximum-health values can disagree across consumers.

**Smallest improvement:** document the effective speed contract or remove dormant author tuning until a chosen movement formula reads it. Preserve `battle_speed`, which is active, and do not merge the two speeds. For health, choose an authoritative campaign maximum and derive any required mirrors at the existing boundaries; retain current HP and battle-local HP. Include equipment health bonuses when defining that boundary rather than blindly deleting a maximum field.

### T5 — Keep: size, sight, profile, slots, learned skills and equipment are separate

**Classification: Justified existing data.**

[Unit.assemble](../src/ecs/assemblages/unit.lua) derives default sight/profile from size, then accepts overrides; bandit/player overrides demonstrate intentional stealth/scouting differences. [PartySystem](../src/systems/parties/party_system.lua) aggregates sight/profile; [CombatSystem.rollProjectileHitChance](../src/systems/battle/combat_system.lua) reads size. Size is not merely another name for visibility. Troop `slots` describes body equipment affordances (`war_dog` has a collar); `equipment` describes starting gear; item requirements are checked by `EquipmentSystem.canEquip`. Troop `skills` replaces the default learned attack set; equipment grants battle skills separately. Empty equipment can use the constructor default; empty skills would intentionally remove the default attack, so those two empty tables are not interchangeable cleanup targets.

## Items, inventory and loot

### I1 — P2: `type` mixes category and weapon identity; slot alternatives overlap

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** [ranged_weapons.javelin](../src/data/items/ranged_weapons.lua) assigns `type` twice, first `"weapon"`, then `"javelin"`; Lua retains only `"javelin"`. Other weapon entries retain `"weapon"`. Type is displayed and propagated into [Item.new](../src/entities/item.lua); armor type is operational in [shield combat](../src/systems/battle/combat_system.lua). [EquipmentSystem.itemSupportsSlot](../src/systems/items/equipment_system.lua) accepts singular `slot` or array `slots`, with singular taking precedence. Daggers use arrays; most gear uses a scalar. There is no item schema checking contradictory slot fields or category values.

**Smallest improvement:** remove the javelin's overwritten subtype assignment; identity is already `id = "javelin"`. Retain a consistent category meaning for `type`. For slots, reject simultaneous `slot` and `slots` or use one existing representation when next editing all affected items/callers. Do not introduce a weapon-subtype field unless a consumer needs it.

### I2 — P1: durability mixes definition capacity, copied defaults and runtime condition

**Classification: Redundant or derivable; Inconsistent representation.**

**Trace:** gear in [armor](../src/data/items/armor.lua), [melee](../src/data/items/melee_weapons.lua), and [ranged](../src/data/items/ranged_weapons.lua) repeats equal `durability/maxDurability`. Combat only degrades shields using `defender.itemDurability[itemId]`, defaulting from `maxDurability` in [applyBlockDurabilityLoss](../src/systems/battle/combat_system.lua). Definition `durability` is not a wear input. Stock/loot copies can carry it as metadata. [BattleUnit.assemble](../src/ecs/assemblages/battle_unit.lua) copies runtime durability by item ID; [LootResolver](../src/systems/items/loot_resolver.lua) and [LootApplication](../src/systems/items/loot_application.lua) carry `durabilityRemaining` for loot. [EquipmentSystem.equip](../src/systems/items/equipment_system.lua) accepts only an item ID and does not consume an instance's `durabilityRemaining`.

These are not three implemented durability mechanics. A copied full `durability` can coexist with a worn `durabilityRemaining`; ID-keyed wear cannot distinguish two copies of the same item. Weapon durability currently does not mean weapon degradation. Battle skill charges are a separate per-battle limit, not evidence that javelin durability is consumed.

**Smallest improvement:** remove duplicate definition `durability`, retain `maxDurability` as intrinsic capacity, and document current shield-only wear. Before extending wear, make transfer/equip use the existing instance condition consistently, or explicitly constrain equipment to ID-level condition. Do not add item UUIDs or a generalized instance framework solely for cleanup. Preserve existing remaining-condition metadata while resolving ownership.

### I3 — P2: full item copies and catalog lookups disagree on the source of effective properties

**Classification: Inconsistent representation; Redundant or derivable.**

**Trace:** [Trader.buildStockInventory](../src/systems/items/trader_system.lua) deep-copies full definitions; [QuestSystem](../src/systems/quests/quest_system.lua) constructs `Item` objects with a subset of presentation/value/weight fields; actor inventories initialize as ID→quantity maps and party/trader inventories as lists. [InventorySystem](../src/systems/items/inventory_system.lua) supports both, compares all metadata except quantity for stacking, and refuses metadata-bearing transfers into maps. Equipment stores just IDs and resolves combat properties from `Items`; party list entries can contain snapshots of those same properties.

Thus an item's representation/stackability can depend on whether it came from stock, a quest or a corpse. Changing a copied definition field can distinguish stacks without affecting equipped behavior. The map/list distinction is deliberate and guarded; silently flattening it would lose state.

**Smallest improvement:** use minimal `{id, quantity}` records for ordinary fungible items and retain only meaningful per-instance metadata (such as remaining condition) on list entries. Have display/pricing resolve absent intrinsic fields from the catalog. Update stock, quest rewards, loot and inventory readers together before deleting copies. Keep the explicit list/map conversion restrictions until metadata loss is addressed; do not merely remove `inventoryFormat` because nonempty inventories can be guessed.

### I4 — P3: quest/consumable promises lack gameplay consumers; weight is descriptive

**Classification: Unused or obsolete; Ambiguous semantics.**

**Trace:** [quest_items](../src/data/items/quest_items.lua) uses both `type = "quest"` and `questItem = true`. No `questItem` gameplay reader was found. [health potion](../src/data/items/consumables.lua) declares `effect.healing = 50`; no consumable-use path reads that effect. Food types are catalog labels, not a link to party supply depletion. Item `weight` is stored/copied but no carrying-capacity/encumbrance calculation was found. Names/descriptions/value do have presentation/trade consumers.

**Smallest improvement:** remove the redundant unread `questItem` marker. Clearly mark potion healing and weight/supplies effects as unimplemented rather than treating them as active mechanics; remove unsupported effect data if the content is not meant to advertise future behavior. Keep descriptive weight if intentionally useful metadata, but do not call it a balance control. Do not infer quest protection, food consumption or healing from category names.

### I5 — P2: troop drops and actual possessions are different reward authorities

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** troop `loot` entries (`currency/id`, `chance`, `min/max`) are actively read by [LootGenerator.generateFromTroop/generateFromTable](../src/systems/items/loot_generator_system.lua). [CampaignBattleResolution.resolve](../src/systems/campaign/campaign_battle_resolution.lua) uses them for defeated enemies in the `rewardPolicy == "player"` route. Its NPC route instead uses [LootResolver.resolve](../src/systems/items/loot_resolver.lua), dividing real inventories, equipment and treasury with explicit loot policy; it never consults troop drop tables. Those tables can grant gold or gear independent of actual possessions. This is an explicit branch in current runtime behavior, not evidence that `loot` is dead.

**Smallest improvement:** document `troop.loot` as player-battle generated rewards, not the authoritative contents of a body. Decide whether that asymmetry is intentional before unifying anything. If it is obsolete, retire the generated-reward route and its fields together; do not remove loot tables alone or double-award both sources. Keep operational loot policy on the encounter/resolver, not on every troop.

### I6 — Keep: armor mitigation, accuracy bonuses and weapon skill overrides are distinct inputs

**Classification: Justified existing data, with a contract clarification.**

Item `stats.attack/defense` modify accuracy stats; typed `protections` modify damage reduction in [combat](../src/systems/battle/combat_system.lua). They are not interchangeable armor values. `grantsSkill` makes the skill available; `skillModifiers` specializes it for the granting equipment. [CombatSystem.getEffectiveSkill/_getSkillModifiers](../src/systems/battle/combat_system.lua) copies the base definition and replaces specified fields, preferring main hand, then ranged, then other slots. `baseDamage` overrides are meaningful; equal item and base-skill values (javelin/sling) are optional repetition under the present base definitions, but could intentionally pin weapon balance independently of a future base change.

**Smallest improvement:** document that “modifiers” are replacements, including replacement of entire nested status/projectile tables, not additive bonuses or recursive merges. Do not remove equal overrides without deciding whether inheritance is intended. See S3 for base/effective charge initialization. No new damage schema is needed.

## Skills and statuses

### S1 — P2: `cost` and `healing` have no execution semantics

**Classification: Unused or obsolete; Ambiguous semantics.**

**Trace:** [skills](../src/data/skills.lua) declares positive spell costs and `heal.healing = 50`. [CombatSystem.getEffectiveSkill](../src/systems/battle/combat_system.lua) copies them, but [DecisionSystem](../src/systems/battle/decision_system.lua) and [ExecutionSystem](../src/systems/battle/execution_system.lua) do not spend a resource or apply a healing amount. Skill execution follows attack/projectile/AOE paths. Copying fields into an effective table is not consumption. There is no complete skill-schema validation of these promised mechanics. `cost = 0` is equally inert.

**Smallest improvement:** remove unused costs and keep the heal entry out of usable content until an actual healing action contract is supported. Retain a design note if intended; do not introduce mana or a generic effect interpreter to rescue unused fields. The existing world healing service is a different action with price and amount owned by `ServiceSystem`, not a consumer of `heal.healing`.

### S2 — P2: status authoring accepts obsolete shapes, while freeze's description exceeds its behavior

**Classification: Inconsistent representation; Unused or obsolete; Ambiguous semantics.**

**Trace:** all authored on-hit lists are arrays of status IDs in [skills](../src/data/skills.lua) and [weapons](../src/data/items/melee_weapons.lua). [ExecutionSystem.applyOnHitStatuses](../src/systems/battle/execution_system.lua) also accepts map values as numbers/booleans/tables, duration aliases `duration/remaining/ticks`, and DOT aliases `damagePerTick/damage_per_tick`, `tickEvery/tick_every`. No checked-in caller needing the latter legacy input variants was found. Runtime status records legitimately contain `remaining`, `duration`, source skill and tick counters. [BattleUnitSystem.canAct](../src/systems/battle/battle_unit_system.lua) reads `canAct` from the canonical status catalog by ID, not an inline override.

`burn/poison` duration/DOT fields affect execution; `stun/paralyze.canAct = false` prevents actions. `freeze` has duration and zero DOT but no slowing parameter or slowing reader. The renderer shows freeze visually, so the whole status is not unused; its description “Slowed movement and action speed” is unsupported. Status descriptions have no dedicated gameplay reader.

**Smallest improvement:** retain the authored ID-array form and remove unneeded compatibility aliases/inline variants after updating any fixtures that actually depend on them. Keep runtime counters distinct from definition duration. Change freeze's description to match its present effect or defer the status's advertised gameplay effect; do not invent slowing flags merely to justify the text. Omit explicit zero DOT where absence already means zero. [Combat regression scenarios](../tests/unit/combat_regression_scenario.lua) verify status application, not the advertised freeze slowdown.

### S3 — P2: timing units and effective-skill boundaries are insufficiently explicit

**Classification: Ambiguous semantics; Inconsistent representation.**

**Trace:** skill `windup/cooldown` and status `duration/tickEvery` decrement once per battle tick in [ExecutionSystem](../src/systems/battle/execution_system.lua). [BattleState](../src/game/states/battle_state.lua) schedules ticks at 20 Hz and [BattleSimulation.tick](../src/game/battle/battle_simulation.lua) advances the simulation; headless stepping uses the same tick operation. The battle assemblage comment calls cooldown-map values seconds even though the execution contract is ticks. Skill `range` scales through [RangeUtils](../src/systems/battle/range_utils.lua) by 42 into world coordinates. Projectile `speed` advances world-coordinate distance per tick, not per second; AOE radius is `max(24, aoe * 42 * 0.8)`. Projectile `sprite/style/arc` are presentation inputs as well as projectile configuration, not additional damage types.

Effective skills replace all specified item fields, but [BattleUnit.assemble](../src/ecs/assemblages/battle_unit.lua) initializes `charges` from base `Skills[skillId].maxCharges`; decision/execution check effective `maxCharges`. Current items do not override charges, so this is a latent contract disagreement, not a claimed current content failure. The AI also reads `damageMultiplier` for selection, while no authored skill supplies it; `baseDamage` is the real damage input.

**Smallest improvement:** document ticks, scaled range, and projectile units next to definitions; correct the seconds comment. Either constrain supported item overrides to the fields the complete pipeline honors or initialize charges from the same effective skill. Remove/update the unused AI selection-property contract instead of introducing a redundant `damageMultiplier` across skill data. Keep `targeted` independent of `type = "aoe"`: it distinguishes point targeting and is read by range/decision/execution.

## Goals, capabilities and runtime activities

### G1 — P2: `acquire_gold.amount` claims one resource scope but evaluates two

**Classification: Ambiguous semantics.**

**Trace:** [goal definitions](../src/systems/goals/goal_definitions.lua) label it “Party treasury target” and validate a nonnegative number. [GoalSystem.condition](../src/systems/goals/goal_system.lua) uses party treasury if a commanded party is supplied, otherwise personal treasury. [wealthy merchant](../src/data/npc_archetypes/wealthy_merchant.lua) starts as a resident with personal funds and an acquire-gold goal; caravan formation is an additional method, whereas raiding requires a hostile traveling party. An acquire-gold goal is not itself a raid instruction.

**Smallest improvement:** document/label the target as the acting actor's available treasury scope and state when it switches to commanded-party funds. If the intended target is strictly personal wealth, choose that scope in the current condition and adapt the actual merchant behavior; do not add a scope enum without a demonstrated need for independently configurable scopes. Keep amount, goals and capabilities separate: wanting money does not imply permission or ability to raid.

### G2 — P2: goal input validation drops unknown fields and has a UI/config shape mismatch

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** [NpcArchetype](../src/data/types/npc_archetype.lua) validates `goals` only as tables; catalog calls [Registry.create](../src/systems/goals/goal_definitions.lua). That constructor copies only registered non-UI fields and explicitly builds `acquire_gold.roam`, silently ignoring other inputs. The goal editor represents `roam` as a boolean plus flat coordinate/radius controls; authored config requires a nested roam record with either a location ID or coordinates. `uiOnly/readForm/writeForm` intentionally translate between these shapes, but `spec.fields` is therefore not a complete runtime configuration schema. Runtime-created capabilities are validated less strictly by `GoalSystem.configure` than catalog archetype capabilities, which must be registered.

**Smallest improvement:** document the nested authored shape and reject unrecognized authored keys at the existing constructor boundary, while preserving the explicit form translation. Use the existing capability registry for all configuration entry points if registration is the intended contract. Do not move runtime `status/attempts/retrySeconds/activity/recovering` into archetypes or add a second goal registry. [NPC-goal scenarios](../tests/unit/npc_goals_scenario.lua) are the existing behavior checks to extend when this contract is tightened.

### G3 — Keep: goals, capabilities, policies and state belong at different boundaries

**Classification: Justified existing data.**

`goals` express desired outcomes, `capabilities` permitted methods. Goal `priority`, `amount`, destination and optional roam territory can vary meaningfully per actor and belong in archetype/actor configuration. `Registry.create` supplies mutable status/attempt counters; `GoalSystem.configure` creates actor-owned `npc_goals`; activity components own current waypoints/timers/contact/sequence, and service acceptance creates `fulfill_obligation`. The catalog and goal configuration explicitly prohibit fabricating that managed obligation in authored archetypes.

Labels/editor defaults/`managed` in [goal definitions](../src/systems/goals/goal_definitions.lua) have actual debug-form consumers and can stay beside the runtime constructor registry. They do not force every goal parameter into UI-only configuration. Global retry/evaluation timing, [recovery thresholds/rates](../src/systems/actors/recovery.lua), [service amounts/prices](../src/systems/services/service_system.lua), and [caravan policy](../src/systems/services/caravan_system.lua) can stay with their current systems until real content differences need overrides. Their being gameplay-specific is not an argument for moving all of them into content files.

## Quests and quest offers

### Q1 — P1: authored objective shapes and story claims exceed the supported model

**Classification: Unused or obsolete; Ambiguous semantics; Inconsistent representation.**

**Trace:** [retrieve_amulet/join_army](../src/data/quests.lua) use objective `item`, `npc`, and `location` fields; [QuestSystem.activateQuest](../src/systems/quests/quest_system.lua) copies only `type`, `target`, `required`, `description`, and resolved `pickTarget` details. Those additional fields never reach [Objective](../src/systems/quests/objective.lua). Runtime progress producers in `QuestSystem` handle `kill_party`, location-entry `travel`, and `report_to_giver`; no producers were found for the example `collect/deliver/talk/reach` objectives. Those old templates are not in the live NPC offer pools. Targets such as `mountain_cave`, `ancient_amulet`, and reputation key `kingdom` are not checked against live catalogs.

Live message/bundle quests give an item through `onStart`, but their objective is reaching a village, not checking or consuming that item. Pilgrimage describes offerings without an item-grant action. Rescue describes bringing a girl back but implements travel, a spawned-party kill, and report. These distinctions matter to field semantics: `travel` does not imply delivery, possession or escort. The document is not proposing all of these missing features.

**Smallest improvement:** archive the unsupported example templates and correct the objective module's list of supported types. Add focused validation of the existing supported objective/action shapes and referenced IDs. For live quests, align descriptions with implemented obligations; only add item/escort conditions if those obligations are intentionally required. Do not keep ignored fields as if they are an extension point or introduce an objective framework to preserve obsolete examples.

### Q2 — P1: `repeatable` is honored only on one offer path

**Classification: Inconsistent representation.**

**Trace:** `pilgrimage/rescue_daughter` declare false and other procedural templates true in [quests](../src/data/quests.lua). [QuestSystem.generateProceduralQuestOffer](../src/systems/quests/quest_system.lua) excludes completed nonrepeatable quests only when enumerating all templates. With `options.questPool`, it checks procedural status and active instances but not completion. [QuestAvailability.rollOfferForNpc](../src/systems/quests/quest_availability_system.lua) always supplies a configured pool from [npc_quest_pools](../src/data/npc_quest_pools.lua), so this principal authored offer route can reoffer them after cooldown.

**Smallest improvement:** apply the same existing eligibility condition to both selections. Keep `repeatable`: it expresses a real intended content distinction. Document its current giver-relative scope, since completed-instance lookup includes giver identity; “once in the entire campaign” is not the existing contract. Do not replace repeatability with extra flags.

### Q3 — P2: template IDs, instance IDs, giver identity and legacy names overlap

**Classification: Redundant or derivable; Inconsistent representation.**

**Trace:** [quest assemblage](../src/ecs/assemblages/quest.lua) assigns both `id` and `instanceId` identically, separately keeping `templateId`. Activation keeps `giverId`, `giverName`, and legacy `giver = giverName`. [QuestSystem._normalizeGiverRef/_isSameGiver](../src/systems/quests/quest_system.lua) supports stable identity, but also name-only matching; dialogue turn-in accepts several alternative quest-ID fields. Definitions repeat their registry key in `id`; activation indexes by key and passes that key as `templateId` rather than using the embedded template `id`.

**Smallest improvement:** retain template-versus-instance distinction, which is necessary for repeatable offers. Prefer the entity's `id` for instance identity when updating all callers, and retire `giver` where `giverName` already serves presentation. Require stable giver IDs on live NPC paths; keep names as snapshots, not alternative identifiers. Remove legacy fallback fields only after checking current dialogue/debug/test callers. Do not confuse display snapshots with redundant identities.

### Q4 — P2: reward and start-action payloads use unnecessary alternatives

**Classification: Inconsistent representation; Redundant or derivable.**

**Trace:** [QuestSystem._grantItemRewards](../src/systems/quests/quest_system.lua) accepts item maps or arrays, `id/itemId`, `quantity/amount`; `completeQuest` accepts scalar `unlock` and array `unlocks`. Authored [join_army](../src/data/quests.lua) uses scalar unlock, while the quest assemblage defaults to an empty unlocks array. No authored item rewards currently require all those alternatives. `onStart` is a single discriminated action (`spawn_party` or `give_item`) with actual consumers; spawned `partyId` is a template-local binding key rewritten to a runtime party ID, not a globally reserved campaign ID.

**Smallest improvement:** retain one documented item-reward shape and one unlock shape, migrating any fixtures with actual uses; remove unneeded aliases. Keep the existing single start-action model while it is sufficient. Rename/comment its `partyId` as a binding key if confusion persists; do not remove it as “duplicate identity,” since it connects kill objectives to freshly allocated parties.

### Q5 — Keep: procedural selectors, offer policy and snapshots have real independent purposes

**Classification: Justified existing data.**

`procedural` filters eligible templates; `pickTarget.locationType` selects and binds a concrete location at acceptance. Offer pool `rollChance`, `offerDurationDays`, `cooldownDays`, and `questPool` have separate reads in [QuestAvailability](../src/systems/quests/quest_availability_system.lua). Generated/expiry/cooldown days and accepted instance IDs are runtime NPC offer state, not definition properties. Values of 7 duplicated across profiles can be omitted if the defaults are deliberately authoritative, but explicit per-profile timing remains reasonable tuning.

Quest `giverLocationName/X/Y` and objective `targetName/X/Y` are deliberately captured knowledge used by the [quest log](../src/ui/screens/quest_log_screen.lua). They need not follow moving actors or later map state. `giverId` provides identity while a name snapshot supports display. An offer's `targetName` is separately resolved before acceptance, while acceptance resolves again; do not call it a guaranteed bound destination unless that resolution is made authoritative. Preserve the snapshots; document the distinction or bind the offered target if a firm promise is intended. Objective `required = 1` is an optional explicit default (`Objective.new` and activation already supply it); keeping it for readable quest steps is reasonable, while `giver = nil` in Lua constructors adds no stored property at all.

## Dialogues and names

### D1 — P2: named speaker text contradicts generated NPC identity

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** [NpcFactory](../src/systems/population/npc_factory.lua) chooses a generated name from cultural/archetype pools and appends `title`. [elder_intro](../src/data/dialogues/elder.lua) says “I am Bogdan” for every elder. [DialogueState.resolveSpeaker](../src/game/states/dialogue_state.lua) uses the actual actor's name for the heading, so the heading and introduction can disagree. `speaker` in generic dialogue nodes is a fallback display label, not the authoritative NPC identity.

**Smallest improvement:** remove the fixed given name from shared elder introduction text, or use the already-available text variable mechanism to insert the generated name. Keep culturally distinct name pools and `title`. [names/generic.lua](../src/data/names/generic.lua) intentionally imports [npc_name_pools.lua](../src/data/npc_name_pools.lua); the older filename is **not** an unused catalog. Moving those lists would be organizational cleanup, not removal of dead data.

### D2 — P2: two dialogue mutation forms and several routing layers need explicit precedence

**Classification: Ambiguous semantics; Inconsistent representation.**

**Trace:** [DialogueSystem.applySet](../src/systems/social/dialogue_system.lua) accepts an array of flags or a map of values/arithmetic resource expressions. If index 1 exists, it processes only array flags and returns; mixed maps silently lose keyed changes. [DialogueState.resolveDialogueTree](../src/game/states/dialogue_state.lua) applies `checkQuest/states`, `checkActiveQuest`, `checkOffer`, and `noOfferDialogue` with order-dependent routing; elder uses several together. Option predicates (`requiresQuestPool/Offer/AcceptedQuest/ReadyToTurnIn`, introduction flags, conditions), actions and `next` are read by dialogue filtering/action dispatch/navigation. [dialogue registry](../src/data/dialogue.lua) only checks duplicate node keys, not shape or links.

**Smallest improvement:** document existing routing order and reject mixed `set` forms rather than creating a new expression language. Validate referenced node/quest/action IDs in the existing registry if the authoring contract is tightened. Preserve useful specialized routing: check-specific-quest and check-any-current-offer express different questions. Do not collapse them solely because both eventually choose a dialogue node.

### D3 — Keep: action parameters and display flags are real dialogue data

**Classification: Justified existing data.**

`lines/text/options`, option `next/action`, quest filters, `set`, `showGold/showFavor`, and tavern `cost` have concrete consumers in dialogue state/screen/system. Tavern prices can remain per-option policy; moving every price into a system would lose authored choice differences. Cost numbers repeated in prose can drift, so use existing text substitution when parameterized text is needed. `id` duplicates the registry key in dialogue definitions without an observed runtime identity need; remove it or validate equality when making a small registry cleanup, rather than treating it as a second independent ID. Full schema invention is unnecessary.

## World generation, visibility and encounters

### W1 — P2: one configuration file appears to tune two different generation models

**Classification: Unused or obsolete (current application path); Ambiguous semantics.**

**Trace:** [GameInitializer](../src/game/game_initializer.lua) selects [PaintedMapLoader](../src/world/generation/painted_map_loader.lua), except for the debug map. That loader reads `world_generation.painted`, `navigation.cellSize`, and biome entries for lookup metadata. The older [WorldGenerationSystem.generate](../src/world/generation/world_generation_system.lua) reads `defaultSeed`, terrain-mask/navigation/continent parameters, `sites`, roads and biome weights. No checked-in Lua caller of that older generator was found. The current painted [MapGenerator.CONFIG](../src/world/generation/map_generator.lua) separately owns height/moisture thresholds, palette, site placement and road costs.

Editing `world_generation.sites.majorCount` or continent radius does not tune the playable painted map. Merely finding a field referenced inside the uncalled generator is not evidence of application reachability. Seed 1337 in `defaultSeed` and 1336 in painted settings are not two layers of the same effective default.

**Smallest improvement:** label the active painted configuration and remove/archive orphan generator settings if that generator is retired. If it remains a deliberate tool, separate/document its entry point and its settings; do not advertise them as universal campaign tunables. Preserve the live generator's calibration constants locally unless authors actually need external overrides.

### W2 — P2: distance relaxation is declared but not forwarded even to its nominal generator

**Classification: Unused or obsolete; Inconsistent representation.**

**Trace:** [world_generation.sites.distanceRelaxation](../src/data/world_generation.lua) declares enabled/start-ratio/end-multiplier. [WorldGenerationSystem.chooseSites](../src/world/generation/world_generation_system.lua) can read `config.distanceRelaxation`, but `generate` builds a `sitesConfig` table containing only count/distance/attempts/padding, omitting that nested group before calling it. The playable painted generator has its own site-placement algorithm.

**Smallest improvement:** remove the dead group with the orphan configuration, or forward the existing field if that separate generator remains supported. Do not add a second painted relaxation flag. Classify it separately from effective world-generation controls.

### W3 — P2: biome vocabularies do not agree across generation and policy

**Classification: Inconsistent representation.**

**Trace:** [world generation biome entries](../src/data/world_generation.lua) use `highlands`; [MapGenerator](../src/world/generation/map_generator.lua) produces `hills`, `mountain`, `snow`, etc., and writes sampled `site.biomeId`. [location definitions](../src/data/locations/index.lua) mix `highlands` biases for common locations with hills/mountain biases for forts/towers. [LocationPopulation.selectDefinition](../src/systems/population/location_population_system.lua) defaults missing biases to 1, silently neutralizing unreachable `highlands` preferences on painted sites. [encounter biomeThreat](../src/data/encounters.lua) and [painted loader](../src/world/generation/painted_map_loader.lua) each have their own biome maps and fallback behavior. The typed placement schema validates strings/numbers, not membership in the actual generator vocabulary.

**Smallest improvement:** align authored placement keys with the generator actually supplying site IDs. If alternate generators remain, document the mapping at their existing output boundary and validate relevant keys there. Do not equate all high terrain or ban biome-specific differences. Adding another flag to every location would hide, not resolve, the disagreement.

### W4 — P3: repeated fallback values obscure which table owns tuning

**Classification: Redundant or derivable; Ambiguous semantics.**

**Trace:** [painted options](../src/data/world_generation.lua) repeat MapGenerator defaults; `PaintedMapLoader.resolveOptions` adds another fallback chain. [encounters.config](../src/data/encounters.lua) and [EncounterSystem](../src/systems/campaign/encounter_system.lua) repeat most tuning values (`stepDistance`, chances, threat bonuses, distances). Visibility also defaults `radiusDivisor` in its consumer. Plain catalogs have no boot-time complete validation.

**Smallest improvement:** decide whether the existing config is required or intentionally partial. For required shipped config, validate it once and remove redundant consumer balance defaults; for supported standalone generator use, keep platform/tool defaults but document caller precedence. Do not delete an explicit balance value simply because a consumer currently has the same fallback. No new configuration-loader abstraction is warranted.

### W5 — P2: threat-band boundaries describe integer bands for a continuous value

**Classification: Inconsistent representation; Ambiguous semantics.**

**Trace:** [encounter bands](../src/data/encounters.lua) use closed ranges 0–12, 13–30, 31–50, etc. [EncounterSystem.computeThreat](../src/systems/campaign/encounter_system.lua) combines fractional `powerToThreat = 0.03` and road-halved contributions without rounding. `pickTemplate` uses inclusive comparisons, then falls back to the first pool of the highest band if none matches. Fractional threat between adjacent declared bands therefore has a different effective meaning than the ascending progression suggests. There is no band coverage validator.

**Smallest improvement:** choose one existing contract: round threat to integer before band selection, or author continuous boundaries with a consistent half-open interval rule. Keep threat and weighted pools configurable. Do not replace this simple model with a curve system; make the current boundary semantics complete.

### W6 — Keep: encounter composition and policy need not share population schemas

**Classification: Justified existing data.**

Encounter config is campaign spawning policy; `bands` select weighted compositions. `weight` is a relative weight, `chancePerThreat` a probability contribution, enemy `min/max` attempted troop counts, `dialogueId` an interaction entry point, and `faction/hostile` a spawned party default. These fields are read in [EncounterSystem](../src/systems/campaign/encounter_system.lua), then party systems. A simple hostile composition does not need cultural role resolution or important-leader retinues. Renaming `enemies[].type` to `troopType` would align terminology, but forcing all encounter and population compositions through a new common schema is unjustified. Preserve individual troop mixes, counts and dialogues.

## Other runtime records and configuration

### R1 — P2: runtime copies can be intentional snapshots, not redundant definitions

**Classification: Justified existing data, with explicit ownership requirements.**

[WorldEvents](../src/systems/campaign/world_events.lua) records immutable event copies; [KnowledgeSystem](../src/systems/knowledge/knowledge_system.lua), [BattleKnowledge](../src/systems/knowledge/battle_knowledge_system.lua), and [TravelKnowledge](../src/systems/knowledge/travel_knowledge_system.lua) record who knows what. [BattlefieldRemains](../src/systems/battlefield/battlefield_remains_system.lua) stores corpses/history/resource snapshots, and collection mutates remaining loot. IDs plus captured names/factions/positions/time are justified when live entities may move or disappear. `discovered` (remembered discovery) and `currentlyVisible` (present observation) are different state. Event IDs, encounter IDs and battlefield IDs identify different records and should not be collapsed.

The narrower ambiguity is allegiance representation captured by corpse `faction/factions` (F2) and item definition snapshots used as live item properties (I3). **Smallest improvement:** document immutable history versus mutable resources versus live references at their existing creation boundaries. Keep the existing serializers and reference checks; do not move history or memory into static content catalogs. [World-event](../tests/unit/world_events_scenario.lua), [knowledge](../tests/unit/knowledge_scenario.lua), [travel knowledge](../tests/unit/travel_knowledge_scenario.lua), and [battlefield remains](../tests/unit/battlefield_remains_scenario.lua) scenarios corroborate these distinct meanings.

### R2 — P3: several initialized party/location fields are only placeholders or diagnostics

**Classification: Unused or obsolete; Ambiguous semantics.**

**Trace:** [party assemblage](../src/ecs/assemblages/party.lua) initializes `supplies = 100`, `morale = 100`, and `currentObjective`. Population party definitions can seed supplies, but no supply consumption or travel gate reads it; the inspector displays it. Morale/objective have setters/getters in [PartySystem](../src/systems/parties/party_system.lua) but no gameplay decision consumers found. Current work is represented by `world_activity` and actor goals. `visibilityModifier` feeds the older `getPartyVisibility` formula, but actual spotting reads summed actor profiles via `getPartyProfile`; no operational caller of the older formula was found. In contrast `speedModifier` is read by the active party-speed helper. [location assemblage](../src/ecs/assemblages/location.lua) initializes `owner`, shown only by the inspector; operative ownership/policy uses `faction`. [NpcPartyFactory](../src/systems/population/npc_party_factory.lua) appends `initialPartyIds` without a runtime reader found.

**Smallest improvement:** remove dormant initial values/configuration and associated unused helpers only after searching their direct callers; retain diagnostic provenance only if intentionally useful and label it as such. Do not advertise supplies or morale as operational gameplay configuration. Do not equate individual owner and owning faction if personal ownership is later introduced, but do not maintain an empty second authority now. Keep actual activities and roster registrations authoritative.

### R3 — Keep: platform settings and operational constants do not need content catalogs

**Classification: Justified existing data.**

[conf.lua](../conf.lua) is consumed by LÖVE itself; explicit module switches, identity/version and window defaults have a platform owner even when no Lua source reads those fields. Embedded constants for rendering, navigation calibration, recovery, service retries and activity timing have direct consumers in their owning modules. No demonstrated need was found to make all of them per-item/per-location authoring fields. The [save module](../src/core/save.lua) is a stub, so this audit does not claim proven save-file compatibility requirements for legacy aliases. Explicit record serialize/restore functions still have local consumers/tests and must be checked before changing those payloads.

## Minimal follow-up sequence

1. **Remove misleading dead declarations:** unused hidden-type list, unsupported progression catalog, redundant quest marker, duplicate javelin type, and unwired static concepts. Archive design ideas as prose rather than executable-looking catalogs. Keep the imported generic name pool.
2. **Resolve contradictory authorities:** faction IDs/recruitment links (F1), archetype versus troop policy (N1), location identity/cooldowns (L2–L3), and item condition ownership (I2). These need coordinated callers/fixtures, not isolated field deletion.
3. **Make existing promises true or stop making them:** hydrate intrinsic protections (T1), align quest shapes/repeatability (Q1–Q2), remove unsupported skill/resource promises (S1), document status behavior and units (S2–S3), and correct generation/biome/band semantics (W1–W5).
4. **Trim defaults and legacy shapes after the contract is clear:** optional actor defaults, repeated fixed ranges, reward aliases and unused status input variants. Keep independent capability flags, explicit suppression, cultural overrides, important-actor semantics and historical snapshots.

Validation should be focused on those contracts when implementation is authorized: existing population/location tests for independent capabilities and IDs; combat tests for hydrated signed protections/effective charges; quest checks for supported shapes and pool-independent repeatability; inventory/loot tests for condition and metadata ownership; generator/encounter checks for reachable biome keys and complete band coverage. This audit added no tests and ran no game simulation because it changes documentation only. Static reachability cannot establish external consumers or unstated design intent; ambiguous intentions are identified above rather than resolved by inventing features.
