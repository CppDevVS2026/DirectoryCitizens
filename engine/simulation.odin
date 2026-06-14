package engine

// SimulationEngine — runs citizen AI on a fixed tick interval.
//
// Systems (build one at a time):
//   NeedsSystem    — hunger rises, sleep falls, social drifts
//   BehaviorSystem — citizens decide what to do based on their needs
//   PoliticsSystem — factions, elections, power

TICK_RATE :: 2.0 // seconds between simulation steps

@(private)
accumulator: f64

tick_simulation :: proc(s: ^GameState, dt: f64) {
	accumulator += dt
	if accumulator < TICK_RATE { return }
	accumulator -= TICK_RATE

	tick_needs(s)
	// tick_behavior(s)  — E5, not yet implemented
	// tick_politics(s)  — E6, not yet implemented
}

tick_needs :: proc(s: ^GameState) {
	for &c in s.citizens {
		c.hunger = min(c.hunger + 2,   100) // starving at 100
		c.sleep  = max(c.sleep  - 1,     0) // exhausted at 0
		c.social = max(c.social - 0.5,   0) // lonely at 0

		// Write updated stats back to the .citizen file on disk.
		// c.path was set by load_citizen — it's the full path like
		// "world/Market District/aldric.citizen".
		save_citizen(c, string(c.path))
	}
}

// push_event inserts a new entry at the top of the event log.
push_event :: proc(s: ^GameState, text: cstring, kind: EventKind) {
	inject_at(&s.events, 0, GameEvent{text = text, kind = kind})
	if len(s.events) > 20 {
		pop(&s.events)
	}
}
