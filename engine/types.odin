package engine

import rl "vendor:raylib"

Citizen :: struct {
	name:      cstring,
	zone:      cstring,
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

	// Zones — TODO: replace with scan_world() once citizen_manager is ready
	append(&s.zones, Zone{
		name  = "Market District",
		path  = "world/Market District",
		pos   = {-9, 0, -9},
		size  = {7, 2.5, 7},
		color = {60, 130, 210, 200},
	})
	append(&s.zones, Zone{
		name  = "Residential Quarter",
		path  = "world/Residential Quarter",
		pos   = {3, 0, -6},
		size  = {8, 2, 6},
		color = {80, 190, 80, 200},
	})
	append(&s.zones, Zone{
		name  = "The Keep",
		path  = "world/The Keep",
		pos   = {-2, 0, 4},
		size  = {5, 6, 5},
		color = {190, 80, 60, 200},
	})

	// Citizens — TODO: replace with scan_zone() calls
	append(&s.citizens, Citizen{name="Aldric",          zone="Market District",     status="Trading goods",  health=85, hunger=40, sleep=70, social=60, color={255,200,80,255},  world_pos={-7.5,0.5,-7.5}})
	append(&s.citizens, Citizen{name="Seren",           zone="Market District",     status="Gossiping",      health=92, hunger=20, sleep=90, social=80, color={100,220,255,255}, world_pos={-5.5,0.5,-8.5}})
	append(&s.citizens, Citizen{name="Mira",            zone="The Keep",            status="Guarding gate",  health=78, hunger=60, sleep=50, social=30, color={255,110,180,255}, world_pos={0.5,3.0,6.0}})
	append(&s.citizens, Citizen{name="Thane the Elder", zone="Residential Quarter", status="Sleeping",       health=65, hunger=80, sleep=20, social=55, color={150,255,150,255}, world_pos={5.5,0.5,-4.5}})
	append(&s.citizens, Citizen{name="Lys",             zone="Residential Quarter", status="Tending garden", health=90, hunger=30, sleep=85, social=70, color={255,160,100,255}, world_pos={7.5,0.5,-3.5}})
	append(&s.citizens, Citizen{name="Gareth",          zone="Market District",     status="At the tavern",  health=72, hunger=55, sleep=40, social=95, color={200,140,255,255}, world_pos={-8.5,0.5,-5.5}})

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
