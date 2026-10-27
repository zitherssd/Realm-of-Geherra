# Reusable Debug Campaign

Population is now shared with ordinary campaigns. See [Population authoring](POPULATION_AUTHORING.md)
for location definitions, archetypes, cultures, faction overrides and the two fort examples.

From the repository root in PowerShell:

```powershell
& 'C:\Program Files\LOVE\love.exe' . --debug-campaign
```

Or choose **Debug Campaign** on the main menu (shortcut **D**). Use `lovec.exe`
instead to see the console startup summary. Both paths enter the ordinary generation
splash and playable world state. Profiles reuse one constructor:

```powershell
& 'C:\Program Files\LOVE\love.exe' . --debug-campaign=normal
& 'C:\Program Files\LOVE\love.exe' . --debug-campaign=no_leader
& 'C:\Program Files\LOVE\love.exe' . --debug-campaign=healing
& 'C:\Program Files\LOVE\love.exe' . --debug-campaign=bandit_risk
```

`normal` supplies the merchant, local leader, healer and wounded traveler. `no_leader`
places Ashur at B alongside Enlil, leaving no suitable local NPC leader. `healing` is
an alias of normal initial conditions for recovery playtests. `bandit_risk` adds Zakur.
The default has no fixture bandits. Debug campaigns replace the two legacy starter
parties with profile parties, retaining normal settlement population and the existing
Merchant of Everything. Normal New Game retains its existing initialization.

## Determinism and starting roster

Debug campaigns use a fixed **1536 × 1536** square map with a **3 × 3** district
grid. Each district is 512 pixels square and has one settlement near its center.
Straight roads join horizontal and vertical neighbors. Grid labels run A1–C3:

| Row | Column 1 | Column 2 | Column 3 |
|---|---|---|---|
| A | Plains Village | Forest Town | Minotaur Fort (desert) |
| B | Hills Village | Marsh Town | Pelasgian Fort (mountain) |
| C | Desert Village | Plains Town | Forest Keep |

All districts are walkable and use the existing biome movement penalties and road
bonuses. All nine settlements are discovered for player inspection. The map opens
at a zoom that fits the whole board. The debug map supplies terrain/navigation data
and fixed sites; ordinary settlement population, membership and gameplay APIs still
create and run the world. Normal campaigns retain the painted generator unchanged.

A3 uses the `chieftain_court` population profile: its Minotaur chieftain starts with
a personal party with 3–4 plain Minotaurs, 2–4 warhammer Minotaurs, and a 50% chance
of one additional warrior. Those followers are additional to the chieftain.
B3 retains the ordinary fort garrison.
Both are real stationed parties; inspect them through the location's F1 party links.

The NPC fixture picks the first reachable settlement pair from this map:
**A1 Plains Village** (`location_1`) is the merchant hub, and **A2 Forest Town**
(`location_2`) is the distant employer/recruitment test location. Actor randomness
is seeded with 73421 before normal player creation. Stable actor/party IDs are
claimed through the existing allocator. Fresh launches reset ECS/context, IDs,
services, events and debug clock state. Finalization and application are guarded.

| Character / stable ID | Start | Goal / capabilities | Gold owner |
|---|---|---|---|
| Bel-Naram / `debug_bel_naram` | A, independent resident | Acquire Gold: 10,000 / CaravanFormation | 2,000 personal |
| Ashur / `debug_ashur` | A; B in `no_leader` | Provide Service / LeadCaravan, Travel | 50 personal |
| Ninsun / `debug_ninsun` | A, independent resident | Provide Service / Heal | 100 personal |
| Enlil / `debug_enlil` | B, independent resident | Provide Service / LeadCaravan, Travel | 50 personal |
| Ur-Salim / `debug_ur_salim` | Outdoor route waypoint near A | Rest and Recover / Travel | 100 in `debug_travelers` |
| Zakur / `debug_zakur` | A–B route midpoint; `bandit_risk` only | Acquire Gold: 10,000 / Raid, Roam | 75 in `debug_bandits` |

Named actors now use the shared NPC archetypes (merchant, caravan leader, healer,
traveler and bandit leader), with their existing troop-template equipment and stats.
The fixture overrides their maximum HP to 100 and supplies the fixed goals/funds
listed above. Ur-Salim starts at 30 HP; others start at full HP. His waypoint is outside
settlement interaction range, with A nearest. Zakur has five existing-template
bandit troops and ordinary roam attempts of 30 seconds within 180 pixels. No request,
assignment, caravan, battle or encounter is created by the fixture. Party members
transact through party treasury; independent residents use personal funds.

The original player and five-member party remain intact with normal 50 gold and
starter inventory. The party starts at A; the player starts at 60% HP to permit
healing. Player goals/capabilities are not replaced. Enlil starts with no job knowledge.

## Playtests

Debug tools start enabled with A's live F1 inspector open. Scroll to **DEBUG CAMPAIGN**
links for both settlements, surviving debug NPCs and fixture parties. NPC inspectors
link to current party/settlement, including after caravan dispatch. F1 toggles tools;
right-click discovered locations/parties to reopen inspection. F2 shows historical
facts; F3 shows providers/commissions. Inspection never grants NPC knowledge.

Hold **Space** on the world map to Wait; movement also advances time. Existing tavern
Rest works where offered. The basic village Rest dialogue alone does not advance
the campaign clock. Menus/editors pause world input/time. Release Space to inspect
without advancing time. Preparation starts on the first live goal evaluation.

1. **Hiring/dispatch:** Wait briefly. Inspect Bel-Naram's selected goal, preparation,
   ready time, recruitment service and cooldown. F3 lists the real commission.
   Ashur accepts through local recruitment. Wait through three game days; inspect
   Ashur's current caravan party, sponsor ownership and 500 treasury. Bel-Naram has
   1,500 gold after dispatch. F2 records departures/arrivals. The sponsorship cooldown
   lasts 30 days. No fixture function progresses this work.
2. **Player volunteering:** Start fresh, Wait briefly, enter A and talk to Bel-Naram.
   Choose the existing volunteering option before NPC dispatch. It can displace an
   accepted NPC commission and uses the player's original party. `no_leader` avoids
   NPC competition. Eligibility and all transfers use normal dialogue/services.
3. **Healing:** Start `healing`, Wait and inspect Ninsun's active Provide Service and
   F3 listing. Enter A, talk to Ninsun and purchase healing: normally 10 party gold
   for up to 40 HP. On the world map, Wait and inspect Ur-Salim's Travel, arrival,
   recovery and funds. He chooses the nearest settlement and eligible local healer
   himself. The fixture neither preselects a provider nor makes a purchase.
4. **Knowledge-limited recruitment:** Start `no_leader`. The commission stays open;
   neither B resident initially knows the offer. F2 is omniscient; Enlil's F1 memory
   is separate. For an explicit debug control, choose Enlil's **Grant event knowledge**,
   enter the real `service_offered` event ID from F2, and select `service`, `employer`,
   `location`. Wait: he recognizes the job but reports
   `independent_resident_cannot_travel`. Existing independent residents cannot form
   traveling parties for remote work. Knowledge does not teleport or hire him.
   Ordinary arrival/gossip exchanges can also convey knowledge.
5. **Encounters/lost investment:** Start `bandit_risk`, let Ashur dispatch and Wait.
   Follow both parties in F1/F2. Zakur relies on real visibility, pursuit, reservations,
   battle and loot. Contact and victory are not guaranteed. If the caravan loses,
   compare treasury/cargo, loot and F2 events. Bel-Naram's investment stays spent;
   inspect his personal memory separately from F2. No remote outcome notice or
   automatic obligation resolution is supplied by this fixture.
6. **Reset:** Close the application and rerun the command/profile, or choose a new
   Debug Campaign from the main menu when available. Every launch is fresh. There
   is no in-world reset shortcut or debug save/resume mechanism.

## Validation and files

```powershell
& 'C:\Program Files\LOVE\lovec.exe' tests/unit debug_campaign_scenario
```

The focused test uses the fixed debug grid for all profiles, a repeated fresh normal
profile and an ordinary New Game through the painted generator. It checks square
bounds, biome boundaries and movement differences, evenly spaced discovered sites,
roads and connectivity, splash idempotence, identities/membership, goals/flags,
funds/player ownership, empty fresh services/events, idempotence, goal-created
preparation, real local assignment, isolated remote knowledge, healing transactions,
autonomous traveler arrival/purchase, bandit equipment, startup inspector and real
world/location rendering. Separate process runs confirm the same settlements.

Verification on 2026-10-27: all **29** scenarios were run independently with
`lovec.exe tests/unit <scenario_name>`; **28 passed, 1 failed**. The inline party, typed location, retinue, population and debug campaign,
caravan, services, goals, recovery, knowledge, debug tools and time scenarios pass.
`git diff --check` passes. Rendering checks are automated; a complete human interactive
walkthrough has not been performed.

The three previously documented combat failures were checked separately:

| Scenario | Current result |
|---|---|
| `headless_battle_scenario` | Still fails at line 152: first matchup times out after 4000 ticks, nil winner, HP 10000/30 |
| `world_encounter_scenario` | Passes in the current workspace |
| `battlefield_remains_scenario` | Passes in the current workspace |

No combat fix is included in this task. The fail-fast aggregate runner cannot report
later scenarios after the headless failure, so independent execution supplies coverage.

Files changed for this task (other workspace changes predate this work):

- `src/debug/campaign_fixture.lua`: initial conditions, profiles and console summary.
- `src/debug/campaign_map.lua`: fixed square biome grid, navigation and straight roads.
- `main.lua`, `src/game/states/menu_state.lua`: launch entry points.
- `src/game/game_initializer.lua`: opt-in setup and one-time finalization.
- `src/game/states/world_generation_state.lua`: forwards population options.
- `src/systems/location_population_system.lua`: typed location and population initialization.
- `src/systems/time_system.lua`: fresh debug clock reset.
- `src/game/states/world_state.lua`: startup F1 inspector and fit-to-board debug zoom.
- `src/ui/screens/debug_overlay.lua`: existing inspector navigation links.
- `src/ui/screens/location_screen.lua`: wraps residents and reads actions from the location definition.
- `tests/unit/debug_campaign_scenario.lua`, `tests/unit/main.lua`: automated coverage.
- `docs/DEBUG_CAMPAIGN.md`, `docs/DEBUG_MODE.md`: documentation.

Later outcomes depend on gameplay/player actions; deterministic initial conditions
do not promise identical frame-by-frame encounters. Remote travel by independent
residents remains unsupported. Bandit contact/destruction is probabilistic. The
known headless combat timeout can prevent resolution. No new goals, recruitment
travel, investigation, gold generation or encounter bypass was introduced.
