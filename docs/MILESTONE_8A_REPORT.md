# Milestone 8A implementation report

Implemented Dynamic Goal Importance only, retaining the existing 7D/7E working-tree changes.
The architecture details and initial balancing values are in
[CAMPAIGN_ARCHITECTURE.md](CAMPAIGN_ARCHITECTURE.md#milestone-8a-dynamic-goal-importance).

1. **Architecture inspected.** Actor-owned goal registry/construction, capabilities, selection,
   all six goal types and registered extensions; recovery/shared regeneration; Raid/Roam;
   services, healing and payment; caravan preparation/dispatch/trade/delivery/cooldown;
   commissioned investigation/search/report state; filtered personal knowledge; Travel and
   activity sequence ownership; independent residents, local followers and party leadership;
   campaign time, pause and runtime ordering; F1 editor/inspector, service viewer, F2/F3 bindings;
   scenario/navigation harness and campaign architecture. Fixed-priority contracts existed in
   selection, the special recovery override, immediate obligation selection after application,
   inspector ranking and the debug editor. Service availability previously required selected
   ProvideService; obligation execution already followed selectedGoalIndex.

2. **Representation/API.** `GoalSystem.getImportance(goal, actor, commandedParty)` returns a
   clamped 0–100 value with no gameplay execution. Existing definition specs now optionally
   provide an importance calculator. The single legacy `priority` field is base configuration,
   not a competing calculated score; authored `importance` aliases it at construction. Legacy
   registered extensions fall back to that base, clamped. Scores of zero retain their goal.

3. **State/time separation.** Recovery, wealth, knowledge and obligations read current state.
   The optional definition hook `advanceImportance(goal, actor, party, dt)` advances accumulated
   state once per positive world interval, before selection, including non-dominant goals.
   No production accumulated motivation is added. A synthetic scenario verifies pause, reads
   without advancement, exact intervals despite duplicate resident references, large elapsed
   updates and continued state retention while another motivation controls the actor. Units
   stay existing simulation seconds (1 second = 1.5 world hours), not raw render seconds.

4. **Selection.** Highest eligible positive score wins; insertion order breaks ties. An eligible
   incumbent yields at a challenger difference of at least five, including exactly five.
   Zero/satisfied/cancelled/completed/invalid/ineligible incumbents release immediately. Failed
   attempts retain existing retry/fallback behavior. With all zeros, no goal is selected and
   no new idle activity is invented. State reads run every positive simulation update; old
   evaluation-cooldown data is retained inertly rather than gating recalculation.

5. **Ownership/progress.** Switching releases only the exact goal-owned activity sequence and
   actor ID; reserved encounters defer release. Goals, service references, destinations,
   caravan phases/preparation/cooldown, personal memories and investigation centers/elapsed
   search stay intact. New Travel plans from actual position. Manual/external activities are
   preserved. Cancelled investigations archive progress after reservations clear, resolve the
   obligation once, and keep their real party position rather than inventing ReturnHome.

6. **Existing goals.** Rest uses HP/party urgency. AcquireWealth keeps the `acquire_gold` ID and
   uses the actual treasury/target ratio. FulfillObligation uses Responsibility. ProvideService
   keeps configurable base 20. AcquireKnowledge uses existing knowledge satisfaction, scoring
   zero when known and base importance otherwise; its default is now 90 so missing-caravan
   questions remain competitive with dynamic wealth. Uncommissionable questions stay blocked.
   ReachLocation has configurable default 40 and zero at actual stationing. Extensions retain
   base-priority fallback. Existing explicit values are retained, with required 0–100 clamping.

7. **Recovery calculation.** Remaining HP 100/80/50/40/20/0% maps piecewise to 0/15/60/80/95/100.
   Leaders take the maximum of personal urgency and transformed mean living-member health plus
   a bounded critical-member bonus (below 30% HP, weight 0.5). Count never multiplies urgency;
   non-leaders read personal HP. The old 60%/90% gates and unconditional safety override are
   removed. With no competitor recovery can continue to full HP; competing motivations use
   ordinary hysteresis. Rest completion uses group urgency, while the existing Recovery system
   alone grants healing. Settlement selection and local purchase rules remain unchanged.

8. **Wealth.** `clamp(100 * (1 - gold / amount))`; configured targets are preserved and omitted
   targets default to 10000. Target zero is satisfied. Party leaders use shared treasury,
   independent residents personal gold. Reaching/exceeding target gives zero; subsequent loss
   reactivates motivation. Roam/Raid and CaravanFormation stay the execution methods. The
   30-day sponsorship cooldown and ongoing preparation survive switches.

9. **Responsibility.** Optional `actor.responsibility`, clamped 0–1, default 0.5. Importance is
   `50 + 40 * responsibility` (50/70/90). No timer/deadline growth, trait generation or personality
   representation. Accepted work persists during interruptions; terminal assignments score zero
   and retain resolved records. Service closure/event idempotency remains in ServiceSystem.

10. **Compatible services.** Central Services.isProviding requires an attached active-capable
    ProvideService goal and compatible physical/local availability, rather than dominance.
    A safe independent resident recovering locally can treat customers. Party Rest, Travel,
    combat and conflicting obligations remain unavailable. Non-dominant service goals never
    initiate opportunity travel. Player/NPC payment and healing share canPerform/perform.
    Automatic caravan dispatch waits for its worker's dominant obligation; preparation persists.

11. **F1.** All attached goals display current scores, dominant/non-dominant state, status/reason,
    targets, accumulated value, service ID/Responsibility and owned activity sequence. Current,
    previous dominant goal and switch reason are visible. Editor labels the legacy field as base
    importance. The service viewer reports actual dominance for passive providers. F2/F3 unchanged.

12. **Files changed for 8A.** Existing unrelated checkout changes were left in place.

    - Added `src/systems/goals/goal_importance.lua` and `tests/unit/dynamic_importance_scenario.lua`.
    - Updated `src/systems/goals/goal_system.lua` and `goal_definitions.lua`.
    - Updated `src/systems/actors/recovery.lua` and `src/systems/world_activities/rest_activity.lua`.
    - Updated `src/systems/services/service_system.lua`, `caravan_system.lua`, `investigation_system.lua`.
    - Updated `src/debug/inspector.lua` and `src/ui/screens/debug_overlay.lua`.
    - Updated `tests/unit/main.lua`, `npc_goals_scenario.lua`, `recovery_scenario.lua`,
      `services_scenario.lua`, `debug_mode_scenario.lua`, `knowledge_search_scenario.lua`,
      `investigation_scenario.lua`.
    - Updated `docs/CAMPAIGN_ARCHITECTURE.md` and added this report.

13. **Validation.** Before edits: all 36 scenarios plus navigation passed, so no pre-existing
    failures were observed. After 8A: all 37 scenarios plus navigation pass, including headless
    battles, raid/world encounters, campaign ordering, knowledge/search, services/payments,
    player-led and autonomous caravan return/finance, investigation interruption/reporting,
    recovery, navigation and debug viewers. New tests cover thresholds, deterministic ties,
    zero persistence/idle, state reactions, calculation purity, accumulation/pause, nonlinear
    party health, Responsibility, terminal assignments, non-dominant local services, external
    ownership and fresh route origin. Investigation coverage also verifies reserved cancellation
    without teleporting or duplicate service events. No regressions remain. Older assertions
    that specified removed 60%/90% gates, priority-1000 defaults, recovery-only cancellation
    naming or selected-only provider availability were replaced with the specified 8A outcomes;
    their ownership/payment/progress checks remain. `git diff --check` passes.

    Actual LÖVE preview smoke runs passed for caravan and investigation viewers (populated and
    empty), in addition to debug/service rendering exercised by the suite. Commands:

    ```powershell
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit dynamic_importance_scenario
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit caravan_scenario --preview-smoke
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit investigation_scenario --preview-smoke
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit investigation_scenario --preview-smoke --empty
    git diff --check
    ```

14. **Limitations.** Formulas are initial balancing values, not human-playtested tuning. State
    evaluation/knowledge scans now run on each positive campaign update, preserving prompt
    response; large-campaign performance has not been profiled. Accumulation is infrastructure
    plus a synthetic regression, deliberately without a new production motivation. Cancelled
    investigations retain their party at its real position; there is no automatic ReturnHome.
    Full save/load remains outside scope. No human interactive play session was performed.

15. **Manual playtest.** From the repository root:

    ```powershell
    & 'C:\Program Files\LOVE\love.exe' . --debug-campaign
    ```

    Open F1 and inspect Bel-Naram, Ashur, Ninsun and Ur-Salim. Advance time with the existing
    wait/rest controls; observe healthy recovery scores at zero, wounded Ur-Salim recovering,
    merchant wealth scores, accepted obligations and local healer availability. Use the existing
    NPC/party editor to give an important traveler ReachLocation plus RestAndRecover; inspect
    the score/switch reason as health changes through normal encounters/healing. Confirm the
    destination and service ID survive recovery, and the resumed route begins at the new position.
    For the exact 70/74/75 threshold probe, run dynamic_importance_scenario above: F1 editor
    reconfiguration intentionally cancels/replaces goals and therefore is not a probe of an
    existing incumbent. Set static goals to zero in the editor and verify no new primary activity. Pause and confirm elapsed state/retry timers stop. F2/F3
    should still open their existing viewers. The investigation previews above provide focused
    search/recovery/report fixtures; watch center/search progress persist through an interruption.

16. **8B remains deferred.** ReturnHome/homesickness, the broader personality model and Greed
    generation, persistent injuries and their effects, SeekSafety/group fleeing, traveling injury
    treatment and the other explicitly excluded systems are not implemented.
