package gui

import rl  "vendor:raylib"
import eng "../engine"
import     "core:math"
import     "core:fmt"

// ---------------------------------------------------------------------------
// Sky color — exported so main.odin can set ClearBackground dynamically.
// game_tick is the simulation step count (real_seconds / tick_rate).
// ---------------------------------------------------------------------------

sky_color :: proc(game_tick: int) -> rl.Color {
	hour := game_tick % 24

	NIGHT :: rl.Color{ 3,  4,  9, 255}
	DAWN  :: rl.Color{14,  9, 22, 255}
	DAY   :: rl.Color{ 8, 10, 14, 255}
	DUSK  :: rl.Color{16, 10, 20, 255}

	lerp_sky :: proc(a, b: rl.Color, t: f32) -> rl.Color {
		return rl.Color{
			u8(f32(a.r) + f32(i16(b.r) - i16(a.r)) * t),
			u8(f32(a.g) + f32(i16(b.g) - i16(a.g)) * t),
			u8(f32(a.b) + f32(i16(b.b) - i16(a.b)) * t),
			255,
		}
	}

	switch {
	case hour < 5:  return NIGHT
	case hour < 7:  return lerp_sky(NIGHT, DAWN,  f32(hour - 5) / 2.0)
	case hour < 8:  return lerp_sky(DAWN,  DAY,   f32(hour - 7))
	case hour < 18: return DAY
	case hour < 20: return lerp_sky(DAY,   DUSK,  f32(hour - 18) / 2.0)
	case hour < 22: return lerp_sky(DUSK,  NIGHT, f32(hour - 20) / 2.0)
	case:           return NIGHT
	}
}

// is_nighttime returns true when street lamps should shine bright.
is_nighttime :: proc(game_tick: int) -> bool {
	h := game_tick % 24
	return h < 7 || h >= 19
}

// ---------------------------------------------------------------------------
// Main draw entry point
// ---------------------------------------------------------------------------

Draw_World :: proc(s: ^eng.GameState) {
	game_tick := int(s.tick / s.tick_rate) if s.tick_rate > 0 else 0
	night     := is_nighttime(game_tick)

	rl.BeginMode3D(s.camera)

	draw_ground(s, night)
	draw_city_center(s.tick, night)

	// Rain when unrest >= 60
	if s.unrest >= 60 {
		draw_rain(s.unrest, s.tick)
	}

	for &z in s.zones {
		pop, stressed, avg_hp := zone_stats(s, z)
		draw_neighborhood(z, pop, stressed, avg_hp, s.tick, night)
	}

	draw_social_links(s.citizens[:])

	for &c, ci in s.citizens {
		bob   := f32(math.sin_f64(s.tick * 2.0 + f64(ci) * 1.3)) * 0.06
		base  := rl.Vector3{c.world_pos.x, bob, c.world_pos.z}
		draw_citizen_figure(base, c, i32(ci) == s.selected, s.tick, ci)
	}

	rl.EndMode3D()
	draw_overlays(s)

	rl.DrawRectangle(PANEL_X - 1, 0, 1, SCREEN_H, COL_BORDER)
	rl.DrawRectangle(0, SCREEN_H - 22, PANEL_X, 22, {0, 0, 0, 130})

	speed_str := cstring("")
	if s.paused {
		speed_str = "  [PAUSED]"
	} else if s.speed >= 4 {
		speed_str = "  [×4]"
	} else if s.speed >= 2 {
		speed_str = "  [×2]"
	}
	hint := fmt.ctprintf("[Drag] orbit  [Scroll] zoom  [Click] select  [Space] pause  [1/2/3] speed%s", speed_str)
	rl.DrawText(hint, 10, SCREEN_H - 16, 9, {65, 82, 105, 200})
}

// ---------------------------------------------------------------------------
// Ground
// ---------------------------------------------------------------------------

