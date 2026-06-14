package engine

/*
	simulation.odin
	===============
	Runs the citizen AI on a fixed-interval tick loop.

	Systems — built one at a time:
	  NeedsSystem    (active)  — hunger rises, sleep falls, social drifts
	  BehaviorSystem (E5)      — citizens decide what to do based on needs
	  PoliticsSystem (E6)      — unrest rises with stressed citizens; exile to The Jail
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
	if s.paused { return }
	accumulator += dt * f64(s.speed)
	if accumulator < s.tick_rate {return}
	accumulator -= s.tick_rate

	tick_needs(s)
	tick_behavior(s)
	tick_politics(s)
	tick_renewal(s)
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
	smooth_citizens — moves world_pos toward target_pos at a fixed speed each frame.
	Call this every frame (not on the tick) for buttery smooth movement.
	Speed ~1.0 units/sec feels like a brisk walk.
*/
smooth_citizens :: proc(s: ^GameState, dt: f64) {
	speed := f32(1.2)  // units per second
	for &c in s.citizens {
		dx := c.target_pos.x - c.world_pos.x
		dz := c.target_pos.z - c.world_pos.z
		dist := math.sqrt(dx*dx + dz*dz)
		if dist < 0.005 { continue }
		step := min(speed * f32(dt), dist)
		inv  := step / dist
		c.world_pos.x += dx * inv
		c.world_pos.z += dz * inv
	}
}

