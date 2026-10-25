# Battlefield Remains — TODO & Future Ideas

> Design backlog for the LÖVE2D / Concord ECS world simulation. These are **planned ideas**, not implemented features. Prioritize small, testable milestones; reuse the existing dialogue, visibility, location, inventory, and world-time systems.

## Current baseline (implemented)

- [x] NPC battles create map-owned battlefield remains with encounter history, actual casualty corpse snapshots, abandoned cargo and gold.
- [x] Battlefield sites can be discovered, remembered, rendered, and inspected through the existing location/dialogue flow.
- [x] **Search for Supplies** transfers all abandoned cargo and gold to the player, preserves item metadata, and removes collected resources without duplication.
- [x] World simulation pauses when world time does not advance.
- [ ] Actual save-file I/O for remains and discovery (map serialize/restore helpers exist, but global `Save` is still a stub).

## Priority 1 — Complete basic battlefield interactions

- [ ] **Audit corpse possessions before coding looting.** Trace `LootResolver`, `LootApplication`, equipment IDs, durability, and personal inventories. Determine which possessions are already taken by the victor, which are lost, and which remain recoverable. Prevent duplicated equipment and silent item loss.
- [ ] **Loot Corpses.** Store recoverable possessions per corpse (or references to a dedicated corpse-loot record); inspect and collect them using existing dialogue/inventory transfers. Preserve item identity, metadata, and durability. Empty corpses remain identifiable.
- [ ] **Bury the Dead.** Remove or mark selected corpses as buried; keep battlefield history. Define whether burial is individual or all-at-once, and whether it requires tools or resources (not required initially).
- [ ] **Integrate player battles with shared loot/remains rules.** Preserve current victory/favor/UI behavior while migrating away from unrelated generated troop drops where appropriate. Ensure both player and NPC casualties produce corpse records and resources are conserved.
- [ ] **Manual end-to-end playtest.** NPC raid → battlefield appears → discover → inspect → collect supplies → inspect again; verify correct corpses, cargo, gold, and ordinary dialogue behavior.

## Priority 2 — Time, risk, and persistence

- [ ] **Searching takes world time.** Use the shared world-time advancement model for searching supplies, looting corpses, and burial. The world (including NPC movement and encounters) progresses while the player works. Start with fixed durations; later vary by quantity, skill, and tools.
- [ ] **Interruptible actions.** If enemies arrive while the player is searching or burying, interrupt safely. Decide whether partially completed work yields partial results; never duplicate resources.
- [ ] **Save/load integration.** Persist remains, corpse state, collected resources, discovery, and any in-progress action using the real save pipeline once implemented.
- [ ] **Battlefield aging.** Corpses decay, equipment deteriorates, and sites eventually fade or disappear. Use world time, not wall-clock time; retain notable sites when story-relevant.
- [ ] **Clear lifecycle and cleanup.** Remove empty, expired sites without breaking discovery records or active dialogue; avoid unbounded growth in map objects.

## Priority 3 — Emergent world behavior

- [ ] **NPC scavengers.** Bandits, travelers, or scavengers discover and loot remains through the same transfer mechanics, competing with the player for finite resources.
- [ ] **Necromancy.** Corpses retain enough identity/species/type information to raise suitable undead. Raising consumes or changes the corpse record; never duplicates bodies. Different corpse condition can affect results.
- [ ] **Burial and desecration consequences.** Nearby factions, relatives, religions, or settlements react to burial, grave robbery, and necromancy when witnessed or discovered. Avoid omniscient NPC knowledge.
- [ ] **Investigation and tracking.** Read tracks, banners, wounds, and evidence to infer who fought and where survivors or attackers went. Skill checks may reveal hidden sites or additional history.
- [ ] **Rumors and quests.** NPC witnesses or settlements spread reports of battles, missing caravans, unburied dead, or undead sightings. Reuse world events and dialogue rather than hand-authoring each encounter.
- [ ] **Site discoverability by context.** Large/recent battlefields are easier to spot; terrain, weather, and Tracking/Divination modify discovery. Separate current visibility from remembered discovery.
- [ ] **Wildlife and monsters.** Carrion eaters or opportunistic monsters may gather at corpse-rich sites, creating new encounters.
- [ ] **Return to camp / stolen-goods economy.** Successful raiders eventually transport plunder to camps or markets instead of endlessly raiding; stolen goods remain real circulating resources.

## Priority 4 — Combat and world-system extensions

- [ ] **Morale, routs, surrender, and retreat.** Battles currently fight to the last combatant. Future results should distinguish killed, fled, surrendered, and captured actors; only actual dead create corpses. Surviving defeated parties retain appropriate goods.
- [ ] **Prisoners and ransom.** Captives become world actors/resources with potential rescue, escape, or ransom stories; do not treat them as corpses.
- [ ] **Equipment wear and battlefield damage.** Define explicit item outcomes (recovered, damaged, destroyed, retained) and conserve item identity where possible.
- [ ] **Ground remains after non-raid/player encounters.** Apply consistent policies across encounter types, with plunder eligibility determined by context, not victory alone.

## Design invariants

- **One source of truth:** battlefield sites reference map-owned remains; dialogue and map markers do not duplicate loot or corpse data.
- **No duplication:** every resource has one outcome (transferred, retained, destroyed/lost, or left at the site); collection applies at most once.
- **Real casualties only:** corpse records come from actors actually killed, not merely defeated or routed.
- **Shared world time:** movement, encounter progress, cooldowns, decay, and time-consuming interactions use the same simulation clock.
- **Visibility is knowledge:** NPCs and players should discover evidence rather than know about distant events automatically.
- **Small increments:** implement one action or system at a time with automated tests and manual playtesting.
