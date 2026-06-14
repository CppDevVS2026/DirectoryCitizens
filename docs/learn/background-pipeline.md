
# First: your own codebase

## LEARN: These are the three procs you need to deeply understand before writing anything new:

- citizen_manager.odin:420 — save_citizen: this is how a citizen gets written to disk. A spawner uses the same pattern to create citizens, not just update them.
- citizen_manager.odin:269 — scan_zone: shows what the spawner must produce for the rest of the game to recognize the new zone.
- simulation.odin:415 — exile_most_stressed: the only place in the codebase that creates a file and moves it at runtime. This is your closest existing model for "spawn something into the world mid-game."