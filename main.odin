package main

import rl  "vendor:raylib"
import eng "engine"
import     "gui"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(gui.SCREEN_W, gui.SCREEN_H, "Directory Citizens")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	state := eng.make_game_state()
	defer eng.destroy_game_state(&state)

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		update(&state, f64(rl.GetFrameTime()))

		rl.BeginDrawing()
		rl.ClearBackground({8, 10, 14, 255})
		gui.Draw_World(&state)
		gui.Draw_Hud(&state)
		rl.EndDrawing()
	}
}

update :: proc(s: ^eng.GameState, dt: f64) {
	s.tick += dt

	eng.tick_simulation(s, dt)

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
