# M5.1-C — advanced conditions and presentation

Implemented on the existing Conditions/EffectiveStats, combat pipeline, execution
system, and battle renderer. No new spell engine, event bus, playable skill catalog,
or ECS migration. Injury treatment/recovery and starvation HP rules are unchanged.

## Damage contract

1. Existing effective weapon/skill damage + floor(effective Strength / 2) + exploding
   attack d6 - effective typed protection - exploding mitigation d6, clamped at zero.
2. Add `effects.outgoingDamage`, clamp at zero, then multiply by
   `effects.outgoingDamageMultiplier` (source conditions).
3. Add `effects.incomingDamage`, clamp at zero, multiply by
   `effects.incomingDamageMultiplier`, then `effects.incomingDamage_<type>Multiplier`.
4. Intersect outgoing/incoming minimum and maximum caps (`outgoingDamageMin/Max`,
   `incomingDamageMin/Max`), then floor and clamp at zero. Maximum caps win conflicts.

Stat bonuses, including Rage Strength, go through existing EffectiveStats exactly
once. Physical protection uses existing `protection_slashing`, `protection_piercing`,
and `protection_blunt` effect keys. Cold and lightning use the established `ice` and
`shock` damage types. Underlying permanent stats/protections are never changed.

`calculateDamage` returns a fully modified ordinary attack amount. `typedDamage`
returns a fully modified fixed periodic/reactive amount (typed protection, same
modifier/cap steps, no new dice). `_applyBattleDamage` commits the already calculated
amount to HP and preserves injury/morale/death handling. It does not reapply modifiers.
Periodic/reactive damage uses the existing status-damage flag to avoid extra injuries
and does not deliver ordinary skill on-hit effects. Direct raw HP-loss callers such
as starvation retain their existing behavior.

Projectile defense now matches the requested formula exactly:
`Precision/8 + 2eD8 > 2eD8 + 2*ShieldDefense + projectileDefense`.
The prior implementation's unexplained constant +2 was removed. Ties miss. The
condition `effects.projectileDefense` term contributes no physical shield defense;
shield durability only changes when removing the actual shield contribution would
have turned a defended contact into a hit. `defenseMode="none"` skips defense dice.

## Reactions and lifetime

Condition definitions may specify one reaction table per event, for example:

```lua
reactions = {
    onHitReceived = {damage=3, damageType="fire", meleeOnly=true},
    onHitDealt = {apply={poison=true}}
}
expiresOn = {event="onHitReceived", chance=0.2} -- or triggers=3 (or both)
```

A reaction supports fixed damage, damage type, a map of condition applications,
optional `target="self"` (otherwise the opposing combatant), optional `chance`, and
optional `meleeOnly`. These are data primitives, not a scripting language.

Attack events are dispatched after primary attack resolution in this order:
`onAttackReceived` (even a miss), `onHitReceived` (successful contact, including zero
HP damage), `onDamageReceived` (actual primary HP loss), then `onHitDealt` on the
attacker. Primary protection/caps therefore apply before hit-triggered expiration.
Harassed still applies after its triggering melee roll/damage. Pure healing does
not count as an attack. Damaging and status-only AoE contacts do count; melee-only
reactions ignore projectiles/AoE. A defended projectile-area contact emits an attempt
on a miss; on a delivered area effect, targets receive one area event sequence.

Each event snapshots eligible conditions in ascending ID order and visits each once.
Reaction status maps also apply in sorted ID order. Reactive HP damage is terminal:
it emits no further condition events, so mutual retaliation cannot recurse. It still
uses normal HP/morale/death processing. Reactions can fire on a lethal triggering hit;
reactive effects only apply to a living destination. Expiration follows that condition's
reaction. Trigger counts survive refresh; replacement resets them. A chance is tested
once per matching event; count/chance expiration uses either criterion. The optional
`BattleSimulation.new(..., {conditionRng=fn})` supplies probabilistic reaction RNG.
No random calls occur for unconditional reactions or visual composition.

Periodic HP loss emits damage-received events only. Existing statuses do not store a
live source actor, so these events have no opposing retaliation target; self-targeted
reactions and expiration still work. Source-less pulses have no outgoing source buff.

Existing tick expiry, Burning refresh, Poison stacking, Harassed decay, battle cleanup,
and persistence remain. Definitions can explicitly use `battleLong=true` or
`lifetime="battle-long"` for an untimed battle-only condition. Permanent and persistent
lifetimes remain supported. Tactical status iteration and settlement unit iteration
are deterministic; newly applied/replaced statuses do not receive a stale extra tick.

