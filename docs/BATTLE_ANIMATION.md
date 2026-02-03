# BATTLE_ANIMATION.md

This document outlines **battle animation rules**.

---

## 1. Movement Animations

* Units move between cell centers
* Interpolate over a short duration (tick-aligned)

---

## 2. Attack Animations

* Brief sprite rotation or offset on execute
* No complex timelines initially

---

## 3. Determinism

* Animations use tick timestamps for consistency

