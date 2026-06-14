package main

import rl  "vendor:raylib"
import eng "engine"
import     "gui"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(gui.SCREEN_W, gui.SCREEN_H, "Directory Citizens")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	state := eng.make_game_state()
	eng.init_audio(&state.audio)
	defer eng.destroy_game_state(&state)

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		dt := f64(rl.GetFrameTime())
		update(&state, dt)
		eng.smooth_citizens(&state, dt)

		game_tick := int(state.tick / state.tick_rate) if state.tick_rate > 0 else 0

		rl.BeginDrawing()
		rl.ClearBackground(gui.sky_color(game_tick))
		gui.Draw_World(&state)
		gui.Draw_Hud(&state)
		rl.EndDrawing()
	}
}

update :: proc(s: ^eng.GameState, dt: f64) {
	if !s.paused { s.tick += dt * f64(s.speed) }

	// Speed controls: Space=pause, 1=normal, 2=fast, 3=fastest
	if rl.IsKeyPressed(.SPACE) { s.paused = !s.paused }
	if rl.IsKeyPressed(.ONE)   { s.speed = 1.0; s.paused = false }
	if rl.IsKeyPressed(.TWO)   { s.speed = 2.0; s.paused = false }
	if rl.IsKeyPressed(.THREE) { s.speed = 4.0; s.paused = false }

	eng.drain_eye_events(&s.eye, s)
	eng.tick_simulation(s, dt)

	// Drive the stress drone from population stress level.
	stress := f32(0)
	if len(s.citizens) > 0 {
		for &c in s.citizens {
			if c.hunger >= 80 || c.sleep <= 20 { stress += 1 }
		}
		stress /= f32(len(s.citizens))
	}
	eng.update_audio(&s.audio, stress)

	// Only orbit when the mouse is over the 3D viewport
	mouse := rl.GetMousePosition()
	if mouse.x < f32(gui.PANEL_X) {
		rl.UpdateCamera(&s.camera, .ORBITAL)

		// Click in viewport → ray-cast to select a citizen
		if rl.IsMouseButtonPressed(.LEFT) {
			ray    := rl.GetScreenToWorldRay(mouse, s.camera)
			best_d := f32(999)
			best_i := i32(-1)
			for &c, i in s.citizens {
				hit := rl.GetRayCollisionSphere(ray, c.world_pos, 0.6)
				if hit.hit && hit.distance < best_d {
					best_d = hit.distance
					best_i = i32(i)
				}
			}
			s.selected = best_i if best_i != s.selected else -1
		}
	}
}
