# Directory Citizens

Directory Citizens is a living-city simulation where the **filesystem is the game world**. Citizens are `.citizen`
files, and zones are directories. You observe this world through **The Eye** — a surveillance and control system.

## 👁️ Overview

The central theme explores whether the programmed AI citizens will realize they are part of a simulation under constant
surveillance.

### Core Pillars

- **Filesystem = World**: The game state is stored as human-readable files on disk.
- **The Eye**: A read-only observer that watches and logs events in real-time.
- **Permadeath**: Deleting a `.citizen` file permanently kills that citizen.
- **Gray Aesthetic**: A cold, institutional, monochrome visual style.

## 🛠️ Stack

- **Language**: [Odin](https://odin-lang.org/)
- **Graphics & Audio**: [Raylib](https://www.raylib.com/) (using `vendor:raylib`)
- **Build Tool**: Windows Batch (`build.bat`) / Odin CLI

## 📋 Requirements

- [Odin Compiler](https://odin-lang.org/news/installing-odin/) (latest release recommended)
- Windows (currently utilizes Win32 file watchers for "The Eye")

## 🚀 Getting Started

### Build

To build the project, run the provided batch script:

```batch
build.bat
```

This will generate `DirectoryCitizens.exe` with debug symbols enabled.

### Run

Execute the compiled binary:

```powershell
.\DirectoryCitizens.exe
```

## 📜 Scripts

- `build.bat`: Compiles the project using `odin build . -out:DirectoryCitizens.exe -debug`.

## 📂 Project Structure

- `engine/`: Core simulation logic, audio management, and "The Eye" (filesystem watcher).
- `gui/`: HUD and world rendering using Raylib.
- `assets/`: Sound effects (SFX) and other static resources.
- `world/`: The actual game world data. Contains directories (zones) and `.citizen` files.
- `docs/`: Extensive documentation including PRD, roadmaps, and lore.
- `tests/`: Test suite for core engine components.
- `main.odin`: Application entry point.

## 🧪 Tests

To run the test suite, use the Odin test command:

```powershell
odin test tests
```

## ⚙️ Environment Variables & Config

- **`world.cfg`**: Main configuration for the simulation (located in the world root). Contains `tick_rate` and `world_name`.
- **`.citizen` files**: Individual citizen data (name, health, hunger, sleep, social, position).
- **INI files**: `world.ini` is used in some contexts for configuration parsing (see `world_manager.odin`).

## ⚖️ License

TODO: Add license information.

---
*Developed by JcTheKing*
