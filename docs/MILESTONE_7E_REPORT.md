# Milestone 7E implementation report

Implemented missing-caravan investigations only, preserving the pre-existing 7D working-tree
changes and unrelated edits. No subsequent milestone, generic planner or quest framework was added.

1. **Architecture inspected.** Acquire Gold/Knowledge, Provide Service/Obligation and priorities;
   caravan formation, runtime, dispatch, trade, delivery, loss and cleanup; expected-return departure
   history; service registry and lifecycle; immutable events and filtered personal/party knowledge;
   Travel, Search, Roam and ownership; navigation and shared movement; visibility and real remains;
   resident/party transitions; encounter reservations, casualty/loot processing and destruction;
   campaign clock/runtime ordering; F1/F2/F3 and existing fixtures; CAMPAIGN_ARCHITECTURE.md.

2. **Overdue detection.** Sponsor evaluation reads its own known departure and expected return.
   Past-due unanswered departures create independent target objectives. It never tests whether a
   remote caravan exists or reads global battles. Actual local caravan delivery records a real
   `caravan_returned` occurrence, avoiding reliance on remote service state for successful return.

3. **AcquireKnowledge.** The existing schema gains `caravanFate` and optional `caravanDepartureAt`.
   Generated objectives require known outcome and time after departure. Known elimination, a real
   close encounter establishing survival, or confirmed sponsor delivery answers the question.
   Departure, destination arrival, unrelated/nonterminal battles and partial reports do not.
   Existing generic queries retain their rules. Wealth, recovery and separate caravan objectives
   remain present; persistent attempt metadata survives goal reconfiguration.

4. **Employment.** Only selected AcquireKnowledge commissions work. Generic ServiceSystem owns
   serializable requests, immutable offer/filled/closure history and assigned-worker/status fields.
   Selected ProvideService requires a known offer, actual Investigate capability, local employer
   contact, availability and no conflicting obligation. Acceptance creates normal FulfillObligation.
   Independent residents or eligible commanders of their own real party may accept. No broadcasts,
   job board, fabricated wages or gold transfers were added. Assignment time is recorded generically.

5. **Identity.** A small resident-travel helper was extracted from caravan dispatch. The same actor
   becomes the leader of a real party; HP, memory, equipment, inventory and goals stay on that actor.
   An existing suitable commanded party remains intact. After reporting, only an empty sole-actor
   party created for this job is dissolved into residency. Unexpected gold/cargo/companions preserve
   the stationed party and all its resources.

6. **Work phases.** Actor-owned `investigation_work` holds route/search execution data and service
   references: traveling, searching, returning, reporting, completed/failed. CampaignRuntime executes
   selected obligations after goal selection. Service status and assigned identity are not duplicated.

7. **Route and activities.** Navigation reconstructs the known origin/destination route. Evenly
   spaced centers use 120-unit spacing capped at 12. Existing Travel accepts coordinate destinations
   as well as unchanged location-ID destinations. Existing Search runs within radius 80 for three
   world hours per center. It is unchanged. Navigation, terrain, single-slot ownership, normal
   cooldowns and goal retries remain active. There is no hidden route/evidence lookup or new movement
   algorithm. Search progress and assignment time are bounded; discovery is not guaranteed.

8. **Discovery.** VisibilitySystem and BattleKnowledge teach actual observed remains normally.
   Search completion teaches nothing. A visible real target within the existing 10-unit interaction
   radius can produce one significant `party_encounter` observation per commission; reserved parties
   and distant spotting cannot. Participating parties and important living members learn it.

9. **Reporting.** Real Travel returns the worker to the original employer location. The employer
   must be alive and physically there, and neither participant can be reserved. Intentional
   `Knowledge.share` transfers only relevant personally known events/details; no authoritative
   log is used to fill unknown details. Reports work with ambient arrival exchange disabled.

10. **Outcomes.** A sufficient report satisfies the sponsor's question through the existing
    satisfaction API. An honest empty/partial report still completes the service and resolves
    FulfillObligation, while AcquireKnowledge remains unsatisfied. ProvideService can resume.
    Missing employers leave the surviving investigator and its information waiting at home.

11. **Interruption, loss and retry.** Recovery preserves work, current center and sampled elapsed
    search progress while cancelling owned movement. Pause and encounters suspend execution.
    Death/removal/lost command cancel work without deleting surviving resources or leaking a remote
    death to the sponsor. Open offers are retained. Completed or locally known cancelled attempts
    retry after 24 world hours by default. An absent report expires after 480 world hours from
    acceptance, followed by that retry delay. The worker independently knows the same time allowance;
    employer expiry sends no remote stop instruction. Late reports remain usable; an expired service
    stays cancelled. Actual caravan return resolves sponsor uncertainty locally without cancelling
    the remote investigator. Configuration is on InvestigationSystem, not a new scheduler.

