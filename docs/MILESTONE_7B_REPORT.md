# Milestone 7B implementation report

1. **Architecture inspected.** Read the current campaign architecture and traced actor goals,
   priorities, capabilities, recovery, RestActivity, TravelActivity, WorldActivitySystem, location
   membership, important-character memory, events/knowledge, inventory/treasury transfers,
   player dialogue, F1/F2, WorldState and the campaign ID allocator. The checkout already had
   substantial modified and untracked work; those changes were preserved. No agent delegation,
   world generation changes, commit or 7C work was performed.

2. **ServiceSystem.** Added `src/systems/services/service_system.lua`. Its APIs cover local provider
   discovery, eligibility and immediate execution; create/get/list/isAvailable/assign/complete/
   cancel requests; participant cleanup and learning current status on contact. Context is
   `{world, map}`. Public request/list reads return detached plain-data snapshots.

3. **Player and NPC healing.** Both use the same `Services.perform(provider, customer, "heal",
   context)`. Healing changes actual actor HP, caps it at maximum, rejects dead/full-health
   actors and revalidates conditions on every execution. NPCs call it from recovery; existing
   player conversations gain a priced healing option and display the operation's result.
   A focused test executes the actual dialogue callback, including a funds change after the
   choice was displayed.

4. **Recovery travel discrepancy and authorized change.** This checkout had no settlement
   travel in RestAndRecover: it rested in place. The user explicitly requested adding nearest-
   settlement travel after this was reported. Recovering real party leaders now reuse generic
   TravelActivity to the nearest town/village/castle, chosen solely by distance. Provider lookup
   happens only at a real settlement after arrival. RestActivity, passive regeneration, 60%/90%
   thresholds, shared party recovery and encounter handling retain their existing rules. With
   no settlement the old in-place rest fallback remains; unreachable routes retry normally.
   Independent residents have no newly invented travel/party transition.

5. **Healing utility and payment.** Defaults are 40 HP for 10 gold. Autonomous recovery needs
   at least 20 useful HP and waits 30 world seconds between attempts/purchases. Unaffordable or
   unavailable healing falls back to rest. Party members transact using their real party
   treasury; independent actors use personal `treasury`, initialized to zero. The existing
   `InventorySystem.transferGold` operation debits and credits the owners. Same-treasury and
   self-service transactions are rejected. No money is created. Paused world time freezes the
   autonomous decisions and retry counters.

6. **Request ownership and lifecycle.** Plain records live in `campaign.serviceRequests`, with
   non-reused campaign `service_*` IDs and multiple requests per employer. Lifecycle is open ->
   assigned -> completed, with cancellation from open or assigned. Terminal records are retained.
   The registry is the single authority for assignment. Repeated terminal calls are idempotent;
   duplicate assignment and incompatible terminal transitions fail. Missing/dead participants
   or a removed location cancel pending work safely on the next positive-time update.

7. **ProvideService.** This actor goal defaults to priority 20. Ordinary commercial availability
   requires its actual active selection, an important living provider, the required capability,
   physical locality, and no incompatible activity/encounter or accepted obligation. Important
   stationed followers may provide locally without commanding travel. Remote opportunities
   come only from the actor's learned service/employer/location event details. No global request
   scan discovers jobs. Stale applicants learn current closures at the employer on arrival.

8. **FulfillObligation.** Successful hiring appends and selects this actor-owned goal at priority
   80, referencing the service ID. ProvideService remains in the goal list. Recovery may supersede
   it without destroying the assignment. Unrelated hiring and wholesale goal replacement are
   blocked while work is accepted. Completion/cancellation resolves it; ProvideService can resume.
   A missing/invalid assignment resolves safely on evaluation. It is not a World Activity, and
   has no invented profession executor in 7B.

9. **Capabilities and operational state.** Capabilities remain actor-owned named boolean flags,
   independent of selected goals. The architecture document now specifies separate actor-owned
   capability runtime components for future persistent preparations/cooldowns; they may retain
   service IDs but must not duplicate assignment status. Heal needs no runtime component. No
   generic capability-runtime framework or CaravanFormation component was added.

10. **F3 viewer.** A full-screen two-panel view follows F2's layout: request/provider list on the
    left, complete selected details on the right. Requests show ID, type, employer, location,
    capability, status and worker; details include actor/location IDs, lifecycle event IDs and
    arbitrary request data. Providers show name/ID, actual location, selected goal, capabilities,
    price and amount. F3/Escape/Close closes; Tab switches views; 1/2/3/4 selects all/open/assigned/
    closed; R refreshes. Click selects; wheel scrolls either panel. Availability is derived only
    on opening/refresh, with no persistent provider registry. The viewer pauses simulation,
    consumes gameplay input, handles empty lists and draws only visible rows.

11. **F1/F2.** F1 adds actual selected goals, capabilities, providing status, obligation IDs,
    owned requests and their status/worker, and recent service results. A new existing-inspector
    action, Add Heal / ProvideService, appends the capability/goal to an important NPC for
    playtesting. Goal replacement while assigned returns a readable error. F2 gains readable
    service_offered/filled/cancelled/completed summaries. Knowledge projections independently
    filter time, service, employer, location and outcome. Only direct participants automatically
    learn a service occurrence; unrelated distant actors are not informed. Ordinary healing
    records no historical event. F2 and F3 can switch directly between one another.

12. **Files changed for 7B.** These are this implementation's files, not the pre-existing dirty
    working tree's full file list:

    - `src/systems/services/service_system.lua` (new)
    - `src/systems/goals/goal_system.lua`
    - `src/systems/knowledge/knowledge_system.lua`
    - `src/ecs/assemblages/unit.lua`
    - `src/game/states/dialogue_state.lua`
    - `src/game/states/world_state.lua`
    - `src/ui/screens/service_viewer.lua` (new)
    - `src/ui/screens/debug_overlay.lua`
    - `src/ui/world_event_text.lua`
    - `src/ui/knowledge_text.lua`
    - `src/debug/inspector.lua`
    - `src/debug/campaign_tools.lua`
    - `tests/unit/services_scenario.lua` (new)
    - `tests/unit/recovery_scenario.lua`
    - `tests/unit/main.lua`
    - `docs/CAMPAIGN_ARCHITECTURE.md`
    - `docs/MILESTONE_7B_REPORT.md` (new)

13. **Tests.** All 23 existing/new unit scenarios were run independently with LÖVE 11.5;
    20 pass. The new services scenario and existing recovery, goals, debug, time sync, knowledge,
    travel and travel-knowledge scenarios pass. Recovery tests now station parties when testing
    already-arrived rest and recognize important local followers without granting party command.
    Real LÖVE render snapshots covered requests, providers and empty views at 800x600, 1024x768
    and 1280x720. Visual inspection found and fixed row-selection clipping and checked readable
    details. `git diff --check` passes.

    The three previously documented failures remain:

    - `headless_battle_scenario.lua:152`: first matchup times out, winner nil, 4000 ticks,
      HP 10000/30.
    - `world_encounter_scenario.lua:236`: assertion fails after its supposed victory encounter
      times out with no casualties.
    - `battlefield_remains_scenario.lua:190`: eliminated-party duplicate-cargo assertion fails
      after the underlying encounter times out.

14. **Limitations.** Normal gameplay was not manually completed end-to-end. Windows computer
    capture failed on the interactive fixture, first with `FrameArrived timed out: timed out
    waiting on channel`, then `window capture timed out: timed out waiting on channel`; the
    automation attempt stopped. Automated actual-renderer and input-routing tests plus exported
    visual snapshots passed. The interactive fixture remains available for human review.
    Services remain opt-in; generation does not automatically configure witches. Independent
    residents cannot seek remote jobs without an existing real party transition. Commissions
    hold until explicit completion/cancellation because actual profession execution is 7C+.
    Request-specific constraint callbacks, commission wages, economy, save/load and every other
    excluded profession remain unimplemented. A live employer moving from the advertised
    location makes the old offer unavailable; no automatic relocation/re-advertisement is added.

15. **Manual playtest.** From the repository, run:

    ```powershell
    & 'C:\Program Files\LOVE\love.exe' tests/unit services_scenario --preview
    ```

    This uses the existing test runner and creates 16 small commissions, including open,
    assigned, completed and cancelled work, plus a local healer. It executes no placeholder
    profession. Check F3 request details, filters, Tab providers, R, row selection, both scroll
    panes, F3/Escape/Close, F2 history and F1 inspector. Resize the window and repeat. The
    automated scenario additionally tests the full hiring/obligation/resumption chain.

    In a normal campaign, use F1 -> inspect a location -> inspect an important resident (or
    stationed party member) -> Add Heal / ProvideService. Enable Add RestAndRecover goal too.
    Advance world time to select the provider goal, then inspect it in F3. With the existing
    debugger, injure and fund a different NPC leader and add recovery: verify it travels to
    the nearest settlement regardless of healers, buys only after arrival, gains HP and pays
    actual treasury gold. Repeat with no funds or no healer and confirm ordinary rest. Injure
    the healer and confirm F3 excludes it during recovery, then includes it after recovery.
    Enter the provider's location and dialogue as the player and buy healing; verify the same
    HP/payment rules and failure results. Pause and confirm no autonomous purchases occur.

    To run the focused automatic fixture:

    ```powershell
    & 'C:\Program Files\LOVE\lovec.exe' tests/unit services_scenario
    ```

Milestone 7B stops here. CaravanFormation, caravan preparation/cooldowns and investigation
behavior require review and a later milestone.
