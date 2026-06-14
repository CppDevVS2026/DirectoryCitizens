package engine

/*
	simulation.odin
	===============
	Runs the citizen AI on a fixed-interval tick loop.

	Systems — built one at a time:
	  NeedsSystem    (active)  — hunger rises, sleep falls, social drifts
	  BehaviorSystem (E5)      — citizens decide what to do based on needs
	  PoliticsSystem (E6)      — factions, elections, power

	Tick loop:
	  tick_simulation() is called every frame with the frame delta time (dt).
	  It accumulates time and only fires the simulation step every TICK_RATE
	  seconds, so game speed is independent of frame rate.
*/

import "core:fmt"
import "core:os"

// How many real seconds between simulation steps.
TICK_RATE :: 2.0

@(private)
accumulator: f64

tick_simulation :: proc(s: ^GameState, dt: f64) {
	accumulator += dt
	if accumulator < TICK_RATE {return}
	accumulator -= TICK_RATE

	tick_needs(s)
	// tick_behavior(s)  — E5, not yet implemented
	// tick_politics(s)  — E6, not yet implemented
}

/*
	tick_needs — decays citizen needs and applies health consequences.

	Called once per simulation tick (every TICK_RATE seconds).

	Decay rates (per tick):
	  hunger  +2   (100 = starving)
	  sleep   -1   (0   = exhausted)
	  social  -0.5 (0   = isolated)

	Health damage:
	  After 3 consecutive ticks with hunger >= 80 OR sleep <= 20,
	  health starts falling. A citizen at health 0 dies — their .citizen
	  file is deleted from disk and they're removed from the citizens array.

	Event spam prevention:
	  Critical events (.Info) only fire when a citizen ENTERS a danger zone,
	  not every tick they're in it. We track this with the stress_ticks field:
	    stress_ticks == 1  →  just crossed the threshold  →  fire event
	    stress_ticks  > 1  →  already in danger           →  stay quiet

	Iteration:
	  We iterate backwards by index so we can safely remove dead citizens
	  from the dynamic array mid-loop without skipping entries.
*/
tick_needs :: proc(s: ^GameState) {
	// Iterate backwards so ordered_remove doesn't skip anyone
	for i := len(s.citizens) - 1; i >= 0; i -= 1 {
		c := &s.citizens[i]

		// --- Needs decay ---
		c.hunger = min(c.hunger + 2,   100)
		c.sleep  = max(c.sleep  - 1,     0)
		c.social = max(c.social - 0.5,   0)

		// --- Stress accumulation ---
		// stress_ticks counts consecutive ticks where needs are critical.
		// Reset to 0 the moment the citizen recovers.
		in_danger := c.hunger >= 80 || c.sleep <= 20
		if in_danger {
			c.stress_ticks += 1
		} else {
			c.stress_ticks = 0
		}

		// --- Threshold events (fire only on entry, not every tick) ---
		// stress_ticks == 1 means this is the first tick crossing the line.
		if c.stress_ticks == 1 {
			if c.hunger >= 90 { push_event(s, fmt.ctprintf("%s is starving",              c.name), .Info) }
			if c.sleep  <= 10 { push_event(s, fmt.ctprintf("%s collapsed from exhaustion", c.name), .Info) }
			if c.social <= 10 { push_event(s, fmt.ctprintf("%s has become a recluse",      c.name), .Info) }
		}
		if c.health <= 20 && c.health > 0 && c.stress_ticks == 1 {
			push_event(s, fmt.ctprintf("%s is near death", c.name), .Info)
		}

		// --- Health damage (kicks in after 3 sustained danger ticks) ---
		if c.stress_ticks >= 3 {
			if c.hunger >= 80 { c.health -= 1   }
			if c.sleep  <= 20 { c.health -= 0.5 }
			c.health = max(c.health, 0)
		}

		// --- Permadeath ---
		// health == 0: delete the .citizen file from disk, log the death,
		// and remove the citizen from the in-memory array.
		// We remove BEFORE saving so we don't re-create a just-deleted file.
		if c.health <= 0 {
			os.remove(string(c.path))
			push_event(s, fmt.ctprintf("%s has died", c.name), .Death)
			ordered_remove(&s.citizens, i) // safe because we're iterating backwards
			continue
		}

		// --- Persist to disk ---
		// Write updated stats back so The Eye and external tools see live values.
		save_citizen(c^, string(c.path))
	}
}

/*
	push_event — inserts a new entry at the top of the event log.

	Keeps the log capped at 20 entries by dropping the oldest.
	inject_at shifts everything down; pop removes the last.
*/
push_event :: proc(s: ^GameState, text: cstring, kind: EventKind) {
	inject_at(&s.events, 0, GameEvent{text = text, kind = kind})
	if len(s.events) > 20 {
		pop(&s.events)
	}
}
