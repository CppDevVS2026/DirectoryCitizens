package engine

import rl "vendor:raylib"

// 72 sim-ticks per season (= 3 in-game days). Four seasons per year.
Season :: enum u8 { Spring, Summer, Autumn, Winter }

season_name :: proc(s: Season) -> cstring {
	switch s {
	case .Spring: return "SPRING"
	case .Summer: return "SUMMER"
	case .Autumn: return "AUTUMN"
	case .Winter: return "WINTER"
	}
	return "SPRING"
}

season_from_tick :: proc(sim_tick: int) -> Season {
	return Season((sim_tick / 72) % 4)
}

// What a citizen is currently doing — drives status text and position drift.
Behavior :: enum u8 {
	Idle,        // default — no pressing need
	Eating,      // hunger >= 70, heading toward Market District
	Sleeping,    // sleep <= 30, resting in place
	Socializing, // social <= 30, seeking other citizens
	Working,     // well-fed and rested — productive
	Wandering,   // low-priority drifting
}

Citizen :: struct {
	name:         cstring,
	zone:         cstring,
	path:         cstring,      // full path to the .citizen file on disk, e.g. "world/Market District/aldric.citizen"
	status:       cstring,
	health:       f32,
	hunger:       f32,
	sleep:        f32,
	social:       f32,
	stress_ticks: f32,
	behavior:     Behavior,     // current activity (runtime-only, not saved to disk)
	color:        rl.Color,
	world_pos:    rl.Vector3,   // current rendered position (lerped toward target_pos each frame)
	target_pos:   rl.Vector3,   // destination set by behavior system each tick
}

Zone :: struct {
	name:  cstring,
	path:  cstring,
	pos:   rl.Vector3,
	size:  rl.Vector3,
	color: rl.Color,
}

EventKind :: enum u8 {
	Spawn,
	Death,
	Move,
	Rename,
	Info,
}

GameEvent :: struct {
	text: cstring,
	kind: EventKind,
	tick: f64,      // s.tick at the moment the event fired (for timestamp display)
}

DeathMarker :: struct {
	pos: rl.Vector3,
	age: f32,   // seconds; markers fade and vanish at 30s
}

GameState :: struct {
	camera:         rl.Camera3D,
	citizens:       [dynamic]Citizen,
	zones:          [dynamic]Zone,
	events:         [dynamic]GameEvent,
	eye:            EyeState,   // live filesystem watcher (The Eye)
	audio:          AudioState, // procedural reactive audio (E7)
	tick_rate:      f64,        // seconds per simulation step, loaded from world.cfg
	unrest:         f32,        // 0–100: rising political tension (E6)
	selected:       i32,
	citizen_scroll: i32,
	tick:           f64,
	world_name:     cstring,    // from world.cfg world_name field
	last_season:    int,        // 0-3; used to detect season transitions
	pop_history:    [48]int,    // circular buffer of population snapshots (every 5 ticks)
	pop_hist_idx:   int,
	pop_hist_full:  bool,       // true once all 48 slots have been written
	paused:         bool,
	speed:          f32,        // 1.0 = normal, 2.0 = fast, 4.0 = fastest
	follow_sel:     bool,       // camera tracks selected citizen when true
	total_deaths:   int,
	max_pop_seen:   int,
	death_markers:  [dynamic]DeathMarker,
}

make_game_state :: proc() -> GameState {
	s: GameState
	s.selected = -1

	s.camera = rl.Camera3D{
		position   = {12, 8, 12},
		target     = {0, 0.5, 0},
		up         = {0, 1, 0},
		fovy       = 50,
		projection = .PERSPECTIVE,
	}

	cfg         := load_world_cfg("world/world.cfg", TICK_RATE)
	s.tick_rate  = cfg.tick_rate
	s.world_name = cfg.world_name
	s.speed      = 1.0

	s.zones = scan_world("world")
	for &z in s.zones {
		citizens := scan_zone(string(z.path), string(z.name))
		for c in citizens { append(&s.citizens, c) }
		delete(citizens)
	}

	start_the_eye(&s.eye, "world")
	// Note: init_audio is called from main after InitAudioDevice.

	// Events (newest first)
	append(&s.events, GameEvent{text="Gareth won the Market election",    kind=.Info})
	append(&s.events, GameEvent{text="Lys moved to Residential Quarter",  kind=.Move})
	append(&s.events, GameEvent{text="Thane renamed to Thane the Elder",  kind=.Rename})
	append(&s.events, GameEvent{text="Old Brennan died in The Keep",      kind=.Death})
	append(&s.events, GameEvent{text="Seren was born in Market District", kind=.Spawn})
	append(&s.events, GameEvent{text="Aldric arrived in Market District", kind=.Move})

	return s
}

destroy_game_state :: proc(s: ^GameState) {
	shutdown_audio(&s.audio)
	stop_the_eye(&s.eye)
	delete(s.citizens)
	delete(s.zones)
	delete(s.events)
	delete(s.death_markers)
}
