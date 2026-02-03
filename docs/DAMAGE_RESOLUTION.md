# DAMAGE_RESOLUTION.md

This document defines **hit chance** and **damage** formulas for battle resolution.

All formulas are implemented in: /battle/battle_rules.lua

---

## 1. Hit Chance

Inputs:

* Attacker `attack`
* Defender `defense`

Rules:

* If defender defense is 0 → hit chance = 95%
* Otherwise:

$$
ratio = \frac{attack}{defense}
$$

$$
chance\% = 50 + (ratio - 1) \times 35
$$

* Clamp to **[5%, 95%]**

---

## 2. Damage

Inputs:

* Attacker `strength`
* Defender `protection`
* Action `damage_bonus` (optional)

Rules:

Define effective strength:

$$
effective\_strength = strength + damage\_bonus
$$

Then:

$$
multiplier = \frac{effective\_strength}{effective\_strength - protection}
$$

$$
base\_damage = effective\_strength \times multiplier
$$

* Apply variance of **±20%**
* Round to nearest integer
* Clamp to minimum of **1**

---

## 3. Determinism Notes

* Variance uses the battle RNG
* Formulas are deterministic given a fixed seed
