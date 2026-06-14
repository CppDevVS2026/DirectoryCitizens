# Directory Citizens — Backlog

**PM:** Claude  
**Dev / Story / Music:** JcTheKing  
**Last updated:** 2026-06-14

---

## Active Sprint — Milestone 1: The Eye Goes Live

Milestone goal: Citizens live on disk, The Eye watches, needs tick in real-time.

### NOW — Unblocked, start here

| Task | Epic | Owner | Notes |
|------|------|-------|-------|
| T4.1 — World name + lore doc | E4 | Story Writer | Unblocks everything narrative |
| T4.2 — Zone definitions | E4 | Story Writer | Need names before T1.2 |
| T4.3 — Starting citizens | E4 | Story Writer | Need `.citizen` content before T1.1 |
| T1.1 — Create world/ directory + .citizen files | E1 | Dev + Story | Story writer provides content; dev creates files |

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

*(nothing yet — first sprint just kicked off)*
