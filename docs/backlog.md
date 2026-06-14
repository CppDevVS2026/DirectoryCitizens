# Directory Citizens — Backlog

**PM:** Claude  
**Dev / Story / Music:** JcTheKing  
**Last updated:** 2026-06-14

---

## Active Sprint — Milestone 2: Citizens Think and The Eye Watches

Milestone goal: The Eye is live, citizens make autonomous decisions, world reacts to real-time disk changes.

### NOW — In progress

| Task | Epic | Owner | Notes |
|------|------|-------|-------|
| Jail zone | Dev | JcTheKing | Learning task — implement using compress |

### NEXT — After jail zone

| Task | Epic | Owner | Notes |
|------|------|-------|-------|
| T3.5 — Load tick_rate from world.cfg | E3 | PM | Currently hardcoded as TICK_RATE :: 2.0 |
| T5.4 — Status flavor text for Jail zone | E5 | PM | Add Jail to behavior_status switch table |
| E6 — Politics system | E6 | TBD | Factions, elections, power |
| E7 — Music / audio reactions | E7 | TBD | Reactive ambient loops |

---

## Completed

- [x] T4.1 — World lore doc (`docs/lore/world.md`) — *Story Writer*
- [x] T4.2 — Zone definitions — 5 zones: Market District, Residential Quarter, The Keep, The Archive, The Null Quarter
- [x] T4.3 — Starting citizens — 11 citizens written to disk
- [x] T4.5 — `world/world.cfg` — tick_rate=2.0, world_name=Root Directory
- [x] T1.1 — `world/` directory structure + `.citizen` files on disk — *PM*
- [x] T1.2 — `scan_world()` implemented — *Dev*
- [x] T1.3 — Wired into `make_game_state()`, hardcoded data removed — *Dev*
- [x] T1.4 — `save_citizen()` implemented — *PM*
- [x] T1.5 — Zone color palette (name hash → ZONE_PALETTE) — *PM*
- [x] T1.6 — Citizen color from name hash — *PM*
- [x] T3.1 — `tick_needs()` active — hunger/sleep/social decay each tick — *Dev*
- [x] T3.2 — Auto-save citizens to disk after each tick — *Dev*
- [x] T3.3 — Critical state events fire at thresholds (entry-only, no spam) — *Dev + PM*
- [x] T3.4 — Health decay from sustained need failure; permadeath deletes file — *PM*
- [x] T2.1 — `start_the_eye()` Win32 watcher background thread — *PM*
- [x] T2.2 — `stop_the_eye()` — clean shutdown, joins thread — *PM*
- [x] T2.3 — `drain_eye_events()` — Spawn/Death/StatChange/Rename/ZoneAdded/ZoneRemoved — *PM*
- [x] T2.4 — EyeState wired into GameState + main loop — *PM*
- [x] T2.5 — HUD live indicator: blinking dot + citizen count — *PM*
- [x] T5.1 — `Behavior` enum added to Citizen struct — *PM*
- [x] T5.2 — `tick_behavior()` — need-driven decisions each tick — *PM*
- [x] T5.3 — Position drift: citizens lerp toward target zone — *PM*
- [x] T5.4 — Status flavor text table (behavior × zone) — *PM*
