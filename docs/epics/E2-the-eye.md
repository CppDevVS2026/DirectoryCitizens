# E2 — The Eye (Live Filesystem Watcher)

**Goal:** The Eye detects file changes in real-time and fires game events without restarting.  
**Owner:** Dev (JcTheKing)  
**Depends on:** E1 complete (citizens live on disk)  
**Status:** Blocked on E1

---

## Why This Matters

This is the core magic of Directory Citizens. Without The Eye, the player has to restart
to see changes. With it, editing a file = the citizen reacts *right now*.

---

## Tasks

### T2.1 — Implement `start_the_eye()` (Win32)
- Import `core:sys/windows`
- `CreateFileW` on the `world/` path with `FILE_LIST_DIRECTORY` access
- Spawn background thread that loops `ReadDirectoryChangesW`
- Parse `FILE_NOTIFY_INFORMATION` chain
- Post `EyeEvent` for each entry into the shared queue (mutex-protected)
- **File:** `engine/the_eye.odin`
- **Reference:** search "ReadDirectoryChangesW odin" or adapt from C examples

### T2.2 — Implement `stop_the_eye()`
- Close `eye.handle` so the blocking `ReadDirectoryChangesW` returns
- Join/free the thread
- **File:** `engine/the_eye.odin`

### T2.3 — Implement `drain_eye_events()` reactions
Wire each `EyeAction` to a game state mutation:

| EyeAction | Game Reaction |
|-----------|---------------|
| `.Spawn` | `load_citizen(path)` → append to `s.citizens` → `push_event(.Spawn)` |
| `.Death` | Remove citizen matching path → `push_event(.Death)` |
| `.StatChange` | Reload citizen from disk → update in-place → `push_event(.Info)` |
| `.Rename` | Update citizen name/path → `push_event(.Rename)` |
| `.ZoneAdded` | Add new Zone → `push_event(.Info)` |
| `.ZoneRemoved` | Remove zone + its citizens → `push_event(.Death)` per citizen |

- **File:** `engine/the_eye.odin`

### T2.4 — Wire EyeState into GameState + main loop
- Add `eye: EyeState` to `GameState` struct
- Call `start_the_eye(&s.eye, "world/")` in `make_game_state()`
- Call `stop_the_eye(&s.eye)` in `destroy_game_state()`
- Call `drain_eye_events(&s.eye, s)` once per frame in `update()`
- **Files:** `engine/types.odin`, `main.odin`

### T2.5 — HUD: show "Watching: world/" as live indicator
- Already displayed — confirm it updates with event count or pulse animation
- Add a blinking dot or frame counter to show The Eye is active

---

## Definition of Done

- Edit a `.citizen` file's `status` while the game runs → HUD updates within 1 second
- Drop a new `.citizen` file into a zone directory → citizen appears in the 3D view
- Delete a `.citizen` file → citizen disappears and a Death event logs
