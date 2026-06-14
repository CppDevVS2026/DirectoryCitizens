# Directory Citizens — Backlog

**PM:** Claude  
**Dev / Story / Music:** JcTheKing  
**Last updated:** 2026-06-14

---

## Active Sprint — Milestone 1: The Eye Goes Live

Milestone goal: Citizens live on disk, The Eye watches, needs tick in real-time.

### NOW — Unblocked, start here (your coding tasks)

| Task | Epic | File | Notes |
|------|------|------|-------|
| T1.4 — Implement `save_citizen()` | E1 | `engine/citizen_manager.odin` | **Done by PM** — verify round-trip |
| T3.1 — Uncomment `tick_needs()` | E3 | `engine/simulation.odin` | Hunger/sleep/social decay |

### NEXT — After T1.1 complete

| Task | Epic | Owner | Notes |
|------|------|-------|-------|
| T1.2 — `scan_world()` | E1 | Dev | Opens world/ dir, creates Zones |
| T1.5 — Zone color palette | E1 | Dev | Rotating palette for dynamic zones |
| T1.6 — Citizen color from name hash | E1 | Dev | No more hardcoded colors |

### THEN — After scan_world() works

| Task | Epic | Owner | Notes |
|------|------|-------|-------|
| T1.3 — Wire scan into make_game_state() | E1 | Dev | Kills all hardcoded data |
| T1.4 — Implement save_citizen() | E1 | Dev | Required for E3 |
| T4.4 — Opening event log entries | E4 | Story Writer | Pre-populate history |

### BLOCKED — Waiting on E1

| Task | Epic | Blocked by |
|------|------|-----------|
| T2.1 — start_the_eye() Win32 | E2 | E1 done |
| T3.1 — Uncomment tick_needs() | E3 | E1 + T1.4 |
| T3.2 — Auto-save on tick | E3 | T1.4 |

### FUTURE — Milestone 2+

| Task | Epic |
|------|------|
| T2.x — Full Eye implementation | E2 |
| T3.x — Critical state events, health decay | E3 |
| T5.x — Behavior system | E5 |
| E6 — Politics system | TBD |
| E7 — Music / audio reactions | TBD |

---

## Open Questions (need answers before proceeding)

1. **Story Writer:** What is this world called? What's the aesthetic?
2. **Story Writer:** Who/what is The Eye from a lore perspective?
3. **Story Writer:** Starting 10–15 citizens with status text?
4. **Composer:** What's the music direction? Reactive or ambient loops?
5. **Dev:** Is Win32-only OK, or should The Eye support Linux/Mac later?

---

## Completed

- [x] T4.1 — World lore doc (`docs/lore/world.md`) — *Story Writer*
- [x] T4.2 — Zone definitions — 5 zones created: Market District, Residential Quarter, The Keep, The Archive, The Null Quarter
- [x] T4.3 — Starting citizens — 11 citizens written to disk
- [x] T4.5 — `world/world.cfg` — tick_rate=2.0, world_name=Root Directory
- [x] T1.1 — `world/` directory structure + `.citizen` files created on disk — *PM*
- [x] T1.2 — `scan_world()` implemented — *Dev*
- [x] T1.3 — Wired into `make_game_state()`, hardcoded data removed — *Dev*
- [x] T1.4 — `save_citizen()` implemented — *PM*
- [x] T1.5 — Zone color palette (name hash → ZONE_PALETTE) — *PM*
- [x] T1.6 — Citizen color from name hash — *PM*
- [x] T3.1 — `tick_needs()` active — hunger/sleep/social decay each tick — *Dev*
- [x] T3.2 — Auto-save citizens to disk after each tick — *Dev*
- [x] T3.3 — Critical state events fire at thresholds (entry-only, no spam) — *Dev + PM*
- [x] T3.4 — Health decay from sustained need failure; permadeath deletes file — *PM*