draw_ground :: proc(s: ^eng.GameState, night: bool) {
	ground_c := rl.Color{8, 10, 16, 255} if night else rl.Color{10, 12, 18, 255}
	rl.DrawPlane({0, -0.01, 0}, {100, 100}, ground_c)

	grid_a := u8(14) if night else u8(22)
	for i := i32(-25); i <= 25; i += 1 {
		rl.DrawLine3D({f32(i)*2, 0.005, -50}, {f32(i)*2, 0.005,  50}, {40, 50, 68, grid_a})
		rl.DrawLine3D({-50, 0.005, f32(i)*2}, { 50, 0.005, f32(i)*2}, {40, 50, 68, grid_a})
	}

	// Roads from city center to each zone
	for &z in s.zones {
		zx := z.pos.x + z.size.x * 0.5
		zz := z.pos.z + z.size.z * 0.5
		road_c := rl.Color{28, 35, 50, 200}
		rl.DrawLine3D({0, 0.01, 0}, {zx, 0.01, zz}, road_c)
		rl.DrawLine3D({ 0.2, 0.01, 0}, {zx + 0.2, 0.01, zz}, {40, 52, 72, 70})
		rl.DrawLine3D({-0.2, 0.01, 0}, {zx - 0.2, 0.01, zz}, {40, 52, 72, 70})
	}

	// Ambient dust motes
	for i in 0..<12 {
		fi  := f64(i)
		px  := f32(math.sin_f64(s.tick * 0.15 + fi * 2.1)) * 14
		py  := f32(math.mod(s.tick * 0.18 + fi * 0.7, 4.0))
		pz  := f32(math.cos_f64(s.tick * 0.12 + fi * 1.8)) * 14
		m   := f32(math.sin_f64(fi * 1.3 + s.tick * 0.4)) * 0.5 + 0.5
		rl.DrawSphere({px, py, pz}, 0.025, {180, 195, 215, u8(m * 35 + 10)})
	}
}

// ---------------------------------------------------------------------------
// City center — animated fountain plaza
// ---------------------------------------------------------------------------

draw_city_center :: proc(tick: f64, night: bool) {
	rl.DrawCube({0, -0.04, 0}, 5.5, 0.08, 5.5, {20, 26, 40, 255})
	rl.DrawCubeWires({0, -0.04, 0}, 5.5, 0.08, 5.5, {50, 65, 95, 180})

	pillar_xs := [2]f32{-2.2, 2.2}
	pillar_zs := [2]f32{-2.2, 2.2}
	for cx in pillar_xs {
		for cz in pillar_zs {
			rl.DrawCube({cx, 0.3, cz}, 0.18, 0.6, 0.18, {30, 38, 56, 255})
			lamp_c := rl.Color{255, 235, 170, 220} if night else rl.Color{55, 148, 235, 160}
			rl.DrawSphere({cx, 0.65, cz}, 0.10, lamp_c)
			if night { rl.DrawSphere({cx, 0.65, cz}, 0.20, {255, 235, 170, 35}) }
		}
	}

	rl.DrawCylinder({0, 0, 0}, 0.9, 1.1, 0.25, 12, {25, 32, 50, 255})
	rl.DrawCylinderWires({0, 0, 0}, 0.9, 1.1, 0.25, 12, {55, 70, 100, 180})
	rl.DrawCylinder({0, 0.22, 0}, 0.88, 0.88, 0.04, 12, {55, 148, 235, 120})
	rl.DrawCylinder({0, 0.25, 0}, 0.12, 0.18, 1.2, 8, {30, 38, 56, 255})

	orb_r := f32(0.22) + f32(math.sin_f64(tick * 1.5)) * 0.02
	rl.DrawSphere({0, 1.55, 0}, orb_r, {55, 148, 235, 200})
	rl.DrawSphereWires({0, 1.55, 0}, orb_r + 0.06, 6, 6, {55, 148, 235, 55})

	for j in 0..<6 {
		angle := f64(j) * (math.PI * 2.0 / 6.0) + tick * 0.3
		for t in 0..<5 {
			ft := f64(t) / 4.0
			jx := f32(math.cos_f64(angle)) * f32(ft * 0.7)
			jz := f32(math.sin_f64(angle)) * f32(ft * 0.7)
			jy := f32(0.3 + ft * (1.0 - ft) * 1.2)
			rl.DrawSphere({jx, jy, jz}, 0.025, {100, 180, 255, u8(120 - t * 22)})
		}
	}
}

// ---------------------------------------------------------------------------
// Rain — falling when unrest >= 60
// ---------------------------------------------------------------------------

draw_rain :: proc(unrest: f32, tick: f64) {
	intensity := (unrest - 60) / 40.0
	n_drops   := int(intensity * 280)
	speed     := f64(14.0)

	for i in 0..<n_drops {
		fi    := f64(i)
		dx    := f32(math.mod(fi * 13.7, 50) - 25)
		dz    := f32(math.mod(fi * 7.3,  50) - 25)
		phase := math.mod(tick * speed + fi * 17.3, 22.0)
		dy    := f32(20 - phase)
		if dy < 0 || dy > 20 { continue }

		alpha := u8(65 * intensity)
		rl.DrawLine3D({dx, dy, dz}, {dx, dy - 0.35, dz}, {120, 148, 195, alpha})
	}
}

// ---------------------------------------------------------------------------
// Zone neighborhood — pavement, lamps, house grid, landmark
// ---------------------------------------------------------------------------

draw_neighborhood :: proc(z: eng.Zone, pop: int, stressed: int, avg_hp: f32, tick: f64, night: bool) {
	cx := z.pos.x + z.size.x * 0.5
	cz := z.pos.z + z.size.z * 0.5

	rl.DrawCube({cx, -0.07, cz}, z.size.x + 0.8, 0.14, z.size.z + 0.8, {16, 20, 30, 255})

	border := z.color
	if   avg_hp < 40 { border = {220, 60, 55, 200} }
	else if avg_hp < 65 { border = {220, 145, 35, 200} }
	else { border.a = 200 }
	rl.DrawCubeWires({cx, -0.01, cz}, z.size.x + 0.7, 0.16, z.size.z + 0.7, border)

	// Corner lamps
	lxs := [2]f32{z.pos.x + 0.4, z.pos.x + z.size.x - 0.4}
	lzs := [2]f32{z.pos.z + 0.4, z.pos.z + z.size.z - 0.4}
	for lx in lxs {
		for lz in lzs {
			rl.DrawCube({lx, 1.1, lz}, 0.07, 2.2, 0.07, {38, 46, 60, 255})
			lamp_c := rl.Color{255, 235, 165, 220} if night else rl.Color{60, 72, 90, 180}
			rl.DrawSphere({lx, 2.3, lz}, 0.12, lamp_c)
			if night { rl.DrawSphere({lx, 2.3, lz}, 0.24, {255, 235, 165, 28}) }
		}
	}

	// House grid — skip cells too close to the landmark center
	num_houses   := max(pop, 2)
	cols         := 1
	for cols * cols < num_houses { cols += 1 }
	rows         := (num_houses + cols - 1) / cols
	margin       := f32(0.9)
	cell_w       := (z.size.x - margin * 2) / f32(cols)
	cell_d       := (z.size.z - margin * 2) / f32(rows)
	lm_clear_r2  := f32(1.8 * 1.8)  // squared radius around landmark center

	hi := 0
	for row in 0..<rows {
		for col in 0..<cols {
			if hi >= num_houses { break }
			hx    := z.pos.x + margin + f32(col) * cell_w + cell_w * 0.5
			hz    := z.pos.z + margin + f32(row) * cell_d + cell_d * 0.5
			ddx   := hx - cx
			ddz   := hz - cz
			if ddx * ddx + ddz * ddz < lm_clear_r2 { hi += 1; continue }
			scale := min(cell_w, cell_d) * 0.40
			draw_house({hx, 0, hz}, scale, z.color, hi < stressed, hi < pop, tick, hi)
			hi += 1
		}
	}

	// Zone-specific landmark at center
	draw_zone_landmark({cx, 0, cz}, z.name, z.color, tick, night)
}

// ---------------------------------------------------------------------------
// House
// ---------------------------------------------------------------------------

draw_house :: proc(pos: rl.Vector3, scale: f32, zone_col: rl.Color, stressed: bool, occupied: bool, tick: f64, idx: int) {
	w      := scale
	h      := scale * 1.05
	d      := scale
	roof_h := scale * 0.72

	rl.DrawCube({pos.x, pos.y - 0.07, pos.z}, w + 0.18, 0.14, d + 0.18, {22, 28, 40, 255})

	wall_c := rl.Color{50, 58, 74, 255}
	if stressed  { wall_c = {68, 42, 44, 255} }
	if !occupied { wall_c = {28, 32, 42, 255} }
	rl.DrawCube({pos.x, pos.y + h * 0.5, pos.z}, w, h, d, wall_c)

	wf := zone_col; wf.a = u8(100 if occupied else 35)
	rl.DrawCubeWires({pos.x, pos.y + h * 0.5, pos.z}, w, h, d, wf)

	roof_c := rl.Color{
		u8(clamp(f32(zone_col.r) * 0.45 + 14, 0, 255)),
		u8(clamp(f32(zone_col.g) * 0.45 + 14, 0, 255)),
		u8(clamp(f32(zone_col.b) * 0.45 + 14, 0, 255)),
		255,
	}
	rl.DrawCylinder({pos.x, pos.y + h, pos.z}, 0, w * 0.82, roof_h, 4, roof_c)
	rl.DrawCylinderWires({pos.x, pos.y + h, pos.z}, 0, w * 0.82, roof_h, 4, wf)

	chim_x := pos.x + w * 0.23
	chim_z := pos.z - d * 0.18
	chim_y := pos.y + h + roof_h * 0.52
	rl.DrawCube({chim_x, chim_y, chim_z}, scale * 0.14, scale * 0.52, scale * 0.14, {35, 42, 54, 255})
	cap_y := chim_y + scale * 0.28
	rl.DrawCube({chim_x, cap_y, chim_z}, scale * 0.19, scale * 0.04, scale * 0.19, {28, 34, 46, 255})

	if occupied {
		for pi in 0..<4 {
			phase  := tick * 0.6 + f64(pi) * 0.8 + f64(idx) * 0.4
			rise   := f32(math.mod(phase, 3.0)) * 0.38
			dx     := f32(math.sin_f64(phase * 1.2)) * 0.06 * (1 + f32(pi) * 0.5)
			dz2    := f32(math.cos_f64(phase * 0.9)) * 0.04 * (1 + f32(pi) * 0.5)
			alpha  := u8(max(0, 65 - pi * 15 - int(rise * 12)))
			rl.DrawSphere({chim_x + dx, cap_y + 0.05 + rise, chim_z + dz2}, 0.035 + f32(pi) * 0.022, {142, 150, 162, alpha})
		}
	}

	door_w  := w * 0.32
	door_h2 := h * 0.56
	door_z  := pos.z - d * 0.5 - 0.028
	door_c  := rl.Color{12, 14, 24, 255} if !stressed else rl.Color{28, 8, 8, 255}
	rl.DrawCube({pos.x, pos.y + door_h2 * 0.5, door_z}, door_w, door_h2, 0.055, door_c)
	frame_c := rl.Color{zone_col.r / 3, zone_col.g / 3, zone_col.b / 3, 255}
	rl.DrawCubeWires({pos.x, pos.y + door_h2 * 0.5, door_z}, door_w, door_h2, 0.055, frame_c)
	rl.DrawSphere({pos.x + door_w * 0.33, pos.y + door_h2 * 0.44, door_z - 0.03}, 0.022, {168, 145, 62, 255})
	rl.DrawCube({pos.x, pos.y - 0.01, door_z - scale * 0.12}, door_w + 0.06, 0.06, scale * 0.16, {28, 35, 48, 255})

	win_lit := occupied && (int(tick * 0.22 + f64(idx) * 1.9) % 6 != 0)
	win_col := rl.Color{255, 235, 145, 215} if win_lit else rl.Color{28, 34, 50, 180}
	lw := rl.Vector3{pos.x - w * 0.5 - 0.028, pos.y + h * 0.65, pos.z + d * 0.08}
	rw := rl.Vector3{pos.x + w * 0.5 + 0.028, pos.y + h * 0.65, pos.z + d * 0.08}
	rl.DrawCube(lw, 0.056, h * 0.25, d * 0.30, win_col)
	rl.DrawCube(rw, 0.056, h * 0.25, d * 0.30, win_col)
	if win_lit {
		glow := rl.Color{255, 235, 145, 28}
		rl.DrawCube(lw, 0.08, h * 0.32, d * 0.38, glow)
		rl.DrawCube(rw, 0.08, h * 0.32, d * 0.38, glow)
	}
	if !occupied {
		x1 := pos.x - w * 0.25; x2 := pos.x + w * 0.25
		mz := pos.z - d * 0.5 - 0.05; my := pos.y + h * 0.5
		rl.DrawLine3D({x1, my - h*0.2, mz}, {x2, my + h*0.2, mz}, {50, 55, 70, 80})
		rl.DrawLine3D({x2, my - h*0.2, mz}, {x1, my + h*0.2, mz}, {50, 55, 70, 80})
	}
}

// ---------------------------------------------------------------------------
// Zone landmarks — unique building per zone type
// ---------------------------------------------------------------------------

draw_zone_landmark :: proc(pos: rl.Vector3, name: cstring, col: rl.Color, tick: f64, night: bool) {
	switch name {
	case "Market District":     draw_market_bazaar(pos, col, tick)
	case "Residential Quarter": draw_community_well(pos, tick)
	case "The Keep":            draw_keep_tower(pos, col, tick, night)
	case "The Archive":         draw_archive_spire(pos, col, night)
	case "The Null Quarter":    draw_null_monument(pos, tick)
	case "The Jail":            draw_jail_watchtower(pos, col, night)
	}
}

