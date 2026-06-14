# PRD — Directory Citizens: Vision

**Status:** Active  
**PM:** Claude  
**Dev / Story / Music:** JcTheKing  
**Last updated:** 2026-06-14

---

## Elevator Pitch

Directory Citizens is a living-city simulation RPG where the **filesystem is the game world**.
Citizens are `.citizen` files. Zones are directories. Moving a file is emigration.
Deleting a file is death. Renaming a file is a life event.

The player watches through **The Eye** — an orbital 3D camera + HUD —
and interacts by editing files, not clicking menus.

---

## Core Design Pillars

| Pillar | Description |
|--------|-------------|
| **Filesystem = World** | Every game state lives on disk as human-readable files |
| **The Eye** | Read-only observer; The Eye watches, never acts directly |
| **Emergent Narrative** | Events arise from file system changes, not scripted sequences |
| **Permadeath** | Deleting a `.citizen` file kills that citizen — permanently |
| **Composability** | Players / tools / scripts can manipulate the world externally |

---

## Win Conditions (Milestone 1 — The Eye Goes Live)

- [ ] Zones and citizens load from real `.citizen` files on disk (no hardcoded data)
- [ ] The Eye's Win32 watcher detects file changes in real-time
- [ ] Game events fire when citizens are added, modified, deleted, or renamed
- [ ] Citizens' needs (hunger, sleep, social) tick and decay over time
- [ ] The HUD reflects live disk state

---

## Story Context *(Story Writer: fill this in)*

> **Needed from you:**
> - What is this world called?
> - What era / aesthetic? (medieval, dieselpunk, near-future city, etc.)
> - Who is The Eye? Is the player a god, a bureaucrat, a surveillance system?
> - What is the narrative tension? (survival, politics, plague, resource war?)
> - Starting cast of citizens and zones for the "world/" directory

---

## Music Direction *(Composer: fill this in)*

> **Needed from you:**
> - Overall sonic palette (ambient, orchestral, lo-fi electronic?)
> - Does music react to game events? (death → minor key, celebration → upbeat)
> - Loop points — one track per zone, or one global track?

---

## Out of Scope (for now)

- Multiplayer / shared filesystem
- Save states (disk IS the save state)
- Combat
- Procedural map generation
