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

The simulation runs as a background Win32 process. It watches the file system in real-time via `ReadDirectoryChangesW`, processes citizen AI and world events on a tick loop, and writes changes back to citizen files — all while the player browses their directories in Windows Explorer.

Long-term vision: Dwarf Fortress depth (emergent politics, factions, economies, histories) expressed entirely through files and folders.

## Architecture (Planned)

```
DirectoryCitizens.exe
├── FileSystemWatcher      ReadDirectoryChangesW → translate FS events to game events
├── WorldMap               Directory tree → simulation zone graph
├── CitizenManager         Parse/serialize citizen .txt files; CRUD on citizen state
├── SimulationEngine       Background thread tick loop
│   ├── NeedsSystem        Hunger, sleep, social needs drive AI decisions
│   ├── BehaviorSystem     Citizen decision-making; pathfinding = directory traversal
│   ├── PoliticsSystem     Factions, relationships, elections, power
│   └── EventBus           Game events → file system writes (rename, edit, delete)
└── TrayIcon               System tray presence; minimal status HUD
```

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
- `Shell_NotifyIcon` — system tray icon for background presence
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
