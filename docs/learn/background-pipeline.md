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


Everything you need is already imported in the project. No new packages.

Odin docs — pkg.odin-lang.org — look up these three packages:

core:strings — split_lines_iterator, has_prefix, index, trim_space, split
core:strconv — parse_f64, parse_int (for parsing threshold numbers from the INI)
core:os — read_entire_file (same call used in load_world_cfg)
Your own codebase refs — in order of importance:

citizen_manager.odin:368 — load_world_cfg — this IS your INI parser template, just needs section detection added
the_eye.odin:56 — EyeState — this is where rules: [dynamic]Rule goes
the_eye.odin:168 — drain_eye_events — this is where rule evaluation and dispatch goes
types.odin:51 — GameState — the data The Eye reads when evaluating conditions (citizen count, unrest, etc.)
That's the full surface area. Four files, three stdlib packages, all already in your project.