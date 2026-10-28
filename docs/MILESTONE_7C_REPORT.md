# Milestone 7C implementation report

1. **Architecture inspected and reused.** GoalSystem/goal definitions, ServiceSystem and its
   learned-offer ProvideService path, Recovery, important actors, actor/party assemblages,
   PartySystem, location residents/stationed membership, Map lifecycle, generic navigation,
   TravelActivity/WorldActivitySystem, WorldEvents/KnowledgeSystem, InventorySystem, RaidActivity,
   WorldEncounterSystem, LootResolver/LootApplication, dialogue, GameContext player ownership,
   world clock, IdAllocator and F1/F2/F3 were inspected. Existing movement, recruitment, funds,
   encounters and history remain authoritative. No separate planner, movement or inventory model
   was added. Existing uncommitted changes, including 7B, were retained.

2. **Runtime ownership.** The sponsor's `caravan_formation` component contains the cooldown,
   one active preparation, last preparation and dispatched service IDs. Preparation holds stable
   IDs, origin/destination, start/ready timestamps, investment and request ID. Hiring status and
   assigned worker remain solely in ServiceSystem. The leader's `caravan_work` component holds
   expedition phase, party/service/sponsor/location IDs, owned travel sequence and timing/profit.
   Normal Concord serialization produces plain payloads; terminal work snapshots strip Concord
   internals before copying. There is no generic capability-runtime framework.

3. **Independent preparation progression.** Positive campaign updates run CaravanSystem from
   GoalSystem before individual goal evaluation. Existing preparation does not depend on the
   sponsor's selected goal or continued capability selection. Pause supplies zero simulation
   time. Dead/removed sponsors cancel pending recruitment through ordinary service cleanup.
   A leaderless ready preparation waits; missing dispatch funds produce a recoverable reason.

4. **Recruitment.** A preparation creates one `lead_caravan` commission requiring `leadCaravan`.
   Its plain data contains preparation, destination and planned departure. Both bounded local
   sponsor recruitment (every two simulation seconds) and proactive learned-offer applications
   call ServiceSystem.assign. Capability, selected active ProvideService, physical accessibility,
   obligations and ownership are revalidated. Events and service references use existing APIs.

5. **NPC leader transitions.** Independent important residents are supported. Existing-party
   NPCs are rejected rather than commandeered. Dispatch moves the same actor from the location
   roster into a newly allocated, stationed party, then Travel unstations it. A successful solo
   return restores the actor to origin and removes the empty party. Unexpected cargo/members
   retain a valid stationed party. No actor inventory, equipment, HP, identity or memory is cloned.

6. **Player volunteering/override.** The greeting dialogue offers immediate departure for the
   actual local player party leader when preflight succeeds. It works before three days and may
   replace an NPC. After physical dispatch succeeds, the old request cancels, releasing the NPC
   obligation, and a replacement request accepts the player through the same internal service
   acceptance operation. Historical offers/assignments are preserved. GameContext still points
   to the original party/actor. The dialogue explicitly commits the party's shared treasury,
   including its existing gold, and returns all surviving gold to the sponsor. This avoids a
   separate wallet and preserves actual losses. Manual movement releases Travel stationing;
   completion restores the player's ordinary map membership and prior trader flag.

7. **Dispatch and money.** Investment defaults to 500. Actual owner funds, both routes, living
   participants, location, ownership and compatible activities are checked before commitment.
   Only successful dispatch invests. A failed station/departure removes the new party, restores
   membership and refunds only the uncommitted transfer. Monotonic IDs consumed by failed
   attempts are not reused. Existing trader classification makes the real party raid-eligible.
   Generic encounter/loot processing owns any later losses; dispatched investments never refund.

8. **Travel, trade, return.** FulfillObligation executes outbound Travel, waits for confirmed
   physical arrival, trades, starts return Travel, then delivers only after confirmed return.
   Work owns activity sequence references and never replaces external activities. Encounters
   reserve progression. NPC RestAndRecover interrupts owned travel while keeping the obligation;
   work resumes from its actual phase after recovery. The player service uses the existing
   positive-time caravan update because the NPC evaluator intentionally excludes the player.

9. **Profit/conservation.** Six world hours after arrival, profit is
   `floor(actual party treasury * 0.25)`, once. It is the sole generated currency. Investment
   moves real money; stolen capital is not recreated. A test invests 500, steals 100, trades
   with 400, generates 100, and delivers exactly 500. Generic loot tests also defeat the actual
   dispatched party and transfer its 500 to bandits, with no refund or successful arrival.

10. **Cooldown.** Thirty world days from preparation start, independent of the three-day timer,
    departure, return, injury, cancellation or selected goal. There is one pending preparation,
    with no active-expedition limit. A test starts/funds a second expedition after day 30 while
    the first remains physically present and reserved in an encounter.

11. **Expected return/events.** Both existing navigation routes are estimated using Travel speed
    and terrain sampling along their waypoints. Expected return is departure plus 120% of their
    combined travel time plus trading duration. The original party_departed path records exactly
    one event per real departure, with optional sponsor/preparation/departure/expected-return
    metadata on initial dispatch. Later real departures/arrivals use ordinary Travel history.
    `caravan_traded` records the distinct abstract gain. No tick/waypoint/discovery events exist.

12. **Knowledge.** The sponsor directly learns its organized departure, including expected
    return through an allowlisted sponsorship category. It does not automatically learn remote
    trading, arrivals, battle, destruction or position. Dispatched service cancellation does not
    automatically teach its employer that outcome. Witness/contact communication remains available
    through existing knowledge sharing. Authoritative service state can close before the sponsor
    knows why; F3's developer visibility does not become NPC knowledge.

13. **F1/F2/F3.** F1 exposes formation/leader capabilities, preparation/readiness/cooldown,
    destination/investment/service/prospective worker, dispatched party/phase/expected return and
    obligations, plus personal treasury. Inspector buttons enable sponsorship or leadership with
    their existing goals. F2 formats trade and expected-return departure metadata; its existing
    complete details panel renders all fields. F3's existing generic rows/details already display
    lead_caravan requests, employer, capability, worker, status, event IDs and preparation data.
    No separate caravan registry or viewer was added.

14. **Files changed for 7C.** These are this task's additions/edits, not the entire pre-existing diff:

    - `src/ecs/components/caravan_formation.lua` (new)
    - `src/ecs/components/caravan_work.lua` (new)
    - `src/ecs/components/init.lua`
    - `src/systems/services/caravan_system.lua` (new)
    - `src/systems/goals/goal_definitions.lua`
    - `src/systems/goals/goal_system.lua`
    - `src/systems/services/service_system.lua`
    - `src/systems/knowledge/travel_knowledge_system.lua`
    - `src/systems/knowledge/knowledge_system.lua`
    - `src/game/states/dialogue_state.lua`
    - `src/game/states/world_state.lua`
    - `src/debug/campaign_tools.lua`
    - `src/debug/inspector.lua`
    - `src/ui/screens/debug_overlay.lua`
    - `src/ui/world_event_text.lua`
    - `src/ui/knowledge_text.lua`
    - `tests/unit/caravan_scenario.lua` (new)
    - `tests/unit/main.lua`
    - `docs/CAMPAIGN_ARCHITECTURE.md`
    - `docs/MILESTONE_7C_REPORT.md` (new)

15. **Validation.** The focused caravan scenario passes. All 24 scenarios were run individually
    so early known failures could not hide later results: **21 pass, three existing failures**.
    Existing services, NPC goals/Roam-Raid, recovery, navigation/travel knowledge, raid encounters,
    loot, debug tools and world-time scenarios pass. Real F1/F3 rendering is exercised in the
    caravan scenario; the playable fixture also passes a three-frame actual WorldState renderer
    smoke run. No claim is made that a human completed the interactive playtest.

    The previously documented failures remain unchanged:

    - `headless_battle_scenario.lua:152`: first matchup timeout, nil winner, 4000 ticks, HP 10000/30.
    - `world_encounter_scenario.lua:236`: supposed victory times out, no casualties.
    - `battlefield_remains_scenario.lua:190`: duplicate-cargo assertion after the underlying timeout.

    Assertions were not weakened and combat was not refactored. The caravan loss test deliberately
    supplies a deterministic defeat to the real generic loot resolver/application; it does not rely
    on changing those combat fixtures. `git diff --check` passes.

16. **Limits.** NPC hires must be independent important residents. Destination choice is the first
    suitable reachable settlement. Shared player treasury participates in trading and delivery.
    A dead/removed/moved sponsor leaves a surviving caravan waiting at fixed origin with treasury
    and obligation intact; no alternative recipient or pursuit is invented. Failed work preserves
    surviving parties/resources rather than deleting them, and encounter reservations defer release
    until real resolution. Clock estimates do not promise arrival through combat, recovery or retries.
    Initial world NPC definitions are not changed; opt in through goals/capabilities or the fixture.
    No investigations, SearchActivity, economy, escorts, wages or save/load implementation was added.

