# BATTLE_RENDERING.md

This document defines rendering rules for the battle scene.

---

## 1. Depth Sorting

* Units are drawn by grid **row** (lower rows drawn last)
* Units within the same row are drawn by **column** order
* This ensures units lower on the screen appear in front

---

## 1.1 Readiness Tint

* Units with cooldown **0** are drawn at **alpha 0.6**
* Units on cooldown are drawn at **alpha 1.0**

---

## 2. Sprites

* Unit sprites are defined in unit data (`sprite.image`)
* Item sprites are not drawn in battle by default

---

## 3. Animations (Planned)

* Move animations interpolate between cell centers
* Attack animations apply rotation or quick offset
* Animation timing is deterministic and tick-aligned

---

## 4. Hit Feedback

* Damaged units flash red briefly
* Damage numbers float upward and fade

