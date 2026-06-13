package main

import rl "vendor:raylib"

SCREEN_W :: 1280
SCREEN_H :: 720

// 3D viewport takes left 68%, HUD panel takes right 32%
PANEL_X :: 880
PANEL_W :: SCREEN_W - PANEL_X

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(SCREEN_W, SCREEN_H, "Directory Citizens")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	state := make_game_state()
	defer destroy_game_state(&state)

	for !rl.WindowShouldClose() {
		// Reset temp allocator each frame so fmt.ctprintf strings don't leak
		defer free_all(context.temp_allocator)

		update(&state, f64(rl.GetFrameTime()))

		rl.BeginDrawing()
		rl.ClearBackground({8, 10, 14, 255})

		draw_world(&state)
		draw_hud(&state)

		rl.EndDrawing()
	}
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

	// --- Zones (directories) ---
	append(&s.zones, Zone{
		name  = "Market District",
		path  = "World/Market",
		pos   = {-9, 0, -9},
		size  = {7, 2.5, 7},
		color = {60, 130, 210, 200},
	})
	append(&s.zones, Zone{
		name  = "Residential Quarter",
		path  = "World/Residential",
		pos   = {3, 0, -6},
		size  = {8, 2, 6},
		color = {80, 190, 80, 200},
	})
	append(&s.zones, Zone{
		name  = "The Keep",
		path  = "World/Keep",
		pos   = {-2, 0, 4},
		size  = {5, 6, 5},
		color = {190, 80, 60, 200},
	})

	// --- Citizens (.citizen files) ---
	append(&s.citizens, Citizen{
		name      = "Aldric",
		zone      = "Market District",
		status    = "Trading goods",
		health    = 85,
		hunger    = 40,
		sleep     = 70,
		social    = 60,
		color     = {255, 200, 80,  255},
		world_pos = {-7.5, 0.5, -7.5},
	})
	append(&s.citizens, Citizen{
		name      = "Seren",
		zone      = "Market District",
		status    = "Gossiping",
		health    = 92,
		hunger    = 20,
		sleep     = 90,
		social    = 80,
		color     = {100, 220, 255, 255},
		world_pos = {-5.5, 0.5, -8.5},
	})
	append(&s.citizens, Citizen{
		name      = "Mira",
		zone      = "The Keep",
		status    = "Guarding gate",
		health    = 78,
		hunger    = 60,
		sleep     = 50,
		social    = 30,
		color     = {255, 110, 180, 255},
		world_pos = {0.5,  3.0,  6.0},
	})
	append(&s.citizens, Citizen{
		name      = "Thane the Elder",
		zone      = "Residential Quarter",
		status    = "Sleeping",
		health    = 65,
		hunger    = 80,
		sleep     = 20,
		social    = 55,
		color     = {150, 255, 150, 255},
		world_pos = {5.5,  0.5, -4.5},
	})
	append(&s.citizens, Citizen{
		name      = "Lys",
		zone      = "Residential Quarter",
		status    = "Tending garden",
		health    = 90,
		hunger    = 30,
		sleep     = 85,
		social    = 70,
		color     = {255, 160, 100, 255},
		world_pos = {7.5,  0.5, -3.5},
	})
	append(&s.citizens, Citizen{
		name      = "Gareth",
		zone      = "Market District",
		status    = "At the tavern",
		health    = 72,
		hunger    = 55,
		sleep     = 40,
		social    = 95,
		color     = {200, 140, 255, 255},
		world_pos = {-8.5, 0.5, -5.5},
	})

	// --- Events (newest first) ---
	append(&s.events, GameEvent{text = "Gareth won the Market election",          kind = .Info})
	append(&s.events, GameEvent{text = "Lys moved to Residential Quarter",        kind = .Move})
	append(&s.events, GameEvent{text = "Thane renamed to Thane the Elder",        kind = .Rename})
	append(&s.events, GameEvent{text = "Old Brennan died in The Keep",            kind = .Death})
	append(&s.events, GameEvent{text = "Seren was born in Market District",       kind = .Spawn})
	append(&s.events, GameEvent{text = "Aldric arrived in Market District",       kind = .Move})
	append(&s.events, GameEvent{text = "The Keep expanded its walls",             kind = .Info})
	append(&s.events, GameEvent{text = "Mira promoted to Gate Warden",           kind = .Rename})

	return s
}

destroy_game_state :: proc(s: ^GameState) {
	delete(s.citizens)
	delete(s.zones)
	delete(s.events)
}

update :: proc(s: ^GameState, dt: f64) {
	s.tick += dt

	// Only orbit the camera when the mouse is over the 3D viewport, not the HUD
	mouse := rl.GetMousePosition()
	if mouse.x < f32(PANEL_X) {
		rl.UpdateCamera(&s.camera, .ORBITAL)

		// Click in viewport to pick a citizen by proximity in screen space
		if rl.IsMouseButtonPressed(.LEFT) {
			ray := rl.GetScreenToWorldRay(mouse, s.camera)
			best_dist := f32(999)
			best_i := i32(-1)
			for &c, i in s.citizens {
				hit := rl.GetRayCollisionSphere(ray, c.world_pos, 0.6)
				if hit.hit && hit.distance < best_dist {
					best_dist = hit.distance
					best_i = i32(i)
				}
			}
			s.selected = best_i if best_i != s.selected else -1
		}
	}
}