17. **Manual playtest.** Launch the small, funded fixture in the existing runner:

    ```powershell
    & 'C:\Program Files\LOVE\love.exe' tests/unit caravan_scenario --preview
    ```

    This uses the real world state and its input/dialogue/F1/F2/F3. The merchant has 2000 personal
    gold, another independent important resident can lead, and the original player party has 100.
    The two settlements are Sponsor Town and Trade Town. Close/restart the window for a fresh case.

    1. Press F1, right-click Sponsor Town, inspect the location, then **Merchant**. Click
       **Enable CaravanFormation / Acquire Gold**. Its capability and wealth goal appear in F1.
    2. Close any editor/menu and hold Space briefly. Inspect the merchant's active preparation,
       ready-in timer, investment 500, destination and service ID. No expedition party exists yet;
       the merchant still has 2000 gold. Pausing in an editor/F2/F3 freezes progress.
    3. Press F3 and select lead_caravan: check open status, employer, leadCaravan requirement,
       offer event and preparation data. Close F3 to advance time again.
    4. Through the same location inspector, inspect **Prospective leader** and click **Enable
       LeadCaravan / ProvideService**. Hold Space. The merchant's bounded local check hires it;
       F3 shows assigned and its F1 goal becomes FulfillObligation, waiting for dispatch.
    5. Hold Space until three world days have elapsed (48 simulation seconds from start).
       A real caravan departs, containing the same NPC. F1 shows merchant 1500 gold and caravan
       500 shared gold, outbound phase and expected return. F2 shows one sponsored departure.
    6. Continue holding Space and follow the party, or use F1/F2/F3 to inspect it. Observe actual
       arrival, six-hour abstract trade, return and delivery. An undamaged NPC expedition returns
       625: merchant ends at 2125. The leader is again a resident and the service completes.
       Cooldown still refers to 30 days from preparation start, not return.

    Additional cases, each from a fresh fixture:

    - **No leader:** enable only the merchant, wait past three days, check the ready preparation
      and open F3 request with no party. Enabling the worker later permits hiring/dispatch.
    - **Sponsor recovery:** add Rest and Recover in the existing goal editor, then fixture key
      H sets sponsor HP to 30. Advance time: recovery is selected but the preparation and cooldown
      persist. J similarly injures the prospective/current NPC leader to test work interruption.
    - **Bandit destruction:** after NPC dispatch, fixture key B spawns strong generic bandits next
      to the caravan. Hold Space for ordinary Raid/encounter resolution. Check F2 battle history,
      bandit treasury/loot, terminal F3 service and no investment refund. The distant merchant's
      memory must not automatically gain the remote result. These bandits use existing combat;
      the three known combat timeout limitations still apply.
    - **Early player departure:** enable only the merchant and start preparation. Before readiness,
      press fixture key C to open the merchant's real greeting dialogue. Choose the explicit party/
      treasury volunteer option. Dispatch happens immediately using the original player party.
      With no losses it trades using 600 (100 existing + 500 investment), delivers 750, and leaves
      the merchant at 2250. Hold Space while trading so world time continues.
    - **Override:** enable both roles, wait until F3 says assigned but before readiness, then C and
      volunteer. The old service cancels, the NPC stays a resident without an obligation, and a new
      player-assigned commission appears. Check that no second player party or duplicate actor exists.
    - **Cooldown/overlap and failed dispatch:** deterministic automated tests cover insufficient funds,
      injected Map departure failure, unavailable sponsor and a second expedition after day 30 while
      the first is still reserved. F1 has no arbitrary balance/time setter; no such game debug
      framework was added. The fixture-only H/J/B keys supply injury/bandit conditions for playtesting.

    In a normal campaign, use the existing funded **Wandering Trader** as a sponsor: first give its
    leader Reach Location plus Travel to station at a settlement, then configure a wealth target
    above its actual shared treasury and enable CaravanFormation. Use a local independent important
    resident as leader. The same F1/F2/F3, dialogue and lifecycle apply without fixture keys.

    Run focused automation or renderer smoke with:

    ```powershell
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit caravan_scenario
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit caravan_scenario --preview-smoke
    ```
