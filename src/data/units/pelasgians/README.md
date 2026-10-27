# Pealasgia import

On 2026-10-26, added 16 unit templates from the Kosmokrator Pealasgia
`mod/pealasgia/pealasgia.dm` source to `pelasgian_units.lua`. The three existing
entries (`pelas_youth`, `pelas_tribesman`, `pelas_skirmisher`) retain their
Geherra stats, sprites, equipment, and loot. New entries record source monster
IDs in comments. These IDs are provenance only; they overlap Gaia source IDs.

New entries copy `#hp` to `stats.health`, `#att` to `stats.attack`, `#def` to
`stats.defense`, `#str` to `stats.strength`, `#mapmove` to `stats.speed`, `#ap`
to `stats.battle_speed`, and `#size` to `size`. All values are unscaled;
movement/action scales and overall balance may differ between games.

All 42 source PNGs are preserved under `src/assets/sprites/units/pelasgians/`.
New units use their `#spr1` idle image. Attack and rider-on-foot images are
retained as assets; animation and dismounting are not implemented here.

Numeric source weapon/armor IDs are not Geherra item IDs. New entries generally
have empty equipment and inherit the basic attack; `pelas_slinger` is equipped
with Geherra's sling item and uses its sling-stone attack. No source equipment,
magic, leadership, morale, precision, protection, costs, age, terrain abilities,
transformation/upgrade rules, mount behavior, or special abilities are inferred.
The wolf and pony likewise use the default unit behavior and slots.

The existing troop loader already registers this file. This import does not
change encounter, recruitment, faction, or progression tables.
