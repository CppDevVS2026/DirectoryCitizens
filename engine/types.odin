package engine

import rl "vendor:raylib"

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
	world_pos:    rl.Vector3,
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
}

make_game_state :: proc() -> GameState {
	s: GameState
	s.selected = -1

	s.camera = rl.Camera3D{
		position   = {18, 14, 18},
		target     = {0, 1, 0},
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	s.tick_rate = load_world_cfg("world/world.cfg", TICK_RATE)

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
}