// Market District — covered bazaar with stalls and awning
draw_market_bazaar :: proc(pos: rl.Vector3, col: rl.Color, tick: f64) {
	// Central canopy on 4 poles
	pole_xs := [2]f32{-0.85, 0.85}
	pole_zs := [2]f32{-0.65, 0.65}
	for px in pole_xs {
		for pz in pole_zs {
			rl.DrawCube({pos.x + px, pos.y + 0.85, pos.z + pz}, 0.09, 1.7, 0.09, {40, 48, 64, 255})
		}
	}
	awning := col; awning.a = 210
	rl.DrawCube({pos.x, pos.y + 1.88, pos.z}, 2.0, 0.07, 1.5, awning)
	rl.DrawCubeWires({pos.x, pos.y + 1.88, pos.z}, 2.0, 0.07, 1.5, {col.r, col.g, col.b, 100})

	// Counter / display table
	rl.DrawCube({pos.x, pos.y + 0.55, pos.z - 0.58}, 1.5, 0.1, 0.22, {36, 44, 58, 255})
	// Goods on counter — small colored spheres
	goods_cols := [3]rl.Color{{200, 80, 60, 255}, {60, 180, 80, 255}, {220, 180, 60, 255}}
	for gi in 0..<3 {
		rl.DrawSphere({pos.x - 0.4 + f32(gi) * 0.4, pos.y + 0.68, pos.z - 0.58}, 0.08, goods_cols[gi])
	}
	// Hanging banner
	rl.DrawCube({pos.x, pos.y + 1.6, pos.z - 0.72}, 0.8, 0.5, 0.03, {col.r, col.g, col.b, 160})
}

// Residential Quarter — stone well + tree
draw_community_well :: proc(pos: rl.Vector3, tick: f64) {
	rl.DrawCylinder({pos.x, pos.y, pos.z}, 0.45, 0.58, 0.48, 12, {36, 44, 58, 255})
	rl.DrawCylinderWires({pos.x, pos.y, pos.z}, 0.45, 0.58, 0.48, 12, {60, 74, 100, 200})
	rl.DrawCylinder({pos.x, pos.y + 0.44, pos.z}, 0.56, 0.56, 0.06, 12, {30, 38, 52, 255})
	// Posts + beam
	rl.DrawCube({pos.x - 0.52, pos.y + 0.85, pos.z}, 0.08, 0.68, 0.08, {44, 54, 68, 255})
	rl.DrawCube({pos.x + 0.52, pos.y + 0.85, pos.z}, 0.08, 0.68, 0.08, {44, 54, 68, 255})
	rl.DrawCube({pos.x, pos.y + 1.18, pos.z}, 1.15, 0.07, 0.07, {40, 50, 65, 255})
	// Bucket dangling
	bucket_y := pos.y + 0.65 + f32(math.sin_f64(tick * 0.5)) * 0.05
	rl.DrawSphere({pos.x, bucket_y, pos.z}, 0.11, {50, 130, 200, 180})

	// Tree nearby
	tree_x := pos.x + 1.6
	tree_z := pos.z - 0.8
	rl.DrawCylinder({tree_x, pos.y, tree_z}, 0.08, 0.12, 1.4, 6, {36, 42, 52, 255})
	rl.DrawSphere({tree_x, pos.y + 1.85, tree_z}, 0.6, {35, 75, 45, 200})
	rl.DrawSphere({tree_x + 0.3, pos.y + 1.6, tree_z - 0.2}, 0.38, {30, 65, 40, 180})
}

// The Keep — fortress watch tower with battlements and beacon
draw_keep_tower :: proc(pos: rl.Vector3, col: rl.Color, tick: f64, night: bool) {
	// Base platform
	rl.DrawCube({pos.x, pos.y - 0.05, pos.z}, 2.8, 0.1, 2.8, {26, 32, 46, 255})
	// Tower walls
	rl.DrawCylinder({pos.x, pos.y, pos.z}, 0.85, 0.95, 4.0, 8, {36, 44, 58, 255})
	rl.DrawCylinderWires({pos.x, pos.y, pos.z}, 0.85, 0.95, 4.0, 8, col)
	// Battlements (8 merlons)
	for bi in 0..<8 {
		angle := f64(bi) * math.PI * 2.0 / 8.0
		bx    := pos.x + f32(math.cos_f64(angle)) * f32(0.88)
		bz    := pos.z + f32(math.sin_f64(angle)) * f32(0.88)
		rl.DrawCube({bx, pos.y + 4.2, bz}, 0.24, 0.42, 0.24, {30, 38, 52, 255})
	}
	// Gate
	rl.DrawCube({pos.x, pos.y + 0.85, pos.z - 0.96}, 0.58, 1.7, 0.2, {16, 20, 30, 255})
	rl.DrawCubeWires({pos.x, pos.y + 0.85, pos.z - 0.96}, 0.58, 1.7, 0.2, col)
	// Portcullis bars
	for bi in 0..<3 {
		bx := pos.x - 0.2 + f32(bi) * 0.2
		rl.DrawCube({bx, pos.y + 0.85, pos.z - 0.96}, 0.04, 1.6, 0.04, {40, 50, 65, 255})
	}
	// Beacon fire on top
	beacon_col := rl.Color{255, 180, 40, 220} if night else rl.Color{100, 120, 160, 120}
	pulse := f32(math.sin_f64(tick * 3.0)) * 0.5 + 0.5
	rl.DrawSphere({pos.x, pos.y + 4.55, pos.z}, 0.18 + pulse * 0.06, beacon_col)
	if night { rl.DrawSphere({pos.x, pos.y + 4.55, pos.z}, 0.35 + pulse * 0.1, {255, 160, 40, 40}) }
	// Flying flag
	flag_y := pos.y + 5.0 + f32(math.sin_f64(tick * 2.0)) * 0.06
	rl.DrawCube({pos.x + 0.12, flag_y, pos.z}, 0.04, 0.5, 0.04, {44, 54, 70, 255})
	rl.DrawCube({pos.x + 0.22, flag_y + 0.18, pos.z}, 0.28, 0.3, 0.04, col)
}

// The Archive — tall library spire with dome and lit windows
draw_archive_spire :: proc(pos: rl.Vector3, col: rl.Color, night: bool) {
	rl.DrawCube({pos.x, pos.y - 0.05, pos.z}, 2.5, 0.1, 2.5, {22, 28, 42, 255})
	// Steps
	rl.DrawCube({pos.x, pos.y + 0.03, pos.z - 1.1}, 0.9, 0.06, 0.3, {28, 35, 50, 255})
	rl.DrawCube({pos.x, pos.y + 0.08, pos.z - 0.92}, 0.75, 0.06, 0.22, {32, 40, 56, 255})
	// Main tower body
	rl.DrawCube({pos.x, pos.y + 2.2, pos.z}, 1.1, 4.4, 1.1, {40, 50, 65, 255})
	rl.DrawCubeWires({pos.x, pos.y + 2.2, pos.z}, 1.1, 4.4, 1.1, col)
	// Buttresses
	rl.DrawCube({pos.x - 0.72, pos.y + 1.5, pos.z}, 0.22, 3.0, 0.65, {34, 42, 56, 255})
	rl.DrawCube({pos.x + 0.72, pos.y + 1.5, pos.z}, 0.22, 3.0, 0.65, {34, 42, 56, 255})
	// Dome cap
	rl.DrawSphere({pos.x, pos.y + 4.7, pos.z}, 0.62, col)
	rl.DrawSphereWires({pos.x, pos.y + 4.7, pos.z}, 0.64, 8, 8, {col.r, col.g, col.b, 70})
	// Spire tip
	rl.DrawCylinder({pos.x, pos.y + 5.3, pos.z}, 0, 0.1, 0.7, 4, {col.r, col.g, col.b, 200})
	// Lit windows per floor
	win_c := rl.Color{255, 235, 145, 200} if night else rl.Color{255, 235, 145, 90}
	win_ys := [3]f32{1.0, 2.3, 3.5}
	for wy in win_ys {
		rl.DrawCube({pos.x - 0.56, pos.y + wy, pos.z}, 0.055, 0.38, 0.30, win_c)
		rl.DrawCube({pos.x + 0.56, pos.y + wy, pos.z}, 0.055, 0.38, 0.30, win_c)
		if night {
			g := rl.Color{255, 235, 145, 30}
			rl.DrawCube({pos.x - 0.6, pos.y + wy, pos.z}, 0.08, 0.5, 0.42, g)
			rl.DrawCube({pos.x + 0.6, pos.y + wy, pos.z}, 0.08, 0.5, 0.42, g)
		}
	}
}

// The Null Quarter — crumbled obelisk, rubble, decay
draw_null_monument :: proc(pos: rl.Vector3, tick: f64) {
	// Base rubble ring
	for ri in 0..<6 {
		angle := f64(ri) * math.PI * 2.0 / 6.0 + 0.3
		rx    := pos.x + f32(math.cos_f64(angle)) * 0.7
		rz    := pos.z + f32(math.sin_f64(angle)) * 0.7
		rs    := 0.1 + f32(ri % 3) * 0.06
		rl.DrawCube({rx, pos.y + 0.04, rz}, rs, 0.08, rs * 0.8, {18, 22, 30, 255})
	}
	// Lower column (intact)
	rl.DrawCylinder({pos.x, pos.y, pos.z}, 0.28, 0.38, 1.6, 6, {20, 24, 32, 255})
	rl.DrawCylinderWires({pos.x, pos.y, pos.z}, 0.28, 0.38, 1.6, 6, {35, 42, 55, 130})
	// Upper column — broken, slightly offset
	rl.DrawCylinder({pos.x + 0.14, pos.y + 1.6, pos.z + 0.08}, 0.22, 0.26, 0.9, 6, {16, 20, 28, 255})
	// Floating particle — the null anomaly
	float_y := pos.y + 2.8 + f32(math.sin_f64(tick * 0.8)) * 0.12
	anom_r  := f32(0.12) + f32(math.sin_f64(tick * 2.2)) * 0.03
	rl.DrawSphere({pos.x, float_y, pos.z}, anom_r, {80, 85, 100, 180})
	rl.DrawSphereWires({pos.x, float_y, pos.z}, anom_r + 0.05, 4, 4, {80, 85, 100, 60})
}

