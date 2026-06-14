# E3 — Needs Simulation

**Goal:** Citizens' hunger, sleep, and social stats tick and decay in real-time.  
**Owner:** Dev (JcTheKing)  
**Depends on:** E1 (citizens on disk), E1.4 (save_citizen works)  
**Status:** Blocked on E1

---

## Tasks

### T3.1 — Tune and uncomment tick_needs()
- Uncomment the three decay lines in `simulation.odin:29`
- Tune rates: hunger +2/tick, sleep -1/tick, social -0.5/tick (adjust from playtesting)
- Add clamping: `min(..., 100)` / `max(..., 0)`
- **File:** `engine/simulation.odin`

### T3.2 — Auto-save citizens on needs change
- After `tick_needs()`, call `save_citizen()` for every citizen whose stats changed
- This writes updated stats back to disk — The Eye then picks up the `.Modified` event
- Gate save behind a "dirty" flag to avoid writing every tick if nothing changed

### T3.3 — Critical state events
When a stat crosses a threshold, push a visible event:

| Threshold | Event Text | Kind |
|-----------|-----------|------|
| hunger >= 90 | "{name} is starving" | .Info |
| sleep <= 10 | "{name} collapsed from exhaustion" | .Info |
| social <= 10 | "{name} has become a recluse" | .Info |
| health <= 20 | "{name} is near death" | .Info |

### T3.4 — Needs affect health
- When hunger >= 80 for 3+ ticks: health -= 1/tick
- When sleep <= 20 for 3+ ticks: health -= 0.5/tick
- When health reaches 0: delete the `.citizen` file → The Eye fires `.Death`
- (This gives permadeath meaning — neglect = death)

### T3.5 — TICK_RATE tuning
- Currently hardcoded at 2.0s — make it configurable via a `world/world.cfg` file
- Key: `tick_rate = 2.0`
- Story Writer: decide the "time scale" — is 1 tick = 1 in-game hour? day?

---

## Definition of Done

- Stats visibly drain over time in the HUD stat bars
- A starving citizen eventually dies (health → 0 → file deleted → event fires)
- Stats are written to disk each tick so The Eye and external tools see live values