/*
	push_event — inserts a new entry at the top of the event log.

	Keeps the log capped at 20 entries by dropping the oldest.
	inject_at shifts everything down; pop removes the last.
*/
push_event :: proc(s: ^GameState, text: cstring, kind: EventKind) {
	inject_at(&s.events, 0, GameEvent{text = text, kind = kind, tick = s.tick})
	if len(s.events) > 20 {
		pop(&s.events)
	}
	play_event_sound(&s.audio, kind)
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

		// --- Compute destination for this tick ---
		// For wandering/idle, add a small deterministic offset so citizens
		// mill around their zone rather than all stacking at the center.
		zone_tgt := zone_center(s, target_zone)
		wander_seed := f64(i) * 2.3 + f64(int(s.tick / 8.0)) * 1.7
		wander_r    := f32(1.6)
		dest := zone_tgt
		if c.behavior == .Wandering || c.behavior == .Idle {
			dest.x += math.sin_f32(f32(wander_seed))       * wander_r
			dest.z += math.cos_f32(f32(wander_seed * 1.3)) * wander_r
		} else if c.behavior == .Socializing {
			// Nudge slightly off-center so socializing citizens cluster visibly
			dest.x += math.sin_f32(f32(i) * 1.1) * 0.6
			dest.z += math.cos_f32(f32(i) * 0.9) * 0.6
		}
		c.target_pos = dest

		// --- Zone arrival check ---
		diff := rl.Vector3{dest.x - c.world_pos.x, 0, dest.z - c.world_pos.z}
		dist := math.sqrt(diff.x*diff.x + diff.z*diff.z)
		if dist < 1.5 && target_zone != string(c.zone) {
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

// ---------------------------------------------------------------------------
// E6 — Politics System
// ---------------------------------------------------------------------------

/*
	tick_politics — tracks population-wide unrest and triggers political events.

	Unrest mechanics:
	  +1 per citizen currently in danger (hunger >= 80 or sleep <= 20)
	  -2 per citizen who is healthy and content (hunger < 60, sleep > 40)
	  Clamped to [0, 100].

	Event thresholds:
	  unrest crosses 30  → "Murmurs of discontent"
	  unrest crosses 60  → "Open protests in the streets"
	  unrest crosses 90  → "The population is on the verge of revolt"
	  unrest reaches 100 → REVOLT: the most stressed citizen is exiled to The Jail
	                        (their .citizen file is moved; The Eye picks it up live)

	After a revolt, unrest resets to 40 — the underlying grievances remain.

	The Jail acts as the pressure valve: exiled citizens continue their lives
	there, and their needs still tick. They may die in The Jail if nothing improves.
*/
tick_politics :: proc(s: ^GameState) {
	if len(s.citizens) == 0 { return }

	// Accumulate unrest delta this tick.
	delta := f32(0)
	for &c in s.citizens {
		in_danger := c.hunger >= 80 || c.sleep <= 20
		if in_danger {
			delta += 1
		} else if c.hunger < 60 && c.sleep > 40 {
			delta -= 2
		}
	}
	delta /= f32(len(s.citizens)) // normalize to per-citizen average

	prev    := s.unrest
	s.unrest = clamp(s.unrest + delta, 0, 100)

	// Fire threshold events (only on crossing, not repeatedly).
	cross :: proc(prev, next, threshold: f32) -> bool {
		return prev < threshold && next >= threshold
	}

	if cross(prev, s.unrest, 30) {
		push_event(s, "Murmurs of discontent spread through Root Directory", .Info)
		play_unrest_sound(&s.audio)
	}
	if cross(prev, s.unrest, 60) {
		push_event(s, "Open protests erupt in the streets", .Info)
		play_unrest_sound(&s.audio)
	}
	if cross(prev, s.unrest, 90) {
		push_event(s, "The population teeters on the edge of revolt", .Info)
		play_unrest_sound(&s.audio)
	}

	// Revolt: exile the most stressed citizen to The Jail.
	if s.unrest >= 100 {
		play_revolt_sound(&s.audio)
		exile_most_stressed(s)
		s.unrest = 40 // pressure drops, but grievances linger
	}
}

/*
	exile_most_stressed — moves the citizen with the highest stress_ticks
	into The Jail by renaming their .citizen file on disk.

	The Eye's RENAMED_OLD_NAME / RENAMED_NEW_NAME pair fires automatically,
	which updates the citizen's path and zone in memory.
	If The Jail directory doesn't exist yet, the exile is skipped.
*/
@(private)
exile_most_stressed :: proc(s: ^GameState) {
	// Find the most stressed citizen not already in The Jail.
	worst_i     := -1
	worst_ticks := f32(-1)
	for i in 0..<len(s.citizens) {
		c := &s.citizens[i]
		if string(c.zone) == "The Jail" { continue }
		if c.stress_ticks > worst_ticks {
			worst_ticks = c.stress_ticks
			worst_i     = i
		}
	}
	if worst_i < 0 { return }

	c        := &s.citizens[worst_i]
	old_path := string(c.path)

	// Build the new path: world/The Jail/<name>.citizen
	name     := strings.clone_to_cstring(strings.to_lower(string(c.name), context.temp_allocator), context.temp_allocator)
	new_path := fmt.tprintf("world/The Jail/%s.citizen", name)

	// os.rename moves the file. On success The Eye fires Rename events.
	rename_err := os.rename(old_path, new_path)
	if rename_err == nil {
		push_event(s, fmt.ctprintf("%s was dragged to The Jail", c.name), .Move)
	}
}

// ---------------------------------------------------------------------------
// Population renewal — prevents permanent empty-world death spiral
// ---------------------------------------------------------------------------

// Arrival names cycling through so the world has persistent named characters.
@(private)
ARRIVAL_NAMES := [16]string{
	"Wren", "Osric", "Faye", "Brom", "Cass", "Dex", "Ilen", "Rowan",
	"Tove", "Emric", "Hala", "Syon", "Nara", "Vryn", "Coda", "Ashel",
}

@(private)
renewal_tick: int

/*
	tick_renewal — when a zone falls to 0 citizens, a newcomer arrives after
	a short delay. Each zone can hold at most 4 citizens naturally; once the
	world total drops below 3, an emergency arrival fires immediately.
*/
tick_renewal :: proc(s: ^GameState) {
	renewal_tick += 1

	total := len(s.citizens)

	// Emergency: world is almost empty — spawn someone anywhere
	if total == 0 {
		spawn_arrival(s, "Market District")
		return
	}
	if total < 3 && renewal_tick % 4 == 0 {
		spawn_arrival(s, "Residential Quarter")
		return
	}

	// Zone renewal: every ~30 ticks, repopulate an empty non-Jail zone
	if renewal_tick % 30 != 0 { return }
	for &z in s.zones {
		if string(z.name) == "The Jail" { continue }
		pop := 0
		for &c in s.citizens {
			if c.zone == z.name { pop += 1 }
		}
		if pop == 0 {
			spawn_arrival(s, string(z.name))
			return  // one arrival per renewal tick
		}
	}
}

@(private)
spawn_arrival :: proc(s: ^GameState, zone_name: string) {
	// Find the zone
	zone_pos, zone_size := rl.Vector3{}, rl.Vector3{6, 2, 6}
	for &z in s.zones {
		if string(z.name) == zone_name {
			zone_pos  = z.pos
			zone_size = z.size
			break
		}
	}

	// Pick a name not already in use
	name := ""
	for n in ARRIVAL_NAMES {
		used := false
		for &c in s.citizens {
			if strings.to_lower(string(c.name), context.temp_allocator) == strings.to_lower(n, context.temp_allocator) {
				used = true; break
			}
		}
		if !used { name = n; break }
	}
	if name == "" { name = "Stranger" }

	cx := zone_pos.x + zone_size.x * 0.5
	cz := zone_pos.z + zone_size.z * 0.5

	// Write the .citizen file to disk — The Eye will pick it up and fire Spawn
	file_name := fmt.tprintf("world/%s/%s.citizen", zone_name, strings.to_lower(name, context.temp_allocator))
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	fmt.sbprintf(&b, "name   = %s\n", name)
	fmt.sbprintf(&b, "status = Arrived in %s\n", zone_name)
	fmt.sbprintf(&b, "health = 80\n")
	fmt.sbprintf(&b, "hunger = 20\n")
	fmt.sbprintf(&b, "sleep  = 70\n")
	fmt.sbprintf(&b, "social = 60\n")
	fmt.sbprintf(&b, "pos_x  = %.2f\n", cx)
	fmt.sbprintf(&b, "pos_y  = 0.00\n")
	fmt.sbprintf(&b, "pos_z  = %.2f\n", cz)
	text := strings.to_string(b)
	_ = os.write_entire_file(file_name, transmute([]u8)text)
	// The Eye's Spawn event will handle adding them to s.citizens
}