## Cleansing

`Conditions.remove(actor,id,bodyPart)` remains the direct operation used by treatment.
`Conditions.cleanse(actor,{id=...,category=...})` removes eligible matching entries and
returns a count; omitted selectors match all eligible conditions. Status definitions
can use `category="buff"`, `category="debuff"`, and/or membership maps such as
`categories={poison=true,curse=true}`. `dispellable=false` explicitly protects an entry.
Injuries default to non-dispellable; only injury catalog definitions explicitly setting
`dispellable=true` permit magical cleansing. Injury identities and recovery rules stay
in InjurySystem. No individual cleansing spells were added.

## Presentation

`condition_visuals.lua` is a pure, render-only composer for active `visual` metadata:

- Alpha modifiers multiply, with the final alpha clamped to [0,1].
- Saturation modifiers multiply, with the result clamped at zero minimum.
- Tint entries sort by ascending priority, then condition ID. Each blends its RGB into
  the running white tint using its fourth component as weight (default 0.5). Higher
  priorities blend last and take precedence. RGB/weights clamp to [0,1].
- Visual metadata is optional; the default is white, opaque, full saturation.

The existing flash shader now also handles luminance-based saturation and tint.
Condition alpha is applied to the character draw color. Damage flashes still run.
The renderer's current battle actors use composite sprites (body/equipment pixels
already share the draw); presentation applies uniformly to that image. No layering,
animation, draw order, anchors, scaling, or collision geometry changed. Each actor
uses `push("all")`/`pop()` to restore color, shader, blend mode, and other graphics state.
Status auras and HP bars retain their existing presentation. The renderer's fallback
team circles remain unchanged; condition presentation targets character sprites.

Representative status definitions: Stoneskin (physical protection/desaturation),
Mistform (1-damage cap, 20% hit expiry, alpha .6), Immolation (melee fire retaliation),
Charge Body (melee shock retaliation), Air Shield (+4 projectile defense), Resist Cold
(half incoming ice damage), Rage (+4 Strength/red tint), and Poisoned Weapon (Poison
on hit). Existing Burning/Poison gain subtle warm/green tints. No playable spells added.

## Validation

Ran every `tests/unit/*_scenario.lua` independently: **46 PASS / 10 FAIL**. Every failed
scenario also fails against the pre-M5.1-C HEAD commit. New C, existing A/B, injury and
treatment, movement/collision, squads, Combat Power, headless battle, projectile
presentation, campaign results/resolution, survivors, and event scenarios pass.
Navigation passes; the combined runner stops at the pre-existing party-speed failure.

Existing failures: aoe (physical interception), campaign_runtime (line 92),
combat_regression (javelin damage), morale (fleeing survivors), party_speed,
personality_return_home, projectile (archer Precision), recovery (goal resume),
world_encounter (clock delta), world_time_sync (world-hour conversion).

Focused C tests cover damage order/caps/resistance, immutable stats, single modifier
application, event distinctions, zero-damage hits, projectile/AoE reactions, no
retaliation loops, deterministic RNG/expiry/order, cleansing/protected injuries,
projectile ties/defense bypass/shield wear, visual composition, actual shader pixels
on body/equipment regions, no-visual pixels, graphics state restoration, and matching
simulation HP with rendered versus headless runs. A/B scenarios retain refresh,
stacking, decay, restrictions/healing/settlement and persistence coverage.

After final ordering/AoE refinements, focused C, B, headless, campaign resolution and
navigation checks were rerun. `git diff --check` passes. Raw scenario results are in
`tests/m51c_test_results.txt`; comparison output is in `tests/m51c_baseline_comparison.txt`.

## Files changed

- src/data/statuses.lua
- src/game/battle/battle_simulation.lua
- src/game/battle/condition_visuals.lua (new)
- src/systems/actors/conditions.lua
- src/systems/battle/combat_system.lua
- src/systems/battle/execution_system.lua
- src/systems/battle/render_system.lua
- tests/unit/main.lua
- tests/unit/conditions_c_scenario.lua (new)
- tests/m51c_test_results.txt (new)
- tests/m51c_baseline_comparison.txt (new)
- docs/M51C_ADVANCED_CONDITIONS.md (this report)

No manual gameplay/art review was performed. Automated graphics tests use the actual
LÖVE shader/rendering path and composite fixture pixels. No summons, M6, full spell
catalog, new movement/AoE mechanics, campaign ticking, or resource rules implemented.
