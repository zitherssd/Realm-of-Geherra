# Damage Calculation System

> **Status**: In Design
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Preparation Over Reflexes, Meaningful Progression

## Overview

The Damage Calculation System resolves every combat interaction: determining whether an attack hits, how much damage it deals, and how protections and tags modify the outcome. It reads attacker offence, defender defence, weapon properties, armour protections, creature tags, and size.

## Detailed Design

### Core Rules

1. **Hit determination** (checked every time a unit attacks):
   ```lua
   hit_chance = attacker.offence / (attacker.offence + defender.defence)
   ```
   Compare against a random roll 0–1. If roll < hit_chance, the attack hits.

2. **Ranged hit chance (Size modifier)**:
   ```lua
   ranged_hit_chance = hit_chance * (1.0 + (target.size - 3) * 0.1)
   ```
   Larger targets are easier to hit at range. A dragon (size 6) takes +30% ranged hit chance. A pixie (size 1) takes -20%.

3. **Damage calculation** (on successful hit):
   ```lua
   raw_damage = weapon_base_damage + (attacker.offence / 5)
   ```

4. **Protection application** (flat subtraction):
   ```lua
   protected_damage = max(1, raw_damage - defender.protection[damage_type])
   ```
   Every hit deals at least 1 damage.

5. **Tag modifiers** (applied after protection):
   - `Ethereal`: 75% chance to ignore non-magical attacks entirely (checked before step 1)
   - `Fire Resistance`: 50% fire damage reduction (halves fire damage after protection)
   - `Armoured`: +5 flat damage reduction vs sharp and pierce (applied alongside protection)

6. **Weakness**: Negative protection values increase damage. A skeleton with `blunt = -3` takes +3 blunt damage.

### Complete Resolution Flow

```
1. Check tags (Ethereal → 75% miss vs non-magical)
2. Roll hit chance (Offence vs Defence)
3. If miss: no damage, end
4. If hit: calculate raw_damage = weapon_base + (offence / 5)
5. Apply protection: final = max(1, raw_damage - protection[type])
6. Apply tag modifiers (elemental resistance, etc.)
7. Apply final damage to target HP
```

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| S10 Character Stats | Consumes | Offence, Defence, Size |
| S13 Equipment System | Consumes | Weapon base damage, armour protection |
| S21 Health & Status | Provides | Final damage applied to HP |
| S22 Equipment Effects | Consumes | Weapon-vs-enemy type interactions |

## Formulas

**Hit chance:** `hit_chance = attacker.offence / (attacker.offence + defender.defence)`

**Damage:** `final_damage = max(1, weapon_base + (attacker.offence / 5) - defender.protection[type])`

**Example 1:** Dragon (Offence 30) clawing peasant (Defence 4, no protection):
- Hit: `30/34 = 88%`
- Damage: `15 + 30/5 - 0 = 21`
- Peasant has 12 HP → dead in one hit

**Example 2:** Peasant with club (dmg 8) hitting skeleton (Defence 6, blunt -3):
- Hit: `4/10 = 40%`
- Damage: `8 + 4/5 - (-3) = 8 + 0 + 3 = 11`
- Skeleton has 18 HP → two hits

**Example 3:** Soldier with bronze sword (dmg 12) hitting troll (Defence 10, slash prot 2):
- Hit: `14/24 = 58%`
- Damage: `12 + 14/5 - 2 = 12 + 2 - 2 = 12`
- Troll has 60 HP → five hits. Better bring a blunt weapon.

## Edge Cases

- **If hit chance exceeds 100%**: Clamped to 95%. There's always a chance to miss.
- **If hit chance is below 5%**: Clamped to 5%. There's always a chance to hit.
- **If damage is below 1 after protection**: Clamped to 1. Every hit deals at least 1 damage.
- **If both attacker and defender have 0 offence/defence**: Hit chance is 50% (0/0 treated as equal).

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| S10 Character Stats | Hard | Offence, Defence, Size |
| S13 Equipment System | Hard | Weapon base damage, armour protection |
| S22 Equipment Effects | Soft | Weapon-vs-enemy interaction rules |
| S21 Health & Status | Hard | HP to apply damage to |
