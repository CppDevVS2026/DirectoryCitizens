package engine

import rl "vendor:raylib"

Citizen :: struct {
	name:      cstring,
	zone:      cstring,
	path:      cstring,      // full path to the .citizen file on disk, e.g. "world/Market District/aldric.citizen"
	status:    cstring,
	health:    f32,
	hunger:    f32,
	sleep:     f32,
	social:    f32,
	color:     rl.Color,
	world_pos: rl.Vector3,
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

	s.zones = scan_world("./world")
	for &z in s.zones {
		citizens := scan_zone(string(z.path), string(z.name))
		for c in citizens { append(&s.citizens, c) }
		delete(citizens)
	}
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
	delete(s.citizens)
	delete(s.zones)
	delete(s.events)
}
