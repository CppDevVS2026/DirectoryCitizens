package main

import rl  "vendor:raylib"
import eng "engine"
import     "gui"
import     "core:math"

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
	rl.SetWindowTitle(state.world_name)

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		dt := f64(rl.GetFrameTime())
		update(&state, dt)
		eng.smooth_citizens(&state, dt)
		gui.Tick_Death_Markers(&state, f32(dt))

		game_tick := int(state.tick / state.tick_rate) if state.tick_rate > 0 else 0

		rl.BeginDrawing()
		rl.ClearBackground(gui.sky_color(game_tick))
		gui.Draw_World(&state)
		gui.Draw_Night_Overlay(game_tick, gui.PANEL_X, gui.SCREEN_H)
		gui.Draw_Hud(&state)
		rl.EndDrawing()
	}
}

update :: proc(s: ^eng.GameState, dt: f64) {
	if !s.paused { s.tick += dt * f64(s.speed) }

	// Speed controls
	if rl.IsKeyPressed(.SPACE) { s.paused = !s.paused }
	if rl.IsKeyPressed(.ONE)   { s.speed = 1.0; s.paused = false }
	if rl.IsKeyPressed(.TWO)   { s.speed = 2.0; s.paused = false }
	if rl.IsKeyPressed(.THREE) { s.speed = 4.0; s.paused = false }

	// Arrow key citizen navigation
	n := i32(len(s.citizens))
	if n > 0 {
		if rl.IsKeyPressed(.UP) {
			s.selected = (s.selected - 1 + n) % n
			s.follow_sel = true
			sync_scroll(s)
		}
		if rl.IsKeyPressed(.DOWN) {
			s.selected = (s.selected + 1) % n
			s.follow_sel = true
			sync_scroll(s)
		}
	}

	// ESC deselects and drops follow
	if rl.IsKeyPressed(.ESCAPE) {
		s.selected   = -1
		s.follow_sel = false
	}

	// R = reset camera to default position
	if rl.IsKeyPressed(.R) {
		s.camera.position = {12, 8, 12}
		s.camera.target   = {0, 0.5, 0}
		s.follow_sel      = false
	}

	// F = toggle camera follow on selected citizen
	if rl.IsKeyPressed(.F) {
		s.follow_sel = s.selected >= 0 && !s.follow_sel
	}
	// Deselect drops follow
	if s.selected < 0 { s.follow_sel = false }

	// Camera follow: smoothly orbit target toward selected citizen
	if s.follow_sel && s.selected >= 0 && int(s.selected) < len(s.citizens) {
		c      := &s.citizens[s.selected]
		lerp   := f32(1 - math.exp_f64(-8 * dt))
		s.camera.target.x += (c.world_pos.x - s.camera.target.x) * lerp
		s.camera.target.z += (c.world_pos.z - s.camera.target.z) * lerp
	}

	eng.drain_eye_events(&s.eye, s)
	eng.tick_simulation(s, dt)

	stress := f32(0)
	if len(s.citizens) > 0 {
		for &c in s.citizens {
			if c.hunger >= 80 || c.sleep <= 20 { stress += 1 }
		}
		stress /= f32(len(s.citizens))
	}
	eng.update_audio(&s.audio, stress)

	mouse := rl.GetMousePosition()
	if mouse.x < f32(gui.PANEL_X) {
		rl.UpdateCamera(&s.camera, .ORBITAL)

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
			prev := s.selected
			s.selected = best_i if best_i != s.selected else -1
			if s.selected >= 0 && s.selected != prev {
				s.follow_sel = true
				sync_scroll(s)
			} else if s.selected < 0 {
				s.follow_sel = false
			}
		}
	}
}

// Keep citizen_scroll in sync so the selected item is visible in the HUD list.
sync_scroll :: proc(s: ^eng.GameState) {
	vis := i32(4)
	if s.selected < s.citizen_scroll { s.citizen_scroll = s.selected }
	if s.selected >= s.citizen_scroll + vis { s.citizen_scroll = s.selected - vis + 1 }
}
