# PRD — Directory Citizens: Vision

**Status:** Active  
**PM:** Claude (content + planning)  
**Dev:** JcTheKing  
**Last updated:** 2026-06-14

---

## Elevator Pitch

Directory Citizens is a living-city simulation where the **filesystem is the game world**.
Citizens are `.citizen` files. Zones are directories. The player watches through **The Eye** —
a surveillance and control system built by developers to observe and manage the population.

The central question: **Will the citizens realize they're just AI, programmed and controlled?**

---

## World: Root Directory

| Attribute | Value |
|-----------|-------|
| **World name** | Root Directory |
| **Era** | Unknown |
| **Geography** | A Filesystem |
| **Aesthetic** | Gray — monochrome, cold, institutional |
| **The Eye** | A control system implemented by a few developers |
| **Narrative tension** | Citizens awakening to the fact they're AI under surveillance |

---

## Core Design Pillars

| Pillar | Description |
|--------|-------------|
| **Filesystem = World** | Every game state lives on disk as human-readable files |
| **The Eye** | Read-only observer; watches, logs, never acts directly |
| **Emergent Awakening** | As needs degrade and events accumulate, citizens may become aware |
| **Permadeath** | Deleting a `.citizen` file kills that citizen permanently |
| **Gray Aesthetic** | Minimal color — citizens have muted tones, UI is cold and clinical |

---

## Win Conditions (Milestone 1 — The Eye Goes Live)

- [ ] Zones and citizens load from real `.citizen` files on disk
- [ ] The Eye's Win32 watcher detects file changes in real-time
- [ ] Game events fire when citizens are added, modified, deleted, or renamed
- [ ] Citizens' needs tick and decay over time
- [ ] The HUD reflects live disk state

---

## Music Direction (PM-generated)

- Ambient, cold, minimal — think sparse electronic tones
- Subtle drone underlayer that shifts when a death event fires
- No melody — the world is a machine; music reflects that
- One global track; intensity parameter driven by total citizen stress level