// The Jail — watchtower with iron bars
draw_jail_watchtower :: proc(pos: rl.Vector3, col: rl.Color, night: bool) {
	// Base
	rl.DrawCube({pos.x, pos.y - 0.05, pos.z}, 2.2, 0.1, 2.2, {20, 24, 34, 255})
	// Heavy outer wall
	rl.DrawCube({pos.x, pos.y + 1.5, pos.z}, 1.8, 3.0, 1.8, {30, 36, 48, 255})
	rl.DrawCubeWires({pos.x, pos.y + 1.5, pos.z}, 1.8, 3.0, 1.8, col)
	// Iron bars on front
	for bi in 0..<5 {
		bx := pos.x - 0.7 + f32(bi) * 0.35
		rl.DrawCube({bx, pos.y + 0.85, pos.z - 0.9}, 0.05, 1.7, 0.05, {45, 52, 65, 255})
	}
	// Horizontal bar
	rl.DrawCube({pos.x, pos.y + 1.2, pos.z - 0.9}, 1.55, 0.05, 0.05, {40, 48, 62, 255})
	// Top parapet
	rl.DrawCube({pos.x, pos.y + 3.1, pos.z}, 2.0, 0.2, 2.0, {26, 32, 44, 255})
	// Warning light
	warn_c := rl.Color{220, 60, 40, 200} if night else rl.Color{80, 50, 50, 180}
	pulse  := f32(math.sin_f64(f64(pos.x) * 3.14)) * 0.5 + 0.5
	rl.DrawSphere({pos.x, pos.y + 3.4, pos.z}, 0.15, warn_c)
	if night { rl.DrawSphere({pos.x, pos.y + 3.4, pos.z}, 0.28 + pulse*0.06, {220, 60, 40, 35}) }
}

// ---------------------------------------------------------------------------
// Citizen figure
// ---------------------------------------------------------------------------

draw_citizen_figure :: proc(base: rl.Vector3, c: eng.Citizen, is_sel: bool, tick: f64, idx: int) {
	body_r    := f32(0.12)
	in_danger := c.hunger >= 80 || c.sleep <= 20

	rl.DrawCircle3D({base.x, 0.008, base.z}, 0.20, {1, 0, 0}, 90, {0, 0, 0, 55})

	sleeping := c.behavior == .Sleeping

	foot, shoulder, head: rl.Vector3
	if sleeping {
		// Lying down — capsule runs along X axis
		lie_y    := base.y + 0.16
		foot      = {base.x - 0.28, lie_y, base.z}
		shoulder  = {base.x + 0.28, lie_y, base.z}
		head      = {base.x + 0.42, lie_y, base.z}
	} else {
		foot_y   := base.y + 0.18
		body_h   := f32(0.55)
		head_r   := f32(0.155)
		foot      = {base.x, foot_y, base.z}
		shoulder  = {base.x, foot_y + body_h, base.z}
		head      = {base.x, foot_y + body_h + head_r + 0.04, base.z}
	}

	col := c.color
	if sleeping {
		// Dim sleeping citizens slightly
		col = rl.Color{u8(f32(c.color.r) * 0.6), u8(f32(c.color.g) * 0.6), u8(f32(c.color.b) * 0.6), 255}
	}
	rl.DrawCapsule(foot, shoulder, body_r, 4, 4, col)
	rl.DrawSphere(head, 0.155, col)

	// Behavior dot on chest
	if !sleeping {
		foot_y := base.y + 0.18
		chest := rl.Vector3{base.x, foot_y + 0.55 * 0.55, base.z - body_r - 0.01}
		rl.DrawSphere(chest, 0.04, behavior_dot_color(c.behavior))
	}

	if in_danger && !sleeping {
		pt := f32(math.sin_f64(tick * 4.5 + f64(idx) * 0.8)) * 0.5 + 0.5
		cy := base.y + 0.18 + 0.55 * 0.4
		rl.DrawCircle3D({base.x, cy, base.z}, 0.28 + pt*0.16, {1,0,0}, 90, {225, 60, 55, u8(55 + pt*110)})
	}
	if c.stress_ticks >= 3 && !sleeping {
		cy := base.y + 0.18 + 0.55 * 0.4
		sr := f32(0.48) + f32(math.sin_f64(tick * 2.5 + f64(idx) * 1.1)) * 0.08
		rl.DrawCircle3D({base.x, cy, base.z}, sr, {1,0,0}, 90, {225, 60, 55, 32})
	}
	if is_sel {
		rl.DrawCircle3D(foot, 0.27, {1,0,0}, 90, {255, 255, 255, 210})
		rl.DrawCircle3D(head, 0.22, {1,0,0}, 90, {255, 255, 255, 160})
		rl.DrawLine3D({base.x, 0.015, base.z}, foot, {255, 255, 255, 70})
	}
}

// draw_social_links — faint thread lines between all socializing citizen pairs
draw_social_links :: proc(citizens: []eng.Citizen) {
	for &ca, ai in citizens {
		if ca.behavior != .Socializing { continue }
		for &cb, bi in citizens {
			if bi <= ai { continue }
			if cb.behavior != .Socializing { continue }
			mid_y := f32(0.8)
			rl.DrawLine3D(
				{ca.world_pos.x, mid_y, ca.world_pos.z},
				{cb.world_pos.x, mid_y, cb.world_pos.z},
				{200, 95, 255, 55},
			)
		}
	}
}

// ---------------------------------------------------------------------------
// 2D screen-space overlays
// ---------------------------------------------------------------------------

draw_overlays :: proc(s: ^eng.GameState) {
	for &z in s.zones {
		lp := rl.Vector3{z.pos.x + z.size.x*0.5, 5.2, z.pos.z + z.size.z*0.5}
		sp := rl.GetWorldToScreen(lp, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		pop, stressed, avg_hp := zone_stats(s, z)
		stat_str := fmt.ctprintf("(%d) HP%.0f", pop, avg_hp)
		sw := i32(0)
		if pop > 0 { sw = i32(f32(stressed) / f32(pop) * 30) }

		nw      := rl.MeasureText(z.name, 12)
		pw      := rl.MeasureText(stat_str, 9)
		total_w := max(nw, pw) + 18
		bx      := i32(sp.x) - total_w / 2
		by      := i32(sp.y) - 16

		rl.DrawRectangle(bx, by, total_w, 32, {0, 0, 0, 180})
		rl.DrawRectangleLines(bx, by, total_w, 32, z.color)
		rl.DrawText(z.name, bx + 8, by + 4, 12, z.color)
		pop_c := rl.Color{130, 150, 175, 200} if pop > 0 else rl.Color{225, 60, 55, 255}
		rl.DrawText(stat_str, bx + 8, by + 19, 9, pop_c)
		if pop > 0 && sw > 0 {
			rl.DrawRectangle(bx, by + 30, sw, 2, {225, 60, 55, 200})
		}
	}

	for &c, ci in s.citizens {
		tag_pos := rl.Vector3{c.world_pos.x, 2.0, c.world_pos.z}
		sp := rl.GetWorldToScreen(tag_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		in_danger := c.hunger >= 80 || c.sleep <= 20
		is_sel    := i32(ci) == s.selected
		name_col  := c.color
		if in_danger { name_col = {225, 60, 55, 255} }

		nw := rl.MeasureText(c.name, 11)
		sx := i32(sp.x) - nw / 2
		sy := i32(sp.y)

		if is_sel {
			rl.DrawRectangle(sx - 4, sy - 2, nw + 8, 15, {0, 0, 0, 200})
			rl.DrawRectangleLines(sx - 4, sy - 2, nw + 8, 15, name_col)
		}
		rl.DrawText(c.name, sx, sy, 11, name_col)

		tag_y := sy - 13
		if c.health <= 30 {
			rl.DrawText("HP!", sx, tag_y, 9, {225, 60, 55, 230}); tag_y -= 11
		}
		if c.hunger >= 88 {
			rl.DrawText("STARVING", sx, tag_y, 9, {225, 145, 35, 220}); tag_y -= 11
		} else if c.hunger >= 75 {
			rl.DrawText("HUNGRY", sx, tag_y, 9, {180, 120, 30, 180}); tag_y -= 11
		}
		if c.sleep <= 12 {
			rl.DrawText("EXHAUSTED", sx, tag_y, 9, {80, 155, 255, 220})
		} else if c.sleep <= 25 {
			rl.DrawText("TIRED", sx, tag_y, 9, {60, 120, 200, 180})
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
	case .Sleeping:    return {80,  155, 255, 255}
	case .Socializing: return {200, 95,  255, 255}
	case .Working:     return {65,  210, 90,  255}
	case .Wandering:   return {150, 170, 195, 255}
	case .Idle:        return {55,  65,  82,  255}
	}
	return {55, 65, 82, 255}
}
