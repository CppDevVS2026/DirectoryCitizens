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
import "core:math"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

// How many real seconds between simulation steps.
TICK_RATE :: 2.0

@(private)
accumulator: f64

tick_simulation :: proc(s: ^GameState, dt: f64) {
	accumulator += dt
	if accumulator < s.tick_rate {return}
	accumulator -= s.tick_rate

	tick_needs(s)
	tick_behavior(s)
	tick_politics(s)
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

// ---------------------------------------------------------------------------
// E5 — Behavior System
// ---------------------------------------------------------------------------

/*
	tick_behavior — need-driven decisions for each citizen.

	Priority order (highest urgency wins):
	  1. hunger >= 70  → .Eating      — head to Market District
	  2. sleep  <= 30  → .Sleeping    — rest in current zone
	  3. social <= 30  → .Socializing — drift toward nearest citizen
	  4. health < 50   → .Working     — productive recovery behavior
	  5. otherwise     → .Idle / .Wandering

	Behavior changes update the citizen's status string and (for zone changes)
	trigger a gradual world_pos lerp toward the target zone center.
	Once the citizen arrives (within 1.5 units), their zone field is updated and
	the file is re-saved so The Eye picks up the change.

	Position drift:
	  We move 0.6 units per tick toward the target. With TICK_RATE=2.0 a citizen
	  crosses ~10 units in about 33 seconds — visible but not instant.
*/
tick_behavior :: proc(s: ^GameState) {
	for i in 0..<len(s.citizens) {
		c := &s.citizens[i]

		prev_behavior := c.behavior

		// --- Decide behavior based on most urgent need ---
		if c.hunger >= 70 {
			c.behavior = .Eating
		} else if c.sleep <= 30 {
			c.behavior = .Sleeping
		} else if c.social <= 30 {
			c.behavior = .Socializing
		} else if c.health < 50 {
			c.behavior = .Working
		} else {
			// Alternate between Idle and Wandering so they feel alive even when fine.
			c.behavior = .Idle if int(s.tick) % 6 < 3 else .Wandering
		}

		// --- Pick a status string and target zone based on behavior ---
		target_zone  := string(c.zone)  // default: stay in current zone
		new_status   := behavior_status(c.behavior, string(c.zone))
		c.status      = strings.clone_to_cstring(new_status, context.allocator)

		if c.behavior == .Eating {
			target_zone = "Market District"
		} else if c.behavior == .Socializing {
			target_zone = nearest_populated_zone(s, string(c.zone), i)
		}

		// --- Position drift toward target zone center ---
		target_pos := zone_center(s, target_zone)
		diff       := rl.Vector3{
			target_pos.x - c.world_pos.x,
			0,
			target_pos.z - c.world_pos.z,
		}
		dist := math.sqrt(diff.x*diff.x + diff.z*diff.z)

		if dist > 1.5 {
			// Move 0.6 units per tick toward the target.
			step := f32(0.6) / dist
			c.world_pos.x += diff.x * step
			c.world_pos.z += diff.z * step
		} else if target_zone != string(c.zone) {
			// Arrived in a new zone — update zone field.
			c.zone = strings.clone_to_cstring(target_zone, context.allocator)
			if prev_behavior != c.behavior {
				push_event(s, fmt.ctprintf("%s moved to %s", c.name, c.zone), .Move)
			}
		}

		_ = prev_behavior
	}
}

/*
	behavior_status — returns flavor text for a citizen's current behavior in their zone.

	The 2D lookup (behavior × zone) gives the world personality.
	Unknown combos fall back to generic text so new zones work automatically.
*/
@(private)
behavior_status :: proc(b: Behavior, zone: string) -> string {
	switch b {
	case .Eating:
		switch zone {
		case "Market District":     return "Buying bread at the stalls"
		case "The Keep":            return "Eating at the guard's table"
		case "The Archive":         return "Chewing on rations between scrolls"
		case "Residential Quarter": return "Cooking at home"
		case "The Jail":            return "Eating cold rations through the bars"
		}
		return "Searching for food"

	case .Sleeping:
		switch zone {
		case "Residential Quarter": return "Asleep in their home"
		case "The Keep":            return "Dozing on night watch"
		case "Market District":     return "Slumped behind a stall"
		case "The Archive":         return "Asleep over an open book"
		case "The Null Quarter":    return "Collapsed in the gray"
		case "The Jail":            return "Sleeping on a stone floor"
		}
		return "Sleeping"

	case .Socializing:
		switch zone {
		case "Market District":     return "Arguing with the fishmonger"
		case "Residential Quarter": return "Chatting with a neighbor"
		case "The Keep":            return "Gossiping with the guards"
		case "The Archive":         return "Debating with a scholar"
		case "The Null Quarter":    return "Talking to shadows"
		case "The Jail":            return "Whispering through the cell wall"
		}
		return "Looking for company"

	case .Working:
		switch zone {
		case "Market District":     return "Tending their stall"
		case "Residential Quarter": return "Repairing the roof"
		case "The Keep":            return "Sharpening weapons"
		case "The Archive":         return "Copying manuscripts"
		case "The Null Quarter":    return "Staring at the wall"
		case "The Jail":            return "Breaking rocks in the yard"
		}
		return "Working"

	case .Wandering:
		switch zone {
		case "Market District":     return "Browsing the stalls"
		case "Residential Quarter": return "Walking the alley"
		case "The Keep":            return "Pacing the battlements"
		case "The Archive":         return "Wandering the stacks"
		case "The Null Quarter":    return "Drifting"
		case "The Jail":            return "Pacing the cell"
		}
		return "Wandering"

	case .Idle:
		switch zone {
		case "Market District":     return "Standing in the crowd"
		case "Residential Quarter": return "Sitting on the doorstep"
		case "The Keep":            return "On guard duty"
		case "The Archive":         return "Reading quietly"
		case "The Null Quarter":    return "Staring into nothing"
		case "The Jail":            return "Counting the hours"
		}
		return "Idle"
	}
	return "Idle"
}

/*
	zone_center — returns the 3D center of a named zone.
	Returns the origin if the zone isn't found (fallback).
*/
@(private)
zone_center :: proc(s: ^GameState, zone_name: string) -> rl.Vector3 {
	for &z in s.zones {
		if string(z.name) == zone_name {
			return rl.Vector3{
				z.pos.x + z.size.x * 0.5,
				z.pos.y,
				z.pos.z + z.size.z * 0.5,
			}
		}
	}
	return {0, 0, 0}
}

/*
	nearest_populated_zone — finds the zone with the most citizens (excluding
	the caller's current zone) so socializing citizens drift toward the crowd.
	Returns the caller's zone if no alternatives exist.
*/
@(private)
nearest_populated_zone :: proc(s: ^GameState, current_zone: string, caller_idx: int) -> string {
	best_zone  := current_zone
	best_count := 0

	for &z in s.zones {
		zn := string(z.name)
		if zn == current_zone { continue }
		count := 0
		for ci in 0..<len(s.citizens) {
			if ci != caller_idx && string(s.citizens[ci].zone) == zn {
				count += 1
			}
		}
		if count > best_count {
			best_count = count
			best_zone  = zn
		}
	}
	return best_zone
}
