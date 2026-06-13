package main

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
