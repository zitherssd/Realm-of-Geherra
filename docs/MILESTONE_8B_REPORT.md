# Milestone 8B — Personality and ReturnHome

1. **Architecture inspected.** Read the typed archetype/schema/catalog boundary, seeded
   factory and population/initial-party creation, unit identity, resident/stationed/roster
   location representation, 8A importance/selection/hooks, activity ownership and Travel
   navigation, campaign scheduling/pause/time conversion, recovery/local healing/services,
   caravan preparation/assignment/work, investigation travel/reporting, F1 inspector and
   definition-driven NPC editor, architecture documentation and scenario runner. The existing
   mechanisms remain authoritative; no parallel motivation or navigation system was added.

2. **Personality representation.** Important actors own three fixed numeric traits in
   `actor.personality`: homesickness, responsibility and greed. Missing traits default exactly
   to 0.5. Generic troops receive no personality. A small data helper handles schema checks,
   seeded construction, neutral/legacy reads and one-time normalization, without a manager.

3. **Archetype generation and validation.** Archetype `personality` accepts authored 0–1
   min/max pairs or explicit numbers through the same schema, including factory overrides for
   named NPCs. Unknown traits, invalid bounds, nonfinite values, malformed pairs and inverted
   ranges fail existing assertion-style validation. Independent range rolls use the creator's
   existing seeded stream in fixed trait order. Goals, travel, service acceptance and party
   changes do not reroll. Wealthy merchants, healers, caravan leaders and bandit leaders now
   author illustrative distributions; existing archetypes without them continue to work.

4. **Home assignment.** Population passes the actual persistent location ID through
   `context.homeLocationId` when constructing important residents and initial party members.
   Factory assigns it at creation. Debug fixture residents also supply explicit known homes.
   Other creators can supply this context; unknown homes remain unknown. Neither actor's
   current position nor an assignment destination is used to guess or change home.

5. **ReturnHome importance.** Explicit goal registration reuses `accumulatedImportance` and
   the 8A update hook. Default initial score is zero; authored accumulated/base importance can
   seed it. Maximum away rate is **12 points/world day × Homesickness**; home recovery is
   **18 points/world day**, independent of personality. TimeSystem converts a day to its
   current 16 simulation seconds. Values clamp to 0–100 without resets on arrival. Every live
   NPC with goals advances once per positive interval through the ECS query, including moving
   passengers, rather than each party/population reference. Paused time and pure F1 reads do
   not advance. Large stationary updates use elapsed duration directly. Unknown/off-map homes
   have zero rate and block travel safely.

6. **ReturnHome execution.** A leader with Travel capability starts existing TravelActivity
   toward the actor's actual home, planning from the current position. It preserves accumulated
   importance through interruptions and uses the existing five-point switching rule. Encounter
   reservations and external activity ownership remain authoritative. At home, the goal stays
   eligible while positive without creating Rest/Wait or completing/removing itself. Local
   compatible services remain available. Zero leaves the goal attached and releases control.

7. **Leadership and passengers.** Home detection reuses physical stationing and authoritative
   roster membership. Both leader and passenger count as home when their party is stationed
   there; stale home-population records do not override a traveling party. Independent residents
   are handled through the existing resident representation. Passengers accumulate importance
   but cannot redirect, depart, split or create another party. Independent residents without a
   commanded party cannot invent movement. No movement capabilities were added to archetypes.

8. **Greed.** AcquireWealth uses `100 * max(0, 1 - treasury/amount) ^ (2 - 1.75*greed)`,
   clamped to 0–100, with configurable exponent coefficients in `goal_importance.lua`.
   The authored target is untouched. Leaders use party gold, independent actors/passengers
   personal gold. Zero/invalid targets score zero; authored invalid data still fails validation.
   At 9000/10000 gold, Greed 0/0.5/1 gives 1/7.50/56.23. Lost gold can raise importance again.
   Raid execution, caravan capabilities/profits and sponsorship cooldowns remain unchanged.

9. **Responsibility compatibility.** Obligation importance remains `50 + 40*responsibility`
   using personality and default 0.5. Legacy actor-level values normalize into personality;
   already canonical values take precedence and the old field is removed. Pure reads retain
   fallback compatibility before normalization. Personality stays fixed during accepted work;
   assignment persistence, terminal resolution and absence of deadline escalation are preserved.

10. **Local arrival services.** Before any primary movement decisions, the evaluator checks
    the known commission already recorded as the provider's pursued service. It reuses actual
    request state, knowledge closure, profession assignment, capability and physical availability
    checks. This happens globally before any leader, including one iterated before a passenger,
    can depart. Failed-travel retry does not suppress legitimate local arrival work. Unrelated
    requests are not automatically accepted and non-dominant providers never start new travel.
    Healing commissions lacked an executor: they now share direct healing's checks and effect/
    payment implementation, accept an obligation and immediately complete it. Filled/completed
    events and payment/healing occur once. Moving, busy, remote, incapable or reserved workers,
    unavailable customers and cancelled requests do not bypass physical rules.

11. **F1 and editor.** Existing actor inspection shows all final personality values, assigned
    home ID/name/availability, physical at-home state, ReturnHome score and signed rate per world
    second/day, wealth target/Greed, obligation/Responsibility, and existing goal scores/dominance.
    ReturnHome appears automatically in the existing registry-driven NPC editor. Home/personality
    remain creation-time data; no new editor or evolution/relocation controls were introduced.

12. **Files changed.**

    - Added `src/data/types/personality.lua`.
    - Updated `src/data/types/npc_archetype.lua`.
    - Updated `src/data/npc_archetypes/{wealthy_merchant,healer,caravan_leader,bandit_leader}.lua`.
    - Updated `src/systems/population/{npc_factory,npc_population_system,npc_party_factory}.lua`.
    - Updated `src/systems/goals/{goal_importance,goal_definitions,goal_system}.lua`.
    - Updated `src/systems/services/service_system.lua`.
    - Updated `src/debug/{campaign_fixture,inspector}.lua`.
    - Added `tests/unit/personality_return_home_scenario.lua`.
    - Updated `tests/unit/{main,dynamic_importance_scenario,population_scenario}.lua`.
    - Updated `docs/CAMPAIGN_ARCHITECTURE.md` and added this report.

13. **Tests.** Baseline: all 37 scenarios plus navigation passed; no existing failures were
    observed. Final suite: all **38 scenarios plus navigation pass**. This includes 8A goals,
    population/data validation, leadership, travel/navigation, healing/recovery/services,
    autonomous/player caravans and finances, investigation/search/knowledge, raids/encounters,
    battle simulations/casualties, time/runtime scheduling and debug F1/F2/F3 coverage.
    The new focused scenario verifies distributions/defaults/explicit values/seeds, fixed
    personality, persistent home, rates/pause/clamps/non-dominant updates/duplicate references,
    interrupted fresh routes, home staying, five-point switching, passenger/external ownership,
    encounter reservations, Greed/defaults/targets, legacy Responsibility and idempotent services.
    Arrival tests cover successful immediate healing, cancellation, customer unavailability,
    capability loss, remote customer, busy worker and encounter reservation. A separate
    passenger case verifies no moving-caravan treatment and service completion before its
    leader's departure. Population snapshots now assert homes and seeded personality values.
    Changed 8A expectations are the specified curved wealth result and canonical Responsibility
    fixture fields; ownership/payment/lifecycle checks remain in place.

    ```powershell
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit personality_return_home_scenario
    git diff --check
    ```

14. **Manual playtest.** Start from the repository root:

    ```powershell
    & 'C:\Program Files\LOVE\love.exe' . --debug-campaign
    ```

    Pause before accepting work, open F1 and inspect Ashur/Ninsun. Confirm the three traits,
    permanent home and physical at-home flag. In the existing NPC editor add ReturnHome with
    base importance 85 while retaining ProvideService. Resume time at home, re-inspecting as
    its score decays; verify there is no artificial Rest activity and services remain offered.
    Pause and verify the accumulated score stops. As the service goal becomes five points
    stronger, it should become dominant and ReturnHome should continue decaying.

    In a fresh debug campaign, add ReturnHome with initial importance zero to Ashur before
    accepting a caravan assignment, retaining his existing Travel and LeadCaravan capabilities.
    During the ordinary expedition inspect positive away buildup and unchanged home; after
    return inspect gradual decay. A sufficiently long absence can make ReturnHome interrupt
    obligation travel under ordinary 8A rules. Passengers must stay in their leader's party.
    Inspect Bel-Naram for the unchanged 10000 wealth target and its Greed-dependent score.
    F2/F3 should open their existing viewers. Run the focused command above for deterministic
    high-homesickness arrival, exact switching, negative-service and passenger-order probes;
    debug goal replacement deliberately resets goals and is not an exact hysteresis probe.

15. **Known limitations.** Initial rates/distributions are balancing choices, with no human
    interactive playtest or large-population performance profiling. The existing runtime uses
    discrete update intervals: location-dependent accumulation uses the physical state at the
    update, rather than subdividing travel across an arrival inside a large activity step.
    Homes outside the active map cannot be navigated. A healer/merchant without a commanded
    party and Travel capability cannot autonomously create one to return. No full save/load,
    committed activities, timed treatment, injuries, SeekSafety, fleeing, relocation, autonomous
    splitting or passenger departure is implemented. Normal caravan/investigation work keeps
    its existing obligation-driven execution and interruption behavior.

16. **Decisions within 8B.** Chose 12/18 points per day and the documented four archetype
    distributions; explicitly attached ReturnHome to three archetypes while preserving their
    movement capabilities. Used creator context for explicit home information. Canonical
    personality wins over legacy Responsibility. The existing base-importance editor field
    can seed ReturnHome, alongside the explicit accumulated field in authored data. Followed
    the requested exponent formula exactly, so neutral near-target importance is 7.50, not
    exactly 10. Arrival checks are restricted to retained pursued commissions. Added only the
    missing instantaneous `heal` commission handler, with no generic profession/activity
    framework. Stopped at 8B; persistent injuries and SeekSafety remain deferred.
