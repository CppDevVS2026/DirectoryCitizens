Got it — a background pipeline: Country definitions → queue → random trigger → spawn zone + citizens into world/. That's a real feature with a few moving parts.

Here's what to read, ordered by when you'll need it:

First: your own codebase

These are the three procs you need to deeply understand before writing anything new:

citizen_manager.odin:420 — save_citizen: this is how a citizen gets written to disk. A spawner uses the same pattern to create citizens, not just update them.
citizen_manager.odin:269 — scan_zone: shows what the spawner must produce for the rest of the game to recognize the new zone.
simulation.odin:415 — exile_most_stressed: the only place in the codebase that creates a file and moves it at runtime. This is your closest existing model for "spawn something into the world mid-game."
Second: one Odin stdlib page you haven't touched yet

core:math/rand — pkg.odin-lang.org/core/math/rand

The random trigger and random citizen stat generation both need this. The two procs to focus on: rand.int_max(n) (pick index from queue) and rand.float32_range(lo, hi) (randomize health/hunger/sleep on spawn).

Third: one OS proc you haven't used yet

os.make_directory — documented at pkg.odin-lang.org/core/os

Creating a new country means creating a new subdirectory under world/. save_citizen handles writing the files, but the directory has to exist first. os.make_directory(path) returns an os.Error — check it before trying to write citizen files into it.

Design question before you touch code:

Where do Country definitions live? The answer shapes everything:

Hardcoded Odin structs — simplest, no parsing, but you have to recompile to add countries.
.country files on disk — same key=value format as .citizen, loaded at startup into a queue. More flexible, consistent with the rest of the game's data model.
The .country file approach fits the game's pattern — The Eye already watches world/, so you could even hot-reload country definitions later. But the hardcoded approach is a valid first pass.

What are you leaning toward?