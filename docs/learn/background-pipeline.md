# Background Spawning Pipeline

**Concept:** Country definitions -> Queue -> Random trigger -> Spawn zone and citizens into `world/`.

## Existing Codebase References

Before implementing, review these key procedures:

- `engine/citizen_manager.odin` - `save_citizen`: Demonstrates how a citizen is written to disk. The spawner will use this same pattern to create citizens.
- `engine/citizen_manager.odin` - `scan_zone`: Shows what the spawner must produce for the rest of the game to recognize a newly created zone.
- `engine/simulation.odin` - `exile_most_stressed`: The only place in the codebase that currently creates a file and moves it at runtime. This serves as the closest existing model for spawning entities into the world mid-game.

## Standard Library Requirements

### `core:math/rand`
Used for the random trigger and random citizen stat generation.
- `rand.int_max(n)`: Pick an index from the queue.
- `rand.float32_range(lo, hi)`: Randomize health/hunger/sleep on spawn.

### `core:os`
Used for creating new subdirectories under `world/` for new countries.
- `os.make_directory(path)`: Creates the directory. Returns an `os.Error` which must be checked before writing citizen files into it.

## Design Considerations: Country Definitions

Where do Country definitions live? The chosen approach shapes the implementation:

1. **Hardcoded Odin structs**: Simplest, requires no parsing, but adding countries requires recompilation.
2. **`.country` files on disk**: Uses the same `key=value` format as `.citizen` files, loaded at startup into a queue. More flexible and consistent with the game's data model. The Eye already watches `world/`, allowing for potential hot-reloading of country definitions later.

*Recommendation*: The `.country` file approach fits the game's pattern best, though hardcoded structs are a valid first pass.