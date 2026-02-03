# BATTLE_AI.md

This document defines **battle AI** behavior and extensibility.

---

## 1. Default Targeting

* AI targets the **nearest reachable unit** in action range
* If no valid target, AI moves toward nearest enemy

---

## 2. Extensible Targeting

AI target selection is designed to be overridden by **directives**.

Examples (future):

* "Target enemy archers"
* "Focus cavalry"
* "Protect commander"

---

## 3. Action Selection

* AI evaluates available actions
* Prefers actions that can hit a valid target

