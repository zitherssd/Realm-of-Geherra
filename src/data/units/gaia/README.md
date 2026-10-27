# Gaia units

70 unit definitions imported from `outputs/gaia/gaia.dm` in the Kosmokrator
project on 2026-10-26. Each entry's comment records its source monster ID.
Unit IDs use `gaia_` plus the source sprite stem, so commander variants remain
distinct and existing Geherra units are preserved.

| Source directive | Geherra field | Meaning |
| --- | --- | --- |
| `#hp` | `stats.health` | Hit points |
| `#att` | `stats.attack` | Base melee attack |
| `#def` | `stats.defense` | Base melee defense |
| `#str` | `stats.strength` | Strength used in damage calculation |
| `#mapmove` | `stats.speed` | World movement |
| `#ap` | `stats.battle_speed` | Battle movement/action speed |
| `#size` | `size` | Unit size |
| `#spr1` | `sprite` | Idle image |

Values are copied literally, including zero movement or defense. These are
matching concepts, not a balance conversion: movement scales and the effect of
attack/defense can differ between games. Health and size are also unscaled.

All 142 source PNGs are copied unchanged under
`src/assets/sprites/units/gaia/`, including 70 idle/attack pairs and the banner
and flag. The current unit renderer uses one sprite; attack images are retained
as assets, not listed as random idle variants.

Categories: minotaurs, centaurs, satyrs (including sileni), giants (including
cyclopes and Earth Seer), animals, trolls, nymphs, plants, and monsters.
Definitions are registered in `src/data/troops.lua`. This adds templates; it
does not add them to encounter tables, recruitment, or faction membership.

Equipment is empty and units retain the engine's default basic attack. Source
weapon/armor numeric IDs are not Geherra item IDs and have not been guessed.
Consequently bows, natural weapons, armor, spells, and special attacks shown
in the art are not implemented by this import.

Other omitted directives include protection (`#prot`, which is not melee
defense), precision (no current precision mechanic), magic resistance, morale,
encumbrance, recruitment costs, leadership, magic paths, resistances, flight,
regeneration, stealth, and other source-specific abilities. No protections,
equipment, skills, loot, or commander attributes are inferred from them.
