package gui

import rl  "vendor:raylib"
import eng "../engine"
import     "core:math"
import     "core:fmt"

// ---------------------------------------------------------------------------
// Draw_World
// ---------------------------------------------------------------------------

Draw_World :: proc(s: ^eng.GameState) {
	rl.BeginMode3D(s.camera)

	draw_ground(s)
	draw_city_center(s.tick)

	for &z in s.zones {
		pop, stressed, avg_health := zone_stats(s, z)
		draw_neighborhood(z, pop, stressed, avg_health, s.tick)
	}

	for &c, ci in s.citizens {
		bob   := f32(math.sin_f64(s.tick * 2.0 + f64(ci) * 1.3)) * 0.06
		base  := rl.Vector3{c.world_pos.x, bob, c.world_pos.z}
		is_sel := i32(ci) == s.selected
		draw_citizen_figure(base, c, is_sel, s.tick, ci)
	}

	rl.EndMode3D()

	draw_overlays(s)

	rl.DrawRectangle(PANEL_X - 1, 0, 1, SCREEN_H, COL_BORDER)
	rl.DrawRectangle(0, SCREEN_H - 22, PANEL_X, 22, {0, 0, 0, 130})
	rl.DrawText(
		"[Drag] orbit  [Scroll] zoom  [Click] select",
		10, SCREEN_H - 16, 10, {65, 82, 105, 200},
	)
}

// ---------------------------------------------------------------------------
// Ground
// ---------------------------------------------------------------------------

draw_ground :: proc(s: ^eng.GameState) {
	// Dark tarmac base
	rl.DrawPlane({0, -0.01, 0}, {100, 100}, {8, 10, 16, 255})

	// Subtle tile grid
	for i := i32(-25); i <= 25; i += 1 {
		a := u8(22)
		rl.DrawLine3D({f32(i) * 2, 0.005, -50}, {f32(i) * 2, 0.005,  50}, {40, 50, 68, a})
		rl.DrawLine3D({-50, 0.005, f32(i) * 2}, { 50, 0.005, f32(i) * 2}, {40, 50, 68, a})
	}

	// Roads from each zone toward the center
	for &z in s.zones {
		zx := z.pos.x + z.size.x * 0.5
		zz := z.pos.z + z.size.z * 0.5
		rl.DrawLine3D({0, 0.01, 0}, {zx, 0.01, zz}, {30, 38, 55, 200})
		// Road shoulder lines
		rl.DrawLine3D({0.18, 0.01, 0}, {zx + 0.18, 0.01, zz}, {40, 52, 72, 80})
		rl.DrawLine3D({-0.18, 0.01, 0}, {zx - 0.18, 0.01, zz}, {40, 52, 72, 80})
	}

	// Ambient dust motes — tiny spheres that drift slowly
	for i in 0..<12 {
		fi   := f64(i)
		px   := f32(math.sin_f64(s.tick * 0.15 + fi * 2.1)) * 14
		py   := f32(math.mod(s.tick * 0.18 + fi * 0.7, 4.0))
		pz   := f32(math.cos_f64(s.tick * 0.12 + fi * 1.8)) * 14
		mote := f32(math.sin_f64(fi * 1.3 + s.tick * 0.4)) * 0.5 + 0.5
		rl.DrawSphere({px, py, pz}, 0.025, {180, 195, 215, u8(mote * 35 + 10)})
	}
}

// ---------------------------------------------------------------------------
// City center — plaza + fountain monument
// ---------------------------------------------------------------------------

draw_city_center :: proc(tick: f64) {
	// Plaza slab
	rl.DrawCube({0, -0.04, 0}, 5.5, 0.08, 5.5, {20, 26, 40, 255})
	rl.DrawCubeWires({0, -0.04, 0}, 5.5, 0.08, 5.5, {50, 65, 95, 180})

	// Corner pillars
	pillar_xs := [2]f32{-2.2, 2.2}
	pillar_zs := [2]f32{-2.2, 2.2}
	for cx in pillar_xs {
		for cz in pillar_zs {
			rl.DrawCube({cx, 0.3, cz}, 0.18, 0.6, 0.18, {30, 38, 56, 255})
			rl.DrawSphere({cx, 0.65, cz}, 0.1, {55, 148, 235, 160})
		}
	}

	// Fountain basin
	rl.DrawCylinder({0, 0, 0}, 0.9, 1.1, 0.25, 12, {25, 32, 50, 255})
	rl.DrawCylinderWires({0, 0, 0}, 0.9, 1.1, 0.25, 12, {55, 70, 100, 180})

	// Water surface
	rl.DrawCylinder({0, 0.22, 0}, 0.88, 0.88, 0.04, 12, {55, 148, 235, 120})

	// Central column
	rl.DrawCylinder({0, 0.25, 0}, 0.12, 0.18, 1.2, 8, {30, 38, 56, 255})

	// Top orb — pulses gently
	orb_r := f32(0.22) + f32(math.sin_f64(tick * 1.5)) * 0.02
	rl.DrawSphere({0, 1.55, 0}, orb_r, {55, 148, 235, 200})
	rl.DrawSphereWires({0, 1.55, 0}, orb_r + 0.06, 6, 6, {55, 148, 235, 60})

	// Water jets — 6 arcing streams (approximated as spheres along arc)
	for j in 0..<6 {
		angle := f64(j) * (math.PI * 2.0 / 6.0) + tick * 0.3
		for t in 0..<5 {
			ft  := f64(t) / 4.0
			jx  := f32(math.cos_f64(angle)) * f32(ft * 0.7)
			jz  := f32(math.sin_f64(angle)) * f32(ft * 0.7)
			jy  := f32(0.3 + ft * (1.0 - ft) * 1.2)
			rl.DrawSphere({jx, jy, jz}, 0.025, {100, 180, 255, u8(120 - t * 20)})
		}
	}
}

// ---------------------------------------------------------------------------
// Zone as a neighborhood of houses
// ---------------------------------------------------------------------------

draw_neighborhood :: proc(z: eng.Zone, pop: int, stressed: int, avg_health: f32, tick: f64) {
	cx := z.pos.x + z.size.x * 0.5
	cz := z.pos.z + z.size.z * 0.5

	// Pavement
	rl.DrawCube({cx, -0.07, cz}, z.size.x + 0.8, 0.14, z.size.z + 0.8, {16, 20, 30, 255})

	// Zone perimeter — color shows health of district
	border := z.color
	if avg_health < 40 {
		border = {220, 60, 55, 200}
	} else if avg_health < 65 {
		border = {220, 145, 35, 200}
	}
	border.a = 200
	rl.DrawCubeWires({cx, -0.01, cz}, z.size.x + 0.7, 0.16, z.size.z + 0.7, border)

	// Corner street lamps
	lamp_positions := [4][2]f32{
		{z.pos.x + 0.4, z.pos.z + 0.4},
		{z.pos.x + z.size.x - 0.4, z.pos.z + 0.4},
		{z.pos.x + 0.4, z.pos.z + z.size.z - 0.4},
		{z.pos.x + z.size.x - 0.4, z.pos.z + z.size.z - 0.4},
	}
	for lp in lamp_positions {
		rl.DrawCube({lp[0], 1.1, lp[1]}, 0.07, 2.2, 0.07, {40, 48, 62, 255})
		lamp_on := (int(tick * 0.2) % 10) < 9
		lamp_col := rl.Color{255, 235, 170, 220} if lamp_on else rl.Color{50, 55, 65, 180}
		rl.DrawSphere({lp[0], 2.3, lp[1]}, 0.12, lamp_col)
		if lamp_on {
			rl.DrawSphere({lp[0], 2.3, lp[1]}, 0.22, {255, 235, 170, 30})
		}
	}

	// House grid
	num_houses := max(pop, 2)
	cols       := 1
	for cols * cols < num_houses { cols += 1 }
	rows       := (num_houses + cols - 1) / cols

	margin := f32(0.9)
	cell_w := (z.size.x - margin * 2) / f32(cols)
	cell_d := (z.size.z - margin * 2) / f32(rows)

	hi := 0
	for row in 0..<rows {
		for col in 0..<cols {
			if hi >= num_houses { break }
			hx    := z.pos.x + margin + f32(col) * cell_w + cell_w * 0.5
			hz    := z.pos.z + margin + f32(row) * cell_d + cell_d * 0.5
			scale := min(cell_w, cell_d) * 0.40
			house_stressed := hi < stressed
			draw_house({hx, 0, hz}, scale, z.color, house_stressed, hi < pop, tick, hi)
			hi += 1
		}
	}
}

// ---------------------------------------------------------------------------
// House — walls, pitched roof, chimney, door, windows, smoke
// ---------------------------------------------------------------------------

draw_house :: proc(pos: rl.Vector3, scale: f32, zone_col: rl.Color, stressed: bool, occupied: bool, tick: f64, idx: int) {
	w := scale
	h := scale * 1.05
	d := scale
	roof_h := scale * 0.72

	// Foundation
	rl.DrawCube({pos.x, pos.y - 0.07, pos.z}, w + 0.18, 0.14, d + 0.18, {22, 28, 40, 255})

	// Walls
	wall_c := rl.Color{48, 56, 72, 255}
	if stressed       { wall_c = {68, 42, 44, 255} }
	if !occupied      { wall_c = {30, 34, 44, 255} }
	rl.DrawCube({pos.x, pos.y + h * 0.5, pos.z}, w, h, d, wall_c)

	// Wall wireframe accent
	wf := zone_col
	wf.a = occupied ? 100 : 40
	rl.DrawCubeWires({pos.x, pos.y + h * 0.5, pos.z}, w, h, d, wf)

	// Roof — 4-sided pyramid
	roof_c := rl.Color{
		u8(clamp(f32(zone_col.r) * 0.45 + 16, 0, 255)),
		u8(clamp(f32(zone_col.g) * 0.45 + 16, 0, 255)),
		u8(clamp(f32(zone_col.b) * 0.45 + 16, 0, 255)),
		255,
	}
	roof_base := rl.Vector3{pos.x, pos.y + h, pos.z}
	rl.DrawCylinder(roof_base, 0, w * 0.82, roof_h, 4, roof_c)
	rl.DrawCylinderWires(roof_base, 0, w * 0.82, roof_h, 4, wf)

	// Chimney
	chimney_x := pos.x + w * 0.23
	chimney_z := pos.z - d * 0.18
	chimney_y := pos.y + h + roof_h * 0.52
	rl.DrawCube({chimney_x, chimney_y, chimney_z}, scale * 0.14, scale * 0.52, scale * 0.14, {35, 42, 54, 255})
	// Chimney cap
	cap_y := chimney_y + scale * 0.28
	rl.DrawCube({chimney_x, cap_y, chimney_z}, scale * 0.19, scale * 0.04, scale * 0.19, {28, 34, 46, 255})

	// Chimney smoke (animated) — only when occupied
	if occupied {
		for pi in 0..<4 {
			fpi    := f64(pi)
			phase  := tick * 0.6 + fpi * 0.8 + f64(idx) * 0.4
			rise   := f32(math.mod(phase, 3.0)) * 0.38
			drift_x := f32(math.sin_f64(phase * 1.2)) * 0.06 * (1 + f32(pi) * 0.5)
			drift_z := f32(math.cos_f64(phase * 0.9)) * 0.04 * (1 + f32(pi) * 0.5)
			smoke_r := f32(0.035) + f32(pi) * 0.022
			alpha   := u8(max(0, 65 - pi * 15 - int(rise * 12)))
			rl.DrawSphere(
				{chimney_x + drift_x, cap_y + 0.05 + rise, chimney_z + drift_z},
				smoke_r,
				{145, 152, 165, alpha},
			)
		}
	}

	// Door (front face, -z side)
	door_w := w * 0.32
	door_h2 := h * 0.56
	door_z  := pos.z - d * 0.5 - 0.028
	door_c  := rl.Color{12, 15, 24, 255}
	if stressed { door_c = {30, 10, 10, 255} }
	rl.DrawCube({pos.x, pos.y + door_h2 * 0.5, door_z}, door_w, door_h2, 0.055, door_c)
	// Door frame
	frame_c := rl.Color{zone_col.r / 3, zone_col.g / 3, zone_col.b / 3, 255}
	rl.DrawCubeWires({pos.x, pos.y + door_h2 * 0.5, door_z}, door_w, door_h2, 0.055, frame_c)
	// Door knob
	rl.DrawSphere({pos.x + door_w * 0.33, pos.y + door_h2 * 0.44, door_z - 0.03}, 0.022, {170, 148, 65, 255})

	// Door step
	rl.DrawCube(
		{pos.x, pos.y - 0.01, door_z - scale * 0.12},
		door_w + 0.06, 0.06, scale * 0.16,
		{28, 35, 48, 255},
	)

	// Windows (phase-staggered lighting)
	win_phase := int(tick * 0.22 + f64(idx) * 1.9)
	win_lit   := occupied && (win_phase % 6 != 0)
	win_col   := rl.Color{255, 235, 145, 215} if win_lit else rl.Color{28, 34, 50, 180}

	lw_pos := rl.Vector3{pos.x - w * 0.5 - 0.028, pos.y + h * 0.65, pos.z + d * 0.08}
	rw_pos := rl.Vector3{pos.x + w * 0.5 + 0.028, pos.y + h * 0.65, pos.z + d * 0.08}
	rl.DrawCube(lw_pos, 0.056, h * 0.25, d * 0.30, win_col)
	rl.DrawCube(rw_pos, 0.056, h * 0.25, d * 0.30, win_col)

	// Window glow bloom
	if win_lit {
		glow := rl.Color{255, 235, 145, 28}
		rl.DrawCube(lw_pos, 0.08, h * 0.32, d * 0.38, glow)
		rl.DrawCube(rw_pos, 0.08, h * 0.32, d * 0.38, glow)
	}

	// Vacant houses get an 'X' indicator via two crossed lines
	if !occupied {
		x1 := pos.x - w * 0.25
		x2 := pos.x + w * 0.25
		mid_z := pos.z - d * 0.5 - 0.05
		mid_y := pos.y + h * 0.5
		rl.DrawLine3D({x1, mid_y - h*0.2, mid_z}, {x2, mid_y + h*0.2, mid_z}, {50, 55, 70, 80})
		rl.DrawLine3D({x2, mid_y - h*0.2, mid_z}, {x1, mid_y + h*0.2, mid_z}, {50, 55, 70, 80})
	}
}

// ---------------------------------------------------------------------------
// Citizen — capsule figure with need indicators
// ---------------------------------------------------------------------------

draw_citizen_figure :: proc(base: rl.Vector3, c: eng.Citizen, is_sel: bool, tick: f64, idx: int) {
	foot_y  := base.y + 0.18
	body_h  := f32(0.55)
	head_r  := f32(0.155)
	body_r  := f32(0.12)
	in_danger := c.hunger >= 80 || c.sleep <= 20

	foot     := rl.Vector3{base.x, foot_y, base.z}
	shoulder := rl.Vector3{base.x, foot_y + body_h, base.z}
	head     := rl.Vector3{base.x, foot_y + body_h + head_r + 0.04, base.z}

	// Ground shadow
	rl.DrawCircle3D({base.x, 0.008, base.z}, 0.20, {1, 0, 0}, 90, {0, 0, 0, 55})

	// Body + head
	rl.DrawCapsule(foot, shoulder, body_r, 4, 4, c.color)
	rl.DrawSphere(head, head_r, c.color)

	// Behavior dot on chest — color = behavior
	chest := rl.Vector3{base.x, foot_y + body_h * 0.55, base.z - body_r - 0.01}
	rl.DrawSphere(chest, 0.04, behavior_dot_color(c.behavior))

	// Danger pulse ring
	if in_danger {
		pulse_t := f32(math.sin_f64(tick * 4.5 + f64(idx) * 0.8)) * 0.5 + 0.5
		pr      := f32(0.28) + pulse_t * 0.16
		pa      := u8(55 + pulse_t * 110)
		rl.DrawCircle3D({base.x, foot_y + body_h * 0.4, base.z}, pr, {1, 0, 0}, 90, {225, 60, 55, pa})
	}

	// Stress severity — second ring, dimmer, larger
	if c.stress_ticks >= 3 {
		sr := f32(0.48) + f32(math.sin_f64(tick * 2.5 + f64(idx) * 1.1)) * 0.08
		rl.DrawCircle3D({base.x, foot_y + body_h * 0.4, base.z}, sr, {1, 0, 0}, 90, {225, 60, 55, 35})
	}

	// Selection rings
	if is_sel {
		rl.DrawCircle3D(foot, 0.27, {1, 0, 0}, 90, {255, 255, 255, 210})
		rl.DrawCircle3D(head,  0.22, {1, 0, 0}, 90, {255, 255, 255, 160})
		rl.DrawLine3D({base.x, 0.015, base.z}, foot, {255, 255, 255, 70})
	}
}

// ---------------------------------------------------------------------------
// 2D overlays — zone labels + citizen need tags
// ---------------------------------------------------------------------------

draw_overlays :: proc(s: ^eng.GameState) {
	// Zone labels with population + stress heat
	for &z in s.zones {
		lp := rl.Vector3{z.pos.x + z.size.x * 0.5, 4.8, z.pos.z + z.size.z * 0.5}
		sp := rl.GetWorldToScreen(lp, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		pop, stressed, avg_hp := zone_stats(s, z)
		pop_str  := fmt.ctprintf("(%d) HP%.0f", pop, avg_hp)
		stress_w := i32(0)
		if pop > 0 { stress_w = i32(f32(stressed) / f32(pop) * 30) }

		nw      := rl.MeasureText(z.name, 12)
		pw      := rl.MeasureText(pop_str, 9)
		total_w := max(nw, pw) + 18
		bx      := i32(sp.x) - total_w / 2
		by      := i32(sp.y) - 16

		rl.DrawRectangle(bx, by, total_w, 30, {0, 0, 0, 180})
		rl.DrawRectangleLines(bx, by, total_w, 30, z.color)
		rl.DrawText(z.name, bx + 8, by + 4,  12, z.color)
		rl.DrawText(pop_str, bx + 8, by + 19, 9, rl.Color{130, 150, 175, 200})

		// Stress bar at bottom of label
		if pop > 0 && stress_w > 0 {
			rl.DrawRectangle(bx, by + 28, stress_w, 2, {225, 60, 55, 200})
		}
	}

	// Citizen need tags — only show if critical
	for &c, ci in s.citizens {
		tag_pos := rl.Vector3{c.world_pos.x, 2.0, c.world_pos.z}
		sp := rl.GetWorldToScreen(tag_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		is_sel    := i32(ci) == s.selected
		in_danger := c.hunger >= 80 || c.sleep <= 20

		// Name tag
		name_col := c.color
		if in_danger { name_col = {225, 60, 55, 255} }
		nw := rl.MeasureText(c.name, 11)
		sx := i32(sp.x) - nw / 2
		sy := i32(sp.y)

		if is_sel {
			rl.DrawRectangle(sx - 4, sy - 2, nw + 8, 15, {0, 0, 0, 200})
			rl.DrawRectangleLines(sx - 4, sy - 2, nw + 8, 15, name_col)
		}
		rl.DrawText(c.name, sx, sy, 11, name_col)

		// Need tags — floating above name
		tag_y := sy - 14
		tag_x := sx
		if c.health <= 30 {
			rl.DrawText("HP!", tag_x, tag_y, 9, {225, 60, 55, 230})
			tag_y -= 11
		}
		if c.hunger >= 88 {
			rl.DrawText("STARVING", tag_x, tag_y, 9, {225, 145, 35, 220})
			tag_y -= 11
		} else if c.hunger >= 75 {
			rl.DrawText("HUNGRY", tag_x, tag_y, 9, {180, 120, 30, 180})
			tag_y -= 11
		}
		if c.sleep <= 12 {
			rl.DrawText("EXHAUSTED", tag_x, tag_y, 9, {80, 155, 255, 220})
		} else if c.sleep <= 25 {
			rl.DrawText("TIRED", tag_x, tag_y, 9, {60, 120, 200, 180})
		}
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

zone_stats :: proc(s: ^eng.GameState, z: eng.Zone) -> (pop: int, stressed: int, avg_health: f32) {
	total_hp := f32(0)
	for &c in s.citizens {
		if c.zone == z.name {
			pop += 1
			total_hp += c.health
			if c.hunger >= 80 || c.sleep <= 20 { stressed += 1 }
		}
	}
	if pop > 0 { avg_health = total_hp / f32(pop) } else { avg_health = 100 }
	return
}

zone_center :: proc(z: eng.Zone) -> rl.Vector3 {
	return {z.pos.x + z.size.x * 0.5, z.size.y * 0.5, z.pos.z + z.size.z * 0.5}
}

behavior_dot_color :: proc(b: eng.Behavior) -> rl.Color {
	switch b {
	case .Eating:      return {220, 145, 40, 255}
	case .Sleeping:    return {80, 155, 255, 255}
	case .Socializing: return {200, 95, 255, 255}
	case .Working:     return {65, 210, 90, 255}
	case .Wandering:   return {150, 170, 195, 255}
	case .Idle:        return {55, 65, 82, 255}
	}
	return {55, 65, 82, 255}
}
