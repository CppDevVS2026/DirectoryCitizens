# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Game Is

**DirectoryCitizens** is a world simulator where the Windows file system *is* the game world — no custom renderer, no game window, no graphics pipeline.

| File System Concept | Game Concept |
|---|---|
| Directory / Folder | Zone — room, building, district, city |
| `.citizen` file | Citizen — living entity with stats, traits, relationships |
| Move / Cut+Paste a file | Citizen travels between locations |
| Delete a file | Citizen dies (permadeath) |
| Edit a file's text | Directly rewrite a citizen's attributes |
| File rename | Life event — marriage, promotion, title change |

The player uses Windows Explorer as the game board. The engine runs alongside it as a **Companion HUD** — a borderless sidebar window on the right side of the screen. The engine watches the file system in real-time via `ReadDirectoryChangesW`, processes citizen AI on a tick loop, and renders live citizen data through **Dear ImGui**.

Long-term vision: Dwarf Fortress depth (emergent politics, factions, economies, histories) expressed entirely through files and folders.

```
DirectoryCitizens.exe
├── Win32 Window (WS_POPUP)    Borderless sidebar, 420px wide, full screen height, right edge
├── StartTheEye()              Background thread: ReadDirectoryChangesW event loop
│   └── Translates events      FILE_ACTION_ADDED → Spawn, RENAMED → Locomotion, REMOVED → Permadeath
├── CitizenManager             Parse/serialize .citizen files; CRUD on citizen state
└── SimulationEngine           Tick loop (background thread)
    ├── NeedsSystem            Hunger, sleep, social needs drive AI decisions
    ├── BehaviorSystem         Citizen decision-making; pathfinding = directory traversal
    └── PoliticsSystem         Factions, relationships, elections, power
```