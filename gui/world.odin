package gui

import rl  "vendor:raylib"
import eng "../engine"
import     "core:math"
import     "core:fmt"

// ---------------------------------------------------------------------------
// Draw_World — zones render as house-filled neighborhoods, citizens as
// walking figures. No transparent boxes — everything is geometry now.
// ---------------------------------------------------------------------------

Draw_World :: proc(s: ^eng.GameState) {
	rl.BeginMode3D(s.camera)

	// Ground plane — dark tarmac
	rl.DrawPlane({0, -0.01, 0}, {80, 80}, {10, 12, 18, 255})

	// Subtle grid lines on the ground
	for i := i32(-20); i <= 20; i += 1 {
		alpha := u8(30)
		rl.DrawLine3D({f32(i)*2, 0, -40}, {f32(i)*2, 0, 40}, {55, 65, 85, alpha})
		rl.DrawLine3D({-40, 0, f32(i)*2}, {40, 0, f32(i)*2}, {55, 65, 85, alpha})
	}

	// -------------------------------------------------------------------------
	// Zones as neighborhoods
	// -------------------------------------------------------------------------
	for &z in s.zones {
		// Count + stress per zone
		pop      := 0
		stressed := 0
		for &c in s.citizens {
			if c.zone == z.name {
				pop += 1
				if c.hunger >= 80 || c.sleep <= 20 { stressed += 1 }
			}
		}
		stress_ratio := f32(0)
		if pop > 0 { stress_ratio = f32(stressed) / f32(pop) }

		draw_neighborhood(z, pop, stress_ratio, s.tick)
	}

	// -------------------------------------------------------------------------
	// Citizens as capsule figures
	// -------------------------------------------------------------------------
	for &c, ci in s.citizens {
		bob        := f32(math.sin_f64(s.tick * 2.0 + f64(ci) * 1.3)) * 0.05
		base       := rl.Vector3{c.world_pos.x, bob, c.world_pos.z}
		is_sel     := i32(ci) == s.selected
		in_danger  := c.hunger >= 80 || c.sleep <= 20

		draw_citizen_figure(base, c.color, in_danger, is_sel, s.tick, ci)
	}

	rl.EndMode3D()

	// -------------------------------------------------------------------------
	// 2D overlays — zone labels + citizen name tags
	// -------------------------------------------------------------------------
	for &z in s.zones {
		label_pos := rl.Vector3{
			z.pos.x + z.size.x * 0.5,
			4.5,
			z.pos.z + z.size.z * 0.5,
		}
		sp := rl.GetWorldToScreen(label_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		pop := 0
		for &c in s.citizens {
			if c.zone == z.name { pop += 1 }
		}

		name_str := z.name
		pop_str  := fmt.ctprintf("(%d)", pop)
		nw       := rl.MeasureText(name_str, 13)
		pw2      := rl.MeasureText(pop_str, 10)
		total_w  := nw + 8 + pw2

		bx := i32(sp.x) - total_w / 2 - 8
		by := i32(sp.y) - 14

		rl.DrawRectangle(bx, by, total_w + 16, 26, {0, 0, 0, 175})
		rl.DrawRectangleLines(bx, by, total_w + 16, 26, z.color)
		rl.DrawText(name_str, bx + 8, by + 6, 13, z.color)
		pop_col := rl.Color{80, 98, 120, 255} if pop > 0 else rl.Color{225, 60, 55, 255}
		rl.DrawText(pop_str, bx + 8 + nw + 8, by + 8, 10, pop_col)
	}

	for &c, ci in s.citizens {
		tag_pos := rl.Vector3{c.world_pos.x, 1.8, c.world_pos.z}
		sp := rl.GetWorldToScreen(tag_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		in_danger := c.hunger >= 80 || c.sleep <= 20
		is_sel    := i32(ci) == s.selected
		name_col  := c.color
		if in_danger { name_col = rl.Color{225, 60, 55, 255} }

		tw := rl.MeasureText(c.name, 11)
		sx := i32(sp.x) - tw / 2
		sy := i32(sp.y)

		if is_sel {
			rl.DrawRectangle(sx - 4, sy - 2, tw + 8, 16, {0, 0, 0, 200})
			rl.DrawRectangleLines(sx - 4, sy - 2, tw + 8, 16, name_col)
		}
		rl.DrawText(c.name, sx, sy, 11, name_col)
	}

	// Hint bar
	rl.DrawRectangle(0, SCREEN_H - 22, PANEL_X, 22, {0, 0, 0, 120})
	rl.DrawText("Drag: orbit  ·  Scroll: zoom  ·  Click sphere: select citizen", 10, SCREEN_H - 16, 10, {70, 88, 108, 200})
}

// ---------------------------------------------------------------------------
// draw_neighborhood — renders a zone as a grid of houses on a paved block
// ---------------------------------------------------------------------------

draw_neighborhood :: proc(z: eng.Zone, pop: int, stress_ratio: f32, tick: f64) {
	cx := z.pos.x + z.size.x * 0.5
	cz := z.pos.z + z.size.z * 0.5

	// Pavement slab
	rl.DrawCube({cx, -0.06, cz}, z.size.x + 0.6, 0.12, z.size.z + 0.6, {18, 22, 32, 255})

	// Zone perimeter curb — tinted by zone color
	curb := z.color
	curb.a = 180
	rl.DrawCubeWires({cx, -0.01, cz}, z.size.x + 0.5, 0.14, z.size.z + 0.5, curb)

	// Street lamp at corner
	lamp_x := z.pos.x + 0.5
	lamp_z := z.pos.z + 0.5
	rl.DrawCube({lamp_x, 1.2, lamp_z}, 0.08, 2.4, 0.08, {45, 52, 65, 255})
	rl.DrawSphere({lamp_x, 2.5, lamp_z}, 0.14, {255, 240, 180, 220})

	// Determine house grid — at least enough for current pop, minimum 2
	num_houses := max(pop, 2)
	cols       := 1
	for cols * cols < num_houses { cols += 1 }
	rows       := (num_houses + cols - 1) / cols

	margin    := f32(0.8)
	cell_w    := (z.size.x - margin * 2) / f32(cols)
	cell_d    := (z.size.z - margin * 2) / f32(rows)

	hi := 0
	for row in 0..<rows {
		for col in 0..<cols {
			if hi >= num_houses { break }

			hx := z.pos.x + margin + f32(col) * cell_w + cell_w * 0.5
			hz := z.pos.z + margin + f32(row) * cell_d + cell_d * 0.5

			occupied     := hi < pop
			house_stress := occupied && stress_ratio > 0.5
			scale        := min(cell_w, cell_d) * 0.42

			draw_house(
				{hx, 0, hz},
				scale,
				z.color,
				house_stress,
				occupied,
				tick,
				hi,
			)
			hi += 1
		}
	}
}

// ---------------------------------------------------------------------------
// draw_house — one building: foundation, walls, pitched roof, door, windows
// ---------------------------------------------------------------------------

draw_house :: proc(pos: rl.Vector3, scale: f32, zone_col: rl.Color, stressed: bool, occupied: bool, tick: f64, idx: int) {
	w := scale
	h := scale * 1.05
	d := scale

	// Foundation slab
	rl.DrawCube({pos.x, pos.y - 0.06, pos.z}, w + 0.15, 0.12, d + 0.15, {25, 30, 42, 255})

	// Walls — slightly stressed tint when citizen inside is suffering
	wall_c := rl.Color{50, 58, 74, 255}
	if stressed {
		wall_c = {65, 44, 46, 255}
	}
	rl.DrawCube({pos.x, pos.y + h * 0.5, pos.z}, w, h, d, wall_c)

	// Wall edge highlight — uses zone color as accent
	outline := zone_col
	outline.a = 120
	rl.DrawCubeWires({pos.x, pos.y + h * 0.5, pos.z}, w, h, d, outline)

	// Pitched roof — 4-sided pyramid via cylinder with 4 slices
	roof_c := rl.Color{
		u8(clamp(f32(zone_col.r) * 0.4 + 18, 0, 255)),
		u8(clamp(f32(zone_col.g) * 0.4 + 18, 0, 255)),
		u8(clamp(f32(zone_col.b) * 0.4 + 18, 0, 255)),
		255,
	}
	roof_base   := rl.Vector3{pos.x, pos.y + h, pos.z}
	roof_radius := w * 0.80
	roof_height := scale * 0.7
	rl.DrawCylinder(roof_base, 0, roof_radius, roof_height, 4, roof_c)
	rl.DrawCylinderWires(roof_base, 0, roof_radius, roof_height, 4, outline)

	// Chimney
	rl.DrawCube(
		{pos.x + w * 0.22, pos.y + h + roof_height * 0.55, pos.z - d * 0.18},
		scale * 0.13, scale * 0.55, scale * 0.13,
		{38, 44, 55, 255},
	)
	// Chimney cap
	rl.DrawCube(
		{pos.x + w * 0.22, pos.y + h + roof_height * 0.55 + scale * 0.29, pos.z - d * 0.18},
		scale * 0.17, scale * 0.04, scale * 0.17,
		{30, 35, 46, 255},
	)

	// Door — front face is -z
	door_w := w * 0.30
	door_h := h * 0.55
	door_z := pos.z - d * 0.5 - 0.025
	rl.DrawCube({pos.x, pos.y + door_h * 0.5, door_z}, door_w, door_h, 0.05, {14, 17, 26, 255})
	// Door frame
	frame_c := rl.Color{zone_col.r / 3, zone_col.g / 3, zone_col.b / 3, 255}
	rl.DrawCubeWires({pos.x, pos.y + door_h * 0.5, door_z}, door_w, door_h, 0.05, frame_c)
	// Door knob
	rl.DrawSphere(
		{pos.x + door_w * 0.32, pos.y + door_h * 0.45, door_z - 0.03},
		0.025,
		{180, 160, 80, 255},
	)

	// Windows — glow if lit; stagger lighting by house index + time
	win_phase := int(tick * 0.25 + f64(idx) * 1.7)
	win_lit   := occupied && (win_phase % 5 != 0)
	win_col   := rl.Color{255, 238, 155, 210} if win_lit else rl.Color{30, 36, 52, 180}
	win_glow  := rl.Color{255, 238, 155, 35}

	// Left window
	lw_pos := rl.Vector3{pos.x - w * 0.5 - 0.025, pos.y + h * 0.65, pos.z + d * 0.1}
	rl.DrawCube(lw_pos, 0.05, h * 0.24, d * 0.28, win_col)
	if win_lit { rl.DrawCube(lw_pos, 0.08, h * 0.30, d * 0.34, win_glow) }

	// Right window
	rw_pos := rl.Vector3{pos.x + w * 0.5 + 0.025, pos.y + h * 0.65, pos.z + d * 0.1}
	rl.DrawCube(rw_pos, 0.05, h * 0.24, d * 0.28, win_col)
	if win_lit { rl.DrawCube(rw_pos, 0.08, h * 0.30, d * 0.34, win_glow) }

	// Path to door (small paving stone)
	rl.DrawCube(
		{pos.x, pos.y - 0.04, pos.z - d * 0.5 - scale * 0.22},
		door_w + 0.05, 0.04, scale * 0.22,
		{28, 34, 46, 255},
	)
}

// ---------------------------------------------------------------------------
// draw_citizen_figure — capsule body + sphere head, colored by state
// ---------------------------------------------------------------------------

draw_citizen_figure :: proc(base: rl.Vector3, col: rl.Color, in_danger: bool, is_sel: bool, tick: f64, idx: int) {
	foot_y  := base.y + 0.18
	body_h  := f32(0.55)
	head_r  := f32(0.16)
	body_r  := f32(0.13)

	foot   := rl.Vector3{base.x, foot_y, base.z}
	shoulder := rl.Vector3{base.x, foot_y + body_h, base.z}
	head   := rl.Vector3{base.x, foot_y + body_h + head_r + 0.04, base.z}

	// Shadow
	rl.DrawCircle3D(
		{base.x, 0.01, base.z}, 0.22, {1, 0, 0}, 90,
		{0, 0, 0, 60},
	)

	// Body (capsule)
	rl.DrawCapsule(foot, shoulder, body_r, 4, 4, col)

	// Head
	rl.DrawSphere(head, head_r, col)

	// Danger pulse ring
	if in_danger {
		pulse := f32(math.sin_f64(tick * 4.5 + f64(idx) * 0.8)) * 0.5 + 0.5
		pr    := f32(0.30) + pulse * 0.18
		pa    := u8(60 + pulse * 110)
		rl.DrawCircle3D(
			{base.x, foot_y + body_h * 0.4, base.z},
			pr, {1, 0, 0}, 90,
			{225, 60, 55, pa},
		)
	}

	// Selection — white rings top and bottom
	if is_sel {
		rl.DrawCircle3D(foot,   0.28, {1, 0, 0}, 90, {255, 255, 255, 200})
		rl.DrawCircle3D(head,   0.22, {1, 0, 0}, 90, {255, 255, 255, 160})
		// Vertical drop line
		rl.DrawLine3D(
			{base.x, 0.02, base.z},
			{base.x, foot_y, base.z},
			{255, 255, 255, 80},
		)
	}
}
