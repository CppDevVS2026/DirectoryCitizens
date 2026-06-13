package main

// SimulationEngine — runs citizen AI on a fixed tick interval.
// Called every frame from update() in main.odin.
//
// Systems (add them one at a time as you build):
//   NeedsSystem    — hunger rises, sleep falls, social changes
//   BehaviorSystem — citizens decide what to do based on their needs
//   PoliticsSystem — factions, elections, relationships

TICK_RATE :: 2.0 // seconds between simulation steps

@(private="file")
accumulator: f64

tick_simulation :: proc(s: ^GameState, dt: f64) {
	accumulator += dt
	if accumulator < TICK_RATE { return }
	accumulator -= TICK_RATE

	tick_needs(s)
	// tick_behavior(s)  // uncomment when ready
	// tick_politics(s)  // uncomment when ready
}

// tick_needs decays citizen needs each simulation step.
// TODO: fill in the actual values and effects.
tick_needs :: proc(s: ^GameState) {
	for &c in s.citizens {
		// Hunger rises over time — a citizen at 100 is starving
		// c.hunger = min(c.hunger + 2, 100)

		// Sleep falls over time — a citizen at 0 is exhausted
		// c.sleep = max(c.sleep - 1, 0)

		// Social decays when the citizen is alone
		// c.social = max(c.social - 0.5, 0)

		_ = &c // remove this line once you start filling in above
	}
}

// push_event adds a new entry to the event log and trims it to 20 lines.
push_event :: proc(s: ^GameState, text: cstring, kind: EventKind) {
	// Insert at front so newest is at the top
	inject_at(&s.events, 0, GameEvent{text = text, kind = kind})
	if len(s.events) > 20 {
		pop(&s.events)
	}
}
