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

## Companion HUD Architecture

```
┌─────────────────────────────┬──────────────────┐
│  Windows Explorer           │  DirectoryCitizens│
│  (the game board)           │  ImGui HUD        │
│                             │                   │
│  C:\FilesRPG\World\         │  Citizen: Jake    │
│  ├── Jake.citizen    ──────►│  Health: 87       │
│  ├── Mira.citizen           │  Job: Farmer      │
│  └── District-1\            │  Mood: Anxious    │
│      └── Town-Hall\         │  [relationships]  │
└─────────────────────────────┴──────────────────┘
```

```
DirectoryCitizens.exe
├── Win32 Window (WS_POPUP)    Borderless sidebar, 420px wide, full screen height, right edge
├── ImGui + DX11 backend       All rendering — never use raw GDI/USER32 for UI
├── StartTheEye()              Background thread: ReadDirectoryChangesW event loop
│   └── Translates events      FILE_ACTION_ADDED → Spawn, RENAMED → Locomotion, REMOVED → Permadeath
├── CitizenManager             Parse/serialize .citizen files; CRUD on citizen state
└── SimulationEngine           Tick loop (background thread)
    ├── NeedsSystem            Hunger, sleep, social needs drive AI decisions
    ├── BehaviorSystem         Citizen decision-making; pathfinding = directory traversal
    └── PoliticsSystem         Factions, relationships, elections, power
```

## Hard Architectural Rules

**These are non-negotiable. Do not suggest code that violates them.**

### Rule A — PMR Arenas Only

The engine runs continuously; standard heap allocations cause fragmentation over time. All dynamic container allocations must go through `std::pmr::monotonic_buffer_resource` backed by a static stack buffer:

```cpp
std::byte buffer[8192];
std::pmr::monotonic_buffer_resource arena(buffer, sizeof(buffer));
std::pmr::vector<Citizen> citizens(&arena);
std::pmr::string name(&arena);
```

- **Forbidden:** `std::vector`, `std::string`, `new`, `std::make_unique` for game-state containers
- **Required:** `std::pmr::vector`, `std::pmr::string` with an explicit arena allocator

### Rule B — Dual-Thread Engine

Two threads, strict separation of concerns:

| Thread | Role | Rule |
|---|---|---|
| **Thread A — Main UI Thread** | Runs the Dear ImGui render loop; reads PMR arena to draw stats | Never sleeps; never calls blocking Win32 I/O |
| **Thread B — The Eye** (`StartTheEye`) | `while(true)` `ReadDirectoryChangesW` loop; translates file events to game mechanics; writes PMR arena | Never touches ImGui |

Shared state between threads must be protected by `std::atomic` or a mutex. The `g_running` atomic flag gates the Eye thread's loop; set it false on `WM_DESTROY`.

### Rule C — No UWP / COM / C++/WinRT

Pure Win32 (`<windows.h>`) only. No COM shell extensions, no WinRT, no UWP APIs, no `#include <winrt/...>`.

## Citizen File Format (Plain Text, UTF-8)

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

Players can hand-edit `.citizen` files to directly intervene in the simulation. Never use binary formats for citizen state.

## Key Win32 APIs

- `ReadDirectoryChangesW` — core input system; detects all player actions in real-time
- `CreateFile` / `ReadFile` / `WriteFile` / `CloseHandle` — citizen I/O
- `GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN)` — monitor resolution for HUD positioning
- `Shell_NotifyIcon` — tray icon (game runs in background; tray icon is its only visible presence)
- `wWinMain` + `GetMessage` loop — entry point; `WIN32` subsystem flag suppresses console

## Build

Requires CMake 3.20+ and MSVC or GCC/MinGW (C++26 / `-std=gnu++26`).

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
- Window style is `WS_POPUP` (borderless). Width = 420px, x = `SM_CXSCREEN - 420`, y = 0, height = `SM_CYSCREEN`.
- ImGui background color is set via `ImGui::GetStyle().Colors[ImGuiCol_WindowBg]` — not via GDI brush.
