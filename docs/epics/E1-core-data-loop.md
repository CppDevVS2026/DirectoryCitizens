# E1 — Core Data Loop

**Goal:** Replace all hardcoded citizens/zones with live disk reads.  
**Owner:** Dev (JcTheKing)  
**Depends on:** nothing — this is the foundation  
**Status:** In Progress

---

## Why This First

Everything else (The Eye, needs simulation, narrative events) depends on citizens and
zones living on disk. Until E1 is done, the game is a static mockup.

---

## Tasks

### T1.1 — Create world/ directory structure on disk
- Create `world/Market District/`, `world/Residential Quarter/`, `world/The Keep/`
- Write `.citizen` files for Aldric, Seren, Mira, Thane the Elder, Lys, Gareth
  with `pos_x`, `pos_y`, `pos_z`, `health`, `hunger`, `sleep`, `social`, `status`
- **Owner:** Story Writer (you pick names, status flavor text)
- **Code:** Dev writes a small helper or does it by hand

### T1.2 — Implement `scan_world()` in citizen_manager.odin
- Opens the `world/` root directory
- For each subdirectory → create a `Zone` (name from dir name, path = dir path)
- Returns `[dynamic]Zone`
- **File:** `engine/citizen_manager.odin`

### T1.3 — Wire `scan_world()` + `scan_zone()` into `make_game_state()`
- Replace hardcoded `append(&s.zones, ...)` block with `scan_world()` call
- Replace hardcoded `append(&s.citizens, ...)` block with `scan_zone()` calls per zone
- **File:** `engine/types.odin`

### T1.4 — Implement `save_citizen()`
- Use `strings.Builder` to build `key = value` text
- Write with `os.write_entire_file()`
- Fields: name, status, health, hunger, sleep, social, pos_x, pos_y, pos_z
- **File:** `engine/citizen_manager.odin:104`

### T1.5 — Assign zone colors from a fixed palette
- Since zones are now dynamic (from disk), assign colors from a rotating palette
- Define 8 distinct colors in citizen_manager or types
- Map zone index → color

### T1.6 — Assign citizen colors procedurally
- Citizens no longer have hardcoded colors
- Hash citizen name → pick from a palette of bright saturated colors

---

## Definition of Done

- `make_game_state()` contains zero hardcoded citizens or zones
- Deleting a `.citizen` file and restarting the game removes that citizen
- Adding a new `.citizen` file and restarting shows the new citizen
- `save_citizen()` round-trips cleanly (write → read → same values)
