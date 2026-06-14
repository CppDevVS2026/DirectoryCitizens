# E4 — World Content

**Goal:** A hand-crafted starting world with rich citizens, zones, and opening narrative.  
**Owner:** Story Writer (JcTheKing)  
**Depends on:** E1 (disk format finalized)  
**Status:** Waiting on E1 + story decisions

---

## Deliverables

### T4.1 — World name + lore doc
Write a 1-page `docs/lore/world.md`:
- World name
- Setting (era, geography, aesthetic)
- Who is The Eye? What does the player represent?
- Central narrative tension

### T4.2 — Zone definitions (6–10 zones)
Each zone = a directory under `world/`.
For each zone, provide:
- Directory name (this IS the zone name in-game)
- Description / flavor
- Suggested position in 3D space (x, z offset from origin — PM will assign)
- Suggested color theme

**Starter zones already in code:**
- `world/Market District` (commerce, gossip)
- `world/Residential Quarter` (homes, gardens)
- `world/The Keep` (military, power)

**Suggested additions (story writer decides):**
- Temple / church district
- Port / docks
- Slums / outskirts
- Scholar's Quarter / library
- The Undercroft (secret zone?)

### T4.3 — Starting citizens (10–15 citizens)
For each citizen, provide a `.citizen` file or a table with:
- `name` — full name
- `status` — their current activity (flavor text)
- `health`, `hunger`, `sleep`, `social` — starting values (0–100)
- Zone they live in
- Any relationships or story notes (not in the file format, but in lore doc)

### T4.4 — Opening event log
Write 6–8 historical events that pre-populate the event log on first launch.
These tell the player what happened before they started watching.

### T4.5 — `world/world.cfg`
Decide values for:
```
tick_rate    = 2.0    # seconds per simulation step
world_name   = ???    # displayed in HUD header
time_scale   = ???    # "1 tick = 1 hour" etc.
```

---

## Notes for Story Writer

The status field is what shows in the HUD under the citizen's name.
Make it vivid — this is the first thing the player reads about each person.

Examples of good status text:
- "Arguing with the fishmonger"
- "Sleeping off last night's wine"
- "Writing letters no one will answer"
- "Sharpening her blade, alone"
