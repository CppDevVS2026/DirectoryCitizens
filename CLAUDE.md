# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Game Is

**Files** is a world simulator where the Windows file system *is* the game world — there is no custom renderer, no game window, no graphics pipeline.

| File System Concept | Game Concept |
|---|---|
| Directory / Folder | Zone — room, building, district, city |
| `.txt` / `.dat` file | Citizen — living entity with stats, traits, relationships |
| Move / Cut+Paste a file | Citizen travels between locations |
| Delete a file | Citizen dies |
| Edit a file's text | Directly rewrite a citizen's attributes |
| File rename | Life event — marriage, promotion, title change |
| File size growing | Citizen accumulates experience and data |

The player uses Windows Explorer as the game board. The engine runs alongside it as a **Companion HUD** — a borderless sidebar window on the right side of the screen. The engine watches the file system in real-time via `ReadDirectoryChangesW`, processes citizen AI and world events on a tick loop, and renders live citizen data through **Dear ImGui**.

Long-term vision: Dwarf Fortress depth (emergent politics, factions, economies, histories) expressed entirely through files and folders.

## Companion HUD Architecture

```
┌─────────────────────────────┬──────────────────┐
│  Windows Explorer           │  DirectoryCitizens│
│  (the game board)           │  ImGui HUD        │
│                             │                   │
│  C:\FilesRPG\World\         │  Citizen: Jake    │
│  ├── Jake.citizen    ──────►│  Health: 87       │
│  ├── Mira.citizen           │  Job: Farmer      │
│  └── District-1\           │  Mood: Anxious    │
│      └── Town-Hall\         │  [relationships]  │
└─────────────────────────────┴──────────────────┘
```

```
DirectoryCitizens.exe
├── Win32 Window (WS_POPUP)    Borderless sidebar, snapped to right edge of screen
├── ImGui + DX11 backend       Renders citizen data, simulation stats, event log
├── FileSystemWatcher          ReadDirectoryChangesW → game events (background thread)
├── CitizenManager             Parse/serialize .citizen files; CRUD on citizen state
├── SimulationEngine           Tick loop (background thread)
│   ├── NeedsSystem            Hunger, sleep, social needs drive AI decisions
│   ├── BehaviorSystem         Citizen decision-making; pathfinding = directory traversal
│   ├── PoliticsSystem         Factions, relationships, elections, power
│   └── EventBus               Game events → file system writes (rename, edit, delete)
└── WorldMap                   Directory tree → simulation zone graph
```

**Do not use raw Win32 GDI/USER32 for UI.** It's Windows 95-era pain. ImGui is the correct layer for all rendering.

## Citizen File Format (Plain Text)

```
Name: Mira Voss
Age: 29
Health: 91
Job: Farmer
Mood: Content
Traits: Hardworking, Curious
Relationships: Dav Voss (Husband), Sela Orin (Friend)
Inventory: Bread x2, Coin x14
```

The engine reads and writes this format. Players can hand-edit files to directly intervene in the simulation.

## Key Win32 APIs

- `ReadDirectoryChangesW` — core file system watcher; detects player actions in real-time
- `CreateFile` / `ReadFile` / `WriteFile` — citizen I/O
- `std::thread` or `CreateThread` — simulation tick loop runs off the main thread
- `Dear ImGui` + DX11 backend — all UI rendering; never use raw GDI for this
- `Shell_NotifyIcon` — optional tray icon for when HUD is minimized
- `wWinMain` + message loop — current skeleton entry point

## Build

Requires CMake 3.20+ and MSVC (C++17).

```bash
mkdir build
cd build
cmake ..
cmake --build . --config Release
```

Output: `build/Release/DirectoryCitizens.exe`

`compile_commands.json` is generated automatically for clangd/IDE tooling.

## Conventions

- Unicode-first: `L""` wide strings, `w`-prefixed Win32 functions throughout.
- The `WIN32` flag in `add_executable` suppresses the console — keep it.
- New source files go in `src/` and must be added to `CMakeLists.txt`.
- Citizen files are always UTF-8 plain text; never use binary formats for citizen state.
