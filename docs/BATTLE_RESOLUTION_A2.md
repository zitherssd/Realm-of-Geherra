# A2: Shared campaign battle resolution

## Flow before this change

Both modes created a `BattleSimulation` with its own Concord world and copied
battle units. Ticks updated those units and collected casualties without writing
campaign HP, equipment, inventories, or rosters.

| Terminal consequence | Interactive player battle | Headless NPC encounter |
| --- | --- | --- |
| Completion | `BattleState.checkBattleEnd` counted living teams; victory or mutual-death draw, with no tick limit. | `HeadlessBattleRunner.advance` detected either winner, mutual-death draw, or tick-limit timeout and built an `EncounterResult`. |
| Actor persistence | Wrote player HP, max HP and status effects, plus surviving player equipment/durability. Removed player casualties from the roster. Enemy actor state and roster stayed unchanged, including on player defeat. | `CampaignBattleResultApplier` validated complete rosters, persisted HP and survivor equipment/durability on both sides, and removed all defeated actors. It did not persist max HP/status effects. |
| Party removal | On player victory with a map, attempted enemy removal and emitted `party_killed`. An empty player party and mutual-death parties were left in place. History listed the enemy as eliminated only if map removal succeeded. | Removed every empty party from the map and emitted `party_killed` once per eliminated party. Draws could eliminate both; timeouts required survivors on both sides. Campaign entities remained registered. |
| Player rewards | Called `LootGeneratorSystem.generateFromTroop` for enemy casualties. Credited generated gold only on victory. Awarded favor using enemy pre-casualty power divided by player post-casualty power: `floor(4 + ratio * 8)`. Returned generated items to the existing battle-end/loot-selection UI; items were not automatically credited. Drop generation also ran on nonterminal checks, discarding those intermediate rolls. | No troop-table drops, generated gold, favor, or loot-selection UI. |
| Possessions and plunder | No automatic possession recovery, cargo/treasury plunder, destruction accounting, or battlefield remains. Existing possessions were untouched. | `LootResolver` planned defeated actors' possessions and explicit plunder policy. Losing actors' recoverable possessions went to the winner even without cargo plunder permission. Eligible cargo used the existing stochastic stolen/destroyed/retained split; gold used stolen/retained shares. Broken equipment was destroyed. |
| Resource application | Existing player drop policy only. | `LootApplication.prepare` validated resource accounting before mutations. `apply` transferred resources, cleared accounted-for defeated actors' stores, retained resources with surviving parties, and placed eliminated parties' retained resources into remains. Draws/timeouts awarded no combat loot or plunder; casualties could still produce remains. |
| History | Captured participant IDs/names at entry; built a `battle_ended` event at completion with time, position, ticks, winner/defeated IDs, casualties and successful enemy removal. No battlefield ID. | Captured participants and survivors before loot/casualty application; recorded the same event type with eliminated IDs and an optional remains ID, then linked the remains history to the event. |
| Knowledge | Taught surviving participants and surviving parties through `BattleKnowledge.learnParticipants`, using a survival snapshot. Dead participants learned nothing. | Same hook and rule, separately wired. Later visible remains could teach observers through the existing discovery hook. |
| Lifecycle | Guarded completion before notifications. Recorded history/knowledge before `onVictory`, then `onComplete`. Victory opened `battle_end`; defeat/draw opened `menu`. `exit` destroyed the simulation. Location-generated opponents could be absent from the traveling map. | Reserved both parties, advanced by world time, then added cooldowns, removed the active encounter, released reservations (including removed parties), notified the originating activity, and cleaned the runner. Failure also released/cleaned and reported an error. |

## Shared operation

`CampaignBattleResolution.resolve(result, context)` composes existing campaign
operations. It does not run combat or introduce a new result/loot representation.

- `BattleSimulation:getOutcome()` and `:buildResult(outcome, winnerPartyId)` now
  provide the former headless result contract to both callers. Actor snapshots
  additionally carry optional final `maxHp` and copied `statusEffects`.
- The context supplies the completed owning `encounter`, campaign `map`, and an
  explicit `rewardPolicy` (`player` or `npc`). Player battles supply their two
  authoritative `parties` in result order, supporting location-generated enemies
  and mapless battles. NPCs continue resolving parties through the map.
- Before mutation, the operation validates the existing result contract, captures
  historical participants/survivors, and, for NPCs, prepares the existing loot
  plan. For player rewards it captures enemy power before casualty removal.
- The explicit NPC branch invokes `LootResolver`/`LootApplication` unchanged. The
  player branch invokes the existing troop generator once at terminal resolution;
  only player victory credits gold/favor. Generated items still await selection
  in the unchanged `BattleEndState`/`LootScreen` flow.
- Both branches invoke `CampaignBattleResultApplier`, construct/record one history
  event, teach surviving participants, and link any NPC remains to that event.
- The owning handle caches the completed resolution. Repeated calls return it
  before revalidating removed parties or rolling rewards. A guard set before
  mutations ignores reentry from casualty notifications. Lower-level duplicate
  guards (`resultApplied`, `lootApplied`, `remainsCreated`) remain in force.

`BattleState` retains input, tick pacing, rendering, completion callbacks, and
screen transitions. `WorldEncounterSystem` retains reservations, cooldowns,
activity notifications, failure handling, and runner cleanup. Neither caller
independently implements history or participant learning anymore.

## Deliberate consistency corrections

Final HP, max HP, status effects, survivor equipment wear, defeated-actor roster
removal, empty-party removal and elimination notifications now apply to both
sides in either mode. This fixes the interactive path's stale enemy rosters and
empty player/draw parties, and persists NPC terminal statuses/max HP. Elimination
history describes empty rosters, including detached location opponents, rather
than depending on whether a map removal happened to find a traveling party.

Player drops now roll only at completion, not on every frame after an enemy
casualty. Drop tables and probabilities are unchanged; the global random stream
will no longer consume those discarded intermediate rolls. Player reward policy
does not recover NPC possessions or create remains. NPC reward policy does not
generate player drops/favor. No combat formulas, inventory formats, or loot
probabilities changed.

## Verification and remaining limits

`campaign_battle_resolution_scenario` submits matching terminal simulation states
through actual player and NPC callers for either winner and mutual death. It
compares complete actor results, participant snapshots, defeated/eliminated IDs,
and checks final actor state and knowledge. It also covers NPC partial-casualty
timeout, detached location opponents, nested casualty notifications, repeated
completion, player gold/favor/drop selection, NPC plunder/remains, reservations,
cooldowns, activity completion and runner cleanup. Existing battle, raid,
equipment, loot, remains, history, knowledge and runtime scenarios remain in the
full suite.

The exactly-once guard is scoped to the live owning encounter handle. Resolution
is not a database transaction or crash-recovery journal: an unexpected error
after mutation propagates and blocks replay on that handle; it cannot roll back
already-emitted notifications. Save/load remains outside A2. Player loot selection
remains a later UI action with its existing ownership rules. Player possessions
and NPC possession recovery intentionally remain different policies; combining
them would change gameplay and needs a separate decision.
