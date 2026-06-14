package gui

import rl  "vendor:raylib"
import eng "../engine"
import     "core:math"
import     "core:fmt"

Draw_World :: proc(s: ^eng.GameState) {
	rl.BeginMode3D(s.camera)

	rl.DrawGrid(40, 1)

	// -------------------------------------------------------------------------
	// Zones — filled box + wireframe + stress tint
	// -------------------------------------------------------------------------
	for &z in s.zones {
		center := zone_center(z)

		// Count stressed citizens in this zone, compute average stress ratio.
		total   := 0
		stressed := 0
		for &c in s.citizens {
			if c.zone == z.name {
				total += 1
				if c.hunger >= 80 || c.sleep <= 20 { stressed += 1 }
			}
		}
		stress_ratio := f32(0)
		if total > 0 { stress_ratio = f32(stressed) / f32(total) }

		// Fill: base zone color at low alpha, shifts redder under stress.
		fill := z.color
		fill.a = 35
		if stress_ratio > 0 {
			fill.r = u8(f32(fill.r) * (1 - stress_ratio) + 200 * stress_ratio)
			fill.g = u8(f32(fill.g) * (1 - stress_ratio))
			fill.b = u8(f32(fill.b) * (1 - stress_ratio))
			fill.a = u8(35 + u8(stress_ratio * 40))
		}
		rl.DrawCube(center, z.size.x, z.size.y, z.size.z, fill)

		// Wireframe
		wire := z.color
		wire.a = 200
		rl.DrawCubeWires(center, z.size.x, z.size.y, z.size.z, wire)

		// Top-edge highlight
		top      := rl.Vector3{center.x, center.y + z.size.y * 0.5, center.z}
		glow     := z.color
		glow.a    = 100
		rl.DrawCubeWires(top, z.size.x * 0.96, 0.04, z.size.z * 0.96, glow)
	}

	// -------------------------------------------------------------------------
	// Citizens — bobbing spheres
	// -------------------------------------------------------------------------
	for &c, i in s.citizens {
		bob    := f32(math.sin_f64(s.tick * 1.8 + f64(i) * 1.1)) * 0.12
		pos    := rl.Vector3{c.world_pos.x, c.world_pos.y + bob, c.world_pos.z}
		is_sel := i32(i) == s.selected
		in_danger := c.hunger >= 80 || c.sleep <= 20

		// Outer glow
		glow   := c.color
		glow.a  = 50
		rl.DrawSphere(pos, 0.52, glow)

		// Core sphere
		rl.DrawSphere(pos, 0.32, c.color)

		// Equator ring
		rl.DrawCircle3D(pos, 0.42, {1, 0, 0}, 90, c.color)

		// Shadow blob
		rl.DrawCircle3D({c.world_pos.x, 0.01, c.world_pos.z}, 0.26, {1, 0, 0}, 90, {0, 0, 0, 70})

		// Danger pulse ring — expands and fades on stress
		if in_danger {
			pulse_t := f32(math.sin_f64(s.tick * 4 + f64(i) * 0.9)) * 0.5 + 0.5
			pulse_r := f32(0.6) + pulse_t * 0.3
			alpha   := u8(80 + pulse_t * 100)
			rl.DrawCircle3D(pos, pulse_r, {1, 0, 0}, 90, rl.Color{COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, alpha})
		}

		// Selection ring + vertical indicator
		if is_sel {
			rl.DrawSphereWires(pos, 0.60, 8, 8, {255, 255, 255, 180})
			rl.DrawCircle3D(pos, 0.78, {1, 0, 0}, 90, {255, 255, 255, 160})
			// Vertical line down to floor
			rl.DrawLine3D(
				{c.world_pos.x, 0.02, c.world_pos.z},
				{c.world_pos.x, c.world_pos.y + bob, c.world_pos.z},
				{255, 255, 255, 60},
			)
		}
	}

	rl.EndMode3D()

	// -------------------------------------------------------------------------
	// Zone labels — 2D screen space, with population count
	// -------------------------------------------------------------------------
	for &z in s.zones {
		label_pos := rl.Vector3{z.pos.x + z.size.x * 0.5, z.size.y + 1.2, z.pos.z + z.size.z * 0.5}
		sp := rl.GetWorldToScreen(label_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		// Count population in this zone
		pop := 0
		for &c in s.citizens {
			if c.zone == z.name { pop += 1 }
		}

		name_label := z.name
		pop_label  := fmt.ctprintf("(%d)", pop)

		nw  := rl.MeasureText(name_label, 13)
		pw2 := rl.MeasureText(pop_label, 10)
		tw2 := nw + 6 + pw2

		bx := i32(sp.x) - tw2 / 2 - 8
		by := i32(sp.y) - 13

		// Background pill
		rl.DrawRectangle(bx, by, tw2 + 16, 24, {0, 0, 0, 170})
		rl.DrawRectangleLines(bx, by, tw2 + 16, 24, z.color)

		// Zone name
		rl.DrawText(name_label, bx + 8, by + 5, 13, z.color)

		// Population count (dim, smaller)
		pop_col := COL_DIM
		if pop == 0 { pop_col = COL_DANGER }
		rl.DrawText(pop_label, bx + 8 + nw + 6, by + 7, 10, pop_col)
	}

	// -------------------------------------------------------------------------
	// Citizen name tags — 2D, colored by danger state
	// -------------------------------------------------------------------------
	for &c, i in s.citizens {
		tag_pos := rl.Vector3{c.world_pos.x, c.world_pos.y + 1.0, c.world_pos.z}
		sp := rl.GetWorldToScreen(tag_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		is_sel    := i32(i) == s.selected
		in_danger := c.hunger >= 80 || c.sleep <= 20

		name_col := c.color
		if in_danger { name_col = COL_DANGER }

		tw3 := rl.MeasureText(c.name, 12)
		if is_sel {
			rl.DrawRectangle(i32(sp.x) - tw3 / 2 - 4, i32(sp.y) - 3, tw3 + 8, 18, {0, 0, 0, 200})
			rl.DrawRectangleLines(i32(sp.x) - tw3 / 2 - 4, i32(sp.y) - 3, tw3 + 8, 18, name_col)
		}
		rl.DrawText(c.name, i32(sp.x) - tw3 / 2, i32(sp.y), 12, name_col)
	}

	// Viewport border + hint
	rl.DrawRectangle(PANEL_X - 1, 0, 1, SCREEN_H, COL_BORDER)
	rl.DrawText(
		"Drag: orbit  ·  Scroll: zoom  ·  Click: select",
		10, SCREEN_H - 20, 10, {70, 88, 108, 180},
	)
}

zone_center :: proc(z: eng.Zone) -> rl.Vector3 {
	return {z.pos.x + z.size.x * 0.5, z.size.y * 0.5, z.pos.z + z.size.z * 0.5}
}