12. **Debuggers.** F1 displays sponsor targets/times/queries/events/services/worker/retry state and
    investigator phase/route/activities/findings/return/report state. F2 keeps generic service and
    battle history, adding descriptions for physical encounter and sponsor-return occurrences.
    Service history includes the target ID. F3 automatically includes commissions in the existing
    registry and explicitly labels target caravans in its detail pane.

13. **Files changed for 7E.**

    - New: `src/ecs/components/investigation_work.lua`;
      `src/systems/parties/resident_travel.lua`;
      `src/systems/services/investigation_system.lua`;
      `tests/unit/investigation_scenario.lua`; this report.
    - Updated: `src/ecs/components/init.lua`; `src/game/campaign/campaign_runtime.lua`;
      `src/systems/goals/goal_definitions.lua`; `src/systems/goals/goal_system.lua`;
      `src/systems/knowledge/knowledge_system.lua`; `src/systems/services/caravan_system.lua`;
      `src/systems/services/service_system.lua`;
      `src/systems/world_activities/travel_activity.lua`; `src/debug/inspector.lua`;
      `src/ui/screens/service_viewer.lua`; `src/ui/world_event_text.lua`;
      `tests/unit/main.lua`; `docs/CAMPAIGN_ARCHITECTURE.md`.
    - Other changes already present on arrival, including 7D Search and removal of the old AI
      system, were preserved. This report's file list distinguishes 7E from the overall Git diff.

14. **Automated validation (2026-10-28).** Dedicated investigation scenarios, the full current
    runner (36 scenarios plus navigation), both playable-preview smoke variants, and
    `git diff --check` pass. Existing assertions were not weakened. Coverage includes before-due
    and overdue living caravans, known fate, no remote lookup in recognition, independent targets,
    goal reconfiguration, known-opportunity/capability gates, no duplicate commissions, registry
    history, real identity-preserving parties, route without hidden evidence, Travel/Search,
    pause/reservations, recovery during Search, real remains discovery, unseen remains, no remote
    knowledge, report with ambient exchange disabled, partial detail sharing, empty searches,
    valid returned memberships/resources, retries, worker death, unavailable employer, surviving
    caravan contact, and caravan return during a reserved ongoing investigation. Existing regression
    suites cover ordinary knowledge propagation, navigation obstacles, raids, recovery, loot and
    caravan/service behavior. Preview smoke runs exercise WorldState and F1 rendering, while the
    scenario also draws the existing F3 and F1 views.

15. **Known limitations.** Commissioned wages are not implemented, so investigation commissions
    are unpaid. Search is bounded random exploration and can miss evidence or fail navigation.
    Partial Search elapsed time is sampled at campaign updates, so interruption can repeat up to
    one update's worth of searching; the assignment deadline remains authoritative. Employers are
    sought only at the original location. Removed/unreachable home locations preserve unresolved
    workers and information; there is no remote tracking or rescue. Timed-out workers can still
    return with a useful report, but their cancelled service is not reopened. Fixtures control
    battle HP to produce reproducible real remains; they do not test combat balance or award
    investigation evidence. Full save/load and the explicitly excluded gameplay systems remain
    outside this milestone. No human interactive playtest was performed.

16. **Exact manual playtest.** From `D:\Projects\Realm-of-Geherra` run:

    ```powershell
    & 'C:\Program Files\LOVE\love.exe' tests/unit investigation_scenario --preview
    ```

    The fixture has already sponsored/dispatched a caravan and resolved a real defeat on a
    navigable route. The investigator is still an independent resident with no evidence or offer
    knowledge. A visitor is traveling to Sponsor Town; seeded normal arrival gossip brings the
    known offer. F1 starts on the merchant, and its existing debug roster links to the investigator.
    Hold Space to advance; release it to pause. Let the visitor arrive, then watch the investigator
    accept, depart in a real party, travel/search and return. F1 inspection is live; its editing
    forms pause. Use H to injure the investigator and inspect recovery before work resumes.
    Use F2 to compare global departure/battle/service history with the merchant's personal known
    events in F1. Use F3 to inspect target, capability, assignment and immutable event IDs. F2/F3
    pause time while open; close them to continue. After physical reporting, the service completes,
    the merchant's knowledge goal is satisfied and the investigator retains memory in residency.

    For the empty-handed variant:

    ```powershell
    & 'C:\Program Files\LOVE\love.exe' tests/unit investigation_scenario --preview --empty
    ```

    This caravan made a real off-route detour before defeat. The same intended-route search should
    complete without learning the hidden battle. After reporting, inspect a completed commission
    alongside an unsatisfied knowledge goal; after the retry interval a new unfilled offer appears.
    Ordinary discovery still applies if the player chooses to visit the off-route site.

    Reproduce automated checks with:

    ```powershell
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit investigation_scenario
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit investigation_scenario --preview-smoke
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit investigation_scenario --preview-smoke --empty
    git diff --check
    ```
