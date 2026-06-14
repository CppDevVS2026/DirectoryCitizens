# Directory Citizens — Backlog

**PM:** Claude  
**Dev / Story / Music:** JcTheKing  
**Last updated:** 2026-06-14

---

## Active Sprint — Milestone 3: Ship

All engine systems are implemented. The project is feature-complete.

### User's personal task

| Task | Owner | Notes |
|------|-------|-------|
| Jail zone — compress integration | JcTheKing | Learning task; jail zone exists and works, compress mechanic TBD |

### Future ideas (Milestone 4+)

| Idea | Epic |
|------|------|
| Factions with named leaders and manifestos | E6 extension |
| Music files — replace procedural tones with composed tracks | E7 extension |
| Save/load game state snapshot | new |
| Win32 tray icon — The Eye as a background process | new |
| Web export (Emscripten) | new |

---

## Completed

### Core Data Loop (E1)
- [x] T1.1 — `world/` directory structure + `.citizen` files on disk
- [x] T1.2 — `scan_world()` — discovers zone directories
- [x] T1.3 — Wired into `make_game_state()`, all hardcoded data removed
- [x] T1.4 — `save_citizen()` — round-trip serialization
- [x] T1.5 — Zone color palette (name hash → ZONE_PALETTE)
- [x] T1.6 — Citizen color from name hash

### The Eye (E2)
- [x] T2.1 — `start_the_eye()` — Win32 ReadDirectoryChangesW background thread
- [x] T2.2 — `stop_the_eye()` — clean shutdown, joins thread
- [x] T2.3 — `drain_eye_events()` — Spawn/Death/StatChange/Rename/ZoneAdded/ZoneRemoved
- [x] T2.4 — EyeState wired into GameState + main loop
- [x] T2.5 — HUD: blinking dot + live citizen count

### Needs Simulation (E3)
- [x] T3.1 — `tick_needs()` — hunger/sleep/social decay each tick
- [x] T3.2 — Auto-save citizens to disk after each tick
- [x] T3.3 — Critical state events fire at thresholds (entry-only, no spam)
- [x] T3.4 — Health decay from sustained need failure; permadeath deletes file
- [x] T3.5 — `tick_rate` loaded from `world/world.cfg` at startup

### World Content (E4)
- [x] T4.1 — World lore doc (`docs/lore/world.md`)
- [x] T4.2 — 5 zones: Market District, Residential Quarter, The Keep, The Archive, The Null Quarter
- [x] T4.3 — 11 starting citizens written to disk
- [x] T4.4 — Opening event log entries (seeded in make_game_state)
- [x] T4.5 — `world/world.cfg`

### Behavior System (E5)
- [x] T5.1 — `Behavior` enum added to Citizen struct
- [x] T5.2 — `tick_behavior()` — need-driven decisions each tick
- [x] T5.3 — Position drift: citizens lerp toward target zone
- [x] T5.4 — Status flavor text table (behavior × zone, all 6 zones)

### Politics System (E6)
- [x] Unrest tracker (0–100) driven by stressed/content citizen ratio
- [x] Three threshold events: 30, 60, 90
- [x] Revolt at 100: most stressed citizen exiled to The Jail via os.rename
- [x] The Jail zone added (world/The Jail/, Rook + Slate as starting prisoners)
- [x] zone_layout and behavior_status entries for The Jail

### Audio (E7)
- [x] Procedural sine wave synthesis — no external files required
- [x] Per-EventKind sounds: Spawn (chirp), Death (descending tone), Move (blip), Rename (chime)
- [x] Unrest sound (low rumble) and Revolt sound (FM buzz)
- [x] Stress drone — continuous low-frequency audio scaled to population stress level
- [x] `update_audio()` called each frame; `play_event_sound()` called from push_event
