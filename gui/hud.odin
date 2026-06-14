package gui

import rl   "vendor:raylib"
import eng  "../engine"
import      "core:fmt"
import      "core:math"

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

SCREEN_W :: i32(1280)
SCREEN_H :: i32(720)
PANEL_X  :: i32(880)
PANEL_W  :: SCREEN_W - PANEL_X

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

COL_BG       :: rl.Color{ 10,  13,  20, 255}
COL_BG_DARK  :: rl.Color{  6,   8,  14, 255}
COL_BG_MID   :: rl.Color{ 15,  19,  30, 255}
COL_BORDER   :: rl.Color{ 30,  48,  72, 255}
COL_BORDER_B :: rl.Color{ 45,  70, 110, 255}
COL_HEADER   :: rl.Color{ 12,  16,  26, 255}
COL_SEL      :: rl.Color{ 22,  42,  70, 255}
COL_SEL_HOV  :: rl.Color{ 18,  32,  55, 255}
COL_DIVIDER  :: rl.Color{ 22,  30,  45, 255}
COL_TEXT     :: rl.Color{210, 222, 238, 255}
COL_TEXT_DIM :: rl.Color{120, 138, 162, 255}
COL_DIM      :: rl.Color{ 80,  98, 120, 255}
COL_ACCENT   :: rl.Color{ 55, 148, 235, 255}
COL_ACCENT_D :: rl.Color{ 35,  90, 160, 255}
COL_DANGER   :: rl.Color{230,  65,  55, 255}
COL_WARN     :: rl.Color{225, 145,  35, 255}
COL_OK       :: rl.Color{ 65, 210,  90, 255}

event_color :: proc(kind: eng.EventKind) -> rl.Color {
	switch kind {
	case .Spawn:  return {  85, 215,  90, 255}
	case .Death:  return { 225,  60,  55, 255}
	case .Move:   return {  80, 170, 255, 255}
	case .Rename: return { 250, 190,  55, 255}
	case .Info:   return { 140, 155, 175, 255}
	}
	return rl.WHITE
}

behavior_label :: proc(b: eng.Behavior) -> cstring {
	switch b {
	case .Idle:        return "IDLE"
	case .Eating:      return "EATING"
	case .Sleeping:    return "SLEEPING"
	case .Socializing: return "SOCIALIZING"
	case .Working:     return "WORKING"
	case .Wandering:   return "WANDERING"
	}
	return "IDLE"
}

// ---------------------------------------------------------------------------
// Main draw proc
// ---------------------------------------------------------------------------

Draw_Hud :: proc(s: ^eng.GameState) {
	px  := PANEL_X
	pw  := PANEL_W
	sh  := SCREEN_H

	// Panel background
	rl.DrawRectangle(px, 0, pw, sh, COL_BG)
	rl.DrawRectangle(px, 0, 2,  sh, COL_BORDER)  // left border — slightly thicker

	y := i32(0)

	// ==========================================================================
	// HEADER
	// ==========================================================================
	hdr_h := i32(122)
	rl.DrawRectangle(px + 2, 0, pw - 2, hdr_h, COL_HEADER)
	rl.DrawRectangle(px + 2, hdr_h - 1, pw - 2, 1, COL_BORDER)

	// Title — world name from config
	wname  := s.world_name if s.world_name != nil else "ROOT DIRECTORY"
	tw     := rl.MeasureText(wname, 14)
	rl.DrawText(wname, px + (pw - tw) / 2, 6, 14, COL_ACCENT)
	sub    := cstring("DIRECTORY CITIZENS")
	sw2    := rl.MeasureText(sub, 9)
	rl.DrawText(sub, px + (pw - sw2) / 2, 22, 9, COL_DIM)

	// Eye status row
	blink_on := (i32(s.tick) % 2) == 0 && !s.paused
	dot_col  := COL_OK if blink_on else COL_DIM
	rl.DrawCircle(px + 18, 36, 4, dot_col)
	sim_tick  := int(s.tick / s.tick_rate) if s.tick_rate > 0 else 0
	world_day := sim_tick / 24 + 1
	world_hr  := sim_tick % 24
	speed_tag := cstring("")
	if s.paused          { speed_tag = "  PAUSED" }
	else if s.speed >= 4 { speed_tag = "  x4" }
	else if s.speed >= 2 { speed_tag = "  x2" }
	season      := eng.season_from_tick(sim_tick)
	season_str  := eng.season_name(season)
	season_col  := season_color(season)
	base_str    := fmt.ctprintf("THE EYE  ·  %d pop  ·  Day %d  %02d:00  ", len(s.citizens), world_day, world_hr)
	bw          := rl.MeasureText(base_str, 10)
	rl.DrawText(base_str, px + 28, 30, 10, COL_DIM)
	rl.DrawText(season_str, px + 28 + bw, 30, 10, season_col)
	if speed_tag != cstring("") {
		sw3 := rl.MeasureText(season_str, 10)
		rl.DrawText(speed_tag, px + 28 + bw + sw3, 30, 10, COL_DIM)
	}

	// Population sparkline + deaths/peak — bottom-right of header
	spark_w   := i32(64)
	spark_h   := i32(16)
	spark_x   := px + pw - spark_w - 8
	spark_y   := i32(30)
	draw_pop_sparkline(spark_x, spark_y, spark_w, spark_h, s)
	deaths_str := fmt.ctprintf("d:%d pk:%d", s.total_deaths, s.max_pop_seen)
	dw         := rl.MeasureText(deaths_str, 8)
	rl.DrawText(deaths_str, spark_x - dw - 6, spark_y + 4, 8, COL_TEXT_DIM)

	// Unrest bar
	unrest_y  := i32(52)
	unrest_lw := i32(46)
	bar_x     := px + 2 + unrest_lw
	bar_w     := pw - 4 - unrest_lw - 32
	bar_h     := i32(10)

	rl.DrawText("UNREST", px + 8, unrest_y + 1, 10, COL_DIM)

	// Bar track
	rl.DrawRectangle(bar_x, unrest_y, bar_w, bar_h, {18, 22, 34, 255})

	// Bar fill — color lerps blue → red as unrest rises
	fill_w := i32(f32(bar_w) * s.unrest / 100)
	t      := s.unrest / 100.0
	ur_col := rl.Color{
		u8(f32(COL_ACCENT.r) * (1 - t) + f32(COL_DANGER.r) * t),
		u8(f32(COL_ACCENT.g) * (1 - t) + f32(COL_DANGER.g) * t),
		u8(f32(COL_ACCENT.b) * (1 - t) + f32(COL_DANGER.b) * t),
		255,
	}
	if fill_w > 0 {
		rl.DrawRectangle(bar_x, unrest_y, fill_w, bar_h, ur_col)
	}
	rl.DrawRectangleLines(bar_x, unrest_y, bar_w, bar_h, COL_BORDER)

	// Tick marks at 30, 60, 90 (event thresholds)
	thresholds := [3]f32{30, 60, 90}
	for threshold in thresholds {
		mx := bar_x + i32(f32(bar_w) * threshold / 100)
		rl.DrawRectangle(mx, unrest_y - 1, 1, bar_h + 2, {80, 80, 100, 180})
	}

	unrest_val := fmt.ctprintf("%.0f", s.unrest)
	rl.DrawText(unrest_val, bar_x + bar_w + 6, unrest_y + 1, 10, ur_col)

	// Revolt warning
	if s.unrest >= 90 {
		pulse := u8(140 + i32(math.sin_f64(s.tick * 6) * 80))
		rl.DrawText("REVOLT IMMINENT", px + 8, unrest_y + 16, 9, rl.Color{COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, pulse})
	}

	// Day/night arc clock — sun or moon on a semicircle arc
	draw_day_clock(px + pw - 44, 14, 28, world_hr, world_day)

	// Zone overview strip — one chip per zone showing pop + stress
	zone_strip_y := i32(94)
	rl.DrawRectangle(px + 2, zone_strip_y, pw - 2, 27, {10, 13, 20, 255})
	rl.DrawRectangle(px + 2, zone_strip_y, pw - 2, 1, COL_BORDER)

	if len(s.zones) > 0 {
		chip_w := (pw - 4) / i32(len(s.zones))
		for zi in 0..<len(s.zones) {
			z   := &s.zones[zi]
			cx  := px + 2 + i32(zi) * chip_w
			// Count pop + stress for this zone
			pop, stressed := 0, 0
			for &c in s.citizens {
				if c.zone == z.name {
					pop += 1
					if c.hunger >= 80 || c.sleep <= 20 { stressed += 1 }
				}
			}
			// Chip background
			chip_bg := rl.Color{z.color.r / 8, z.color.g / 8, z.color.b / 8, 255}
			rl.DrawRectangle(cx, zone_strip_y + 1, chip_w - 1, 25, chip_bg)

			// Zone name — first word only to fit
			name_str := z.name
			rl.DrawText(name_str, cx + 4, zone_strip_y + 4, 8, z.color)

			// Pop + stress fraction
			stat_str := fmt.ctprintf("%d♟", pop)
			if stressed > 0 { stat_str = fmt.ctprintf("%d♟ %d!", pop, stressed) }
			stat_col := COL_DANGER if stressed > 0 else COL_DIM
			rl.DrawText(stat_str, cx + 4, zone_strip_y + 15, 8, stat_col)

			// Divider
			if zi < len(s.zones) - 1 {
				rl.DrawRectangle(cx + chip_w - 1, zone_strip_y + 2, 1, 23, COL_BORDER)
			}
		}
	}

	y = hdr_h + 8

	// ==========================================================================
	// CITIZEN LIST
	// ==========================================================================
	draw_section_header("POPULATION", px, pw, y)
	y += 20

	item_h    := i32(52)
	vis_count := i32(4)
	list_h    := item_h * vis_count

	mouse := rl.GetMousePosition()
	if mouse.x > f32(px) {
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			s.citizen_scroll -= i32(wheel)
			max_s := i32(len(s.citizens)) - vis_count
			if max_s < 0     { max_s = 0 }
			if s.citizen_scroll < 0    { s.citizen_scroll = 0 }
			if s.citizen_scroll > max_s { s.citizen_scroll = max_s }
		}
	}

	rl.BeginScissorMode(px + 2, y, pw - 2, list_h)
	for idx := s.citizen_scroll; idx < s.citizen_scroll + vis_count && idx < i32(len(s.citizens)); idx += 1 {
		c    := &s.citizens[idx]
		iy   := y + (idx - s.citizen_scroll) * item_h
		isel := idx == s.selected
		hovered := rl.CheckCollisionPointRec(mouse, rl.Rectangle{f32(px + 2), f32(iy), f32(pw - 2), f32(item_h)})

		// Row background
		bg := COL_SEL if isel else (COL_SEL_HOV if hovered else rl.Color{0, 0, 0, 0})
		rl.DrawRectangle(px + 2, iy, pw - 2, item_h, bg)

		// Left danger strip (4px) — red if stressed, dim otherwise
		in_danger := c.hunger >= 80 || c.sleep <= 20
		strip_col := COL_DANGER if (in_danger && c.stress_ticks > 0) else (COL_WARN if in_danger else COL_BORDER)
		rl.DrawRectangle(px + 2, iy, 4, item_h, strip_col)

		// Avatar circle
		avatar_x := px + 22
		avatar_y := iy + item_h / 2 - 8
		rl.DrawCircle(avatar_x, avatar_y + 6, 7, c.color)
		if in_danger {
			// Small pulse ring
			pulse_r := f32(9) + f32(math.sin_f64(s.tick * 4 + f64(idx) * 0.7)) * 1.5
			rl.DrawCircleLines(avatar_x, avatar_y + 6, pulse_r, rl.Color{COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, 120})
		}

		// Name
		name_x := px + 36
		rl.DrawText(c.name, name_x, iy + 8, 13, COL_TEXT)

		// Behavior label
		blabel := behavior_label(c.behavior)
		blw    := rl.MeasureText(blabel, 9)
		blab_x := px + pw - blw - 10
		b_col  := behavior_color(c.behavior)
		rl.DrawText(blabel, blab_x, iy + 9, 9, b_col)

		// Zone (dim, small)
		rl.DrawText(c.zone, name_x, iy + 26, 10, COL_DIM)

		// Mini stat row — 3 small bars: health, hunger, sleep
		mini_y := iy + item_h - 14
		mini_x := name_x
		mini_w := i32(60)

		draw_mini_bar(mini_x,          mini_y, mini_w, c.health, {65, 210, 90, 200})
		draw_mini_bar(mini_x + 66,     mini_y, mini_w, 100 - c.hunger, {225, 145, 35, 200})  // inverted: full = not hungry
		draw_mini_bar(mini_x + 132,    mini_y, mini_w, c.sleep, {90, 155, 255, 200})

		rl.DrawText("HP", mini_x,       mini_y - 9, 8, COL_DIM)
		rl.DrawText("FD", mini_x + 66,  mini_y - 9, 8, COL_DIM)
		rl.DrawText("ZZ", mini_x + 132, mini_y - 9, 8, COL_DIM)

		// Click to select (and enable follow)
		if hovered && rl.IsMouseButtonPressed(.LEFT) {
			if s.selected == idx {
				s.selected  = -1
				s.follow_sel = false
			} else {
				s.selected  = idx
				s.follow_sel = true
			}
		}

		rl.DrawRectangle(px + 6, iy + item_h - 1, pw - 8, 1, COL_DIVIDER)
	}
	rl.EndScissorMode()

	// Scroll indicator
	if i32(len(s.citizens)) > vis_count {
		total     := i32(len(s.citizens))
		thumb_h   := list_h * vis_count / total
		thumb_y   := y + (list_h - thumb_h) * s.citizen_scroll / (total - vis_count)
		rl.DrawRectangle(px + pw - 4, y, 2, list_h, COL_BORDER)
		rl.DrawRectangle(px + pw - 4, thumb_y, 2, thumb_h, COL_ACCENT)
	}

	y += list_h + 8

	// ==========================================================================
	// SELECTED CITIZEN DETAILS
	// ==========================================================================
	detail_h := i32(210)
	rl.DrawRectangle(px + 2, y, pw - 2, detail_h, COL_BG_DARK)
	rl.DrawRectangle(px + 2, y, pw - 2, 1, COL_BORDER)
	rl.DrawRectangle(px + 2, y + detail_h - 1, pw - 2, 1, COL_BORDER)

	draw_section_header("SELECTED", px, pw, y + 6)

	if s.selected >= 0 && int(s.selected) < len(s.citizens) {
		c  := &s.citizens[s.selected]
		dy := y + 26

		// Portrait + name block
		rl.DrawCircle(px + 26, dy + 10, 12, c.color)
		in_danger := c.hunger >= 80 || c.sleep <= 20
		if in_danger {
			pulse_r := f32(15) + f32(math.sin_f64(s.tick * 4)) * 2
			rl.DrawCircleLines(px + 26, dy + 10, pulse_r, rl.Color{COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, 100})
		}

		rl.DrawText(c.name,   px + 46, dy,      15, COL_TEXT)
		rl.DrawText(c.zone,   px + 46, dy + 19, 10, COL_DIM)
		if c.status != nil {
			rl.DrawText(c.status, px + 46, dy + 33, 10, COL_TEXT_DIM)
		}

		// Behavior badge
		blabel := behavior_label(c.behavior)
		b_col  := behavior_color(c.behavior)
		blw    := rl.MeasureText(blabel, 10)
		badge_x := px + pw - blw - 18
		rl.DrawRectangle(badge_x - 4, dy - 1, blw + 8, 14, rl.Color{b_col.r, b_col.g, b_col.b, 30})
		rl.DrawRectangleLines(badge_x - 4, dy - 1, blw + 8, 14, rl.Color{b_col.r, b_col.g, b_col.b, 80})
		rl.DrawText(blabel, badge_x, dy + 1, 10, b_col)

		// Stress ticks indicator
		if c.stress_ticks > 0 {
			stress_label := fmt.ctprintf("stress ×%.0f", c.stress_ticks)
			rl.DrawText(stress_label, px + 46, dy + 47, 9, COL_DANGER)
			for ti := i32(0); ti < i32(min(c.stress_ticks, 5)); ti += 1 {
				dot_col2 := COL_DANGER if ti < 3 else rl.Color{255, 30, 30, 255}
				rl.DrawCircle(px + 46 + 86 + ti * 10, dy + 51, 3, dot_col2)
			}
		}

		stat_top := dy + 64
		draw_stat_bar_ex(px + 10, stat_top,       pw - 20, "Health", c.health, {65,  210,  90, 255}, 20,  false)
		draw_stat_bar_ex(px + 10, stat_top + 34,  pw - 20, "Hunger", c.hunger, {225, 145,  35, 255}, 80,  true)
		draw_stat_bar_ex(px + 10, stat_top + 68,  pw - 20, "Sleep",  c.sleep,  { 90, 155, 255, 255}, 20,  false)
		draw_stat_bar_ex(px + 10, stat_top + 102, pw - 20, "Social", c.social, {200,  95, 255, 255}, 20,  false)
	} else {
		msg := cstring("— select a citizen —")
		mw  := rl.MeasureText(msg, 12)
		rl.DrawText(msg, px + (pw - mw) / 2, y + detail_h / 2 - 6, 12, COL_DIM)
	}

	y += detail_h + 8

	// ==========================================================================
	// MINIMAP
	// ==========================================================================
	mm_h   := i32(116)
	mm_y   := sh - mm_h - 2
	mm_x   := px + 2
	mm_w   := pw - 4

	rl.DrawRectangle(mm_x, mm_y, mm_w, mm_h, {6, 8, 14, 255})
	rl.DrawRectangle(mm_x, mm_y, mm_w, 1, COL_BORDER)
	draw_section_header("MAP", px, pw, mm_y + 4)

	// World bounds → minimap rect
	WX0 :: f32(-16); WX1 :: f32(18)
	WZ0 :: f32(-11); WZ1 :: f32(24)
	map_x := mm_x + 4;  map_w2 := mm_w - 8
	map_yy := mm_y + 20; map_h2 := mm_h - 24

	world_to_map :: proc(wx, wz: f32, mx, mw, my, mh: i32) -> (i32, i32) {
		tx := (wx - WX0) / (WX1 - WX0)
		tz := (wz - WZ0) / (WZ1 - WZ0)
		return mx + i32(tx * f32(mw)), my + i32(tz * f32(mh))
	}

	// Zone rectangles
	for &z in s.zones {
		zx1, zy1 := world_to_map(z.pos.x,            z.pos.z,            map_x, map_w2, map_yy, map_h2)
		zx2, zy2 := world_to_map(z.pos.x + z.size.x, z.pos.z + z.size.z, map_x, map_w2, map_yy, map_h2)
		zw := zx2 - zx1; zh := zy2 - zy1
		if zw < 2 { zw = 2 }; if zh < 2 { zh = 2 }
		bg := rl.Color{z.color.r / 7, z.color.g / 7, z.color.b / 7, 255}
		rl.DrawRectangle(zx1, zy1, zw, zh, bg)
		rl.DrawRectangleLines(zx1, zy1, zw, zh, rl.Color{z.color.r, z.color.g, z.color.b, 140})
	}

	// City center dot
	ccx, ccy := world_to_map(0, 0, map_x, map_w2, map_yy, map_h2)
	rl.DrawCircle(ccx, ccy, 2, {55, 148, 235, 200})

	// Citizen dots
	for &c in s.citizens {
		cdx, cdy := world_to_map(c.world_pos.x, c.world_pos.z, map_x, map_w2, map_yy, map_h2)
		in_danger := c.hunger >= 80 || c.sleep <= 20
		dc := rl.Color{COL_DANGER.r, COL_DANGER.g, COL_DANGER.b, 220} if in_danger else rl.Color{c.color.r, c.color.g, c.color.b, 220}
		rl.DrawCircle(cdx, cdy, 2, dc)
	}

	// ==========================================================================
	// EVENT LOG
	// ==========================================================================
	log_area := mm_y - y - 4
	if log_area < 30 { return }

	draw_section_header("EVENTS", px, pw, y)
	y += 20

	ev_h := i32(20)
	rl.BeginScissorMode(px + 2, y, pw - 4, log_area - 22)
	tick_rate := s.tick_rate if s.tick_rate > 0 else 2.0
	for i in 0..<len(s.events) {
		ev   := &s.events[i]
		ey   := y + i32(i) * ev_h
		col  := event_color(ev.kind)
		age  := u8(max(55, 255 - i * 20))
		fcol := rl.Color{col.r, col.g, col.b, age}
		dcol := rl.Color{COL_DIM.r, COL_DIM.g, COL_DIM.b, age / 2}

		// World timestamp: Day N HH:00
		ev_gtick  := int(ev.tick / tick_rate)
		ev_day    := ev_gtick / 24 + 1
		ev_hour   := ev_gtick % 24
		ts_str    := fmt.ctprintf("D%d %02d:00", ev_day, ev_hour)
		rl.DrawText(ts_str, px + 8, ey + 5, 8, dcol)

		rl.DrawCircle(px + 60, ey + ev_h / 2, 2, fcol)
		rl.DrawText(ev.text, px + 68, ey + 5, 9, fcol)
	}
	rl.EndScissorMode()
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

draw_section_header :: proc(label: cstring, px, pw, y: i32) {
	lw := rl.MeasureText(label, 10)
	rl.DrawText(label, px + 10, y + 1, 10, COL_ACCENT)
	rl.DrawRectangle(px + 10 + lw + 6, y + 6, pw - lw - 26, 1, COL_BORDER_B)
}

draw_mini_bar :: proc(x, y, w: i32, value: f32, col: rl.Color) {
	h := i32(4)
	rl.DrawRectangle(x, y, w, h, {20, 24, 36, 255})
	filled := i32(f32(w) * clamp(value, 0, 100) / 100)
	if filled > 0 { rl.DrawRectangle(x, y, filled, h, col) }
	rl.DrawRectangleLines(x, y, w, h, {35, 42, 60, 200})
}

// draw_stat_bar_ex — stat bar with a danger threshold tick mark.
// danger_at: the threshold value. danger_high: true if value >= threshold is bad (hunger), false if <= is bad.
draw_stat_bar_ex :: proc(x, y, w: i32, label: cstring, value: f32, bar_col: rl.Color, danger_at: f32, danger_high: bool) {
	label_w := i32(46)
	bar_h   := i32(11)
	bx      := x + label_w
	bw      := w - label_w - 38

	in_danger := (danger_high && value >= danger_at) || (!danger_high && value <= danger_at)
	lcol      := COL_DANGER if in_danger else COL_TEXT_DIM

	rl.DrawText(label, x, y + 1, 10, lcol)
	rl.DrawRectangle(bx, y, bw, bar_h, {16, 20, 30, 255})

	filled := i32(f32(bw) * clamp(value, 0, 100) / 100)
	fill_c := bar_col
	if in_danger {
		fill_c = COL_DANGER
	}
	if filled > 0 { rl.DrawRectangle(bx, y, filled, bar_h, fill_c) }

	// Danger threshold marker
	thresh_x := bx + i32(f32(bw) * danger_at / 100)
	rl.DrawRectangle(thresh_x, y - 1, 1, bar_h + 2, rl.Color{200, 200, 80, 120})

	rl.DrawRectangleLines(bx, y, bw, bar_h, {35, 45, 62, 255})

	val_str := fmt.ctprintf("%.0f", value)
	vcol    := COL_DANGER if in_danger else COL_TEXT
	rl.DrawText(val_str, bx + bw + 5, y + 1, 10, vcol)
}

// draw_day_clock — small semicircle with sun (day) or moon (night) on the arc.
// cx, cy = center of semicircle, r = radius, hour = 0-23.
draw_day_clock :: proc(cx, cy, r: i32, hour: int, day: int) {
	// Arc background (dim ring)
	for deg := i32(0); deg <= 180; deg += 6 {
		rad := f32(deg) * math.PI / 180
		ax  := cx + i32(f32(r) * math.cos_f32(rad))
		ay  := cy - i32(f32(r) * math.sin_f32(rad))
		rl.DrawCircle(ax, ay, 1, {30, 40, 58, 200})
	}
	// Horizon line
	rl.DrawLine(cx - r, cy, cx + r, cy, {28, 38, 55, 200})

	is_day  := hour >= 6 && hour < 20
	// Map hour to angle on the arc
	// Day:   hour 6→18 maps to 180°→0° (left to right across top)
	// Night: hour 18→6 (next day, 18→30) maps to 180°→0°
	angle_deg := f32(0)
	if is_day {
		t         := f32(hour - 6) / 12.0  // 0=6am, 1=6pm
		angle_deg  = 180 - t * 180
	} else {
		night_h := hour if hour >= 18 else hour + 24
		t        := f32(night_h - 18) / 12.0
		angle_deg = 180 - t * 180
	}
	rad := angle_deg * math.PI / 180
	bx  := cx + i32(f32(r) * math.cos_f32(rad))
	by  := cy - i32(f32(r) * math.sin_f32(rad))

	if is_day {
		rl.DrawCircle(bx, by, 5, {255, 230, 100, 240})
		rl.DrawCircleLines(bx, by, 7, {255, 230, 100, 60})
	} else {
		if by < cy {  // only draw moon above horizon
			rl.DrawCircle(bx, by, 4, {200, 215, 255, 220})
		}
		// Stars (static dots in the arc area)
		stars := [4][2]i32{{cx - 18, cy - 20}, {cx + 12, cy - 24}, {cx + 22, cy - 10}, {cx - 8, cy - 30}}
		for st in stars {
			twinkle := u8(140 + i32(math.sin_f64(f64(day)*1.3 + f64(st[0])*0.1) * 80))
			rl.DrawCircle(st[0], st[1], 1, {200, 215, 255, twinkle})
		}
	}
}

draw_pop_sparkline :: proc(x, y, w, h: i32, s: ^eng.GameState) {
	rl.DrawRectangle(x, y, w, h, {10, 13, 20, 200})
	rl.DrawRectangleLines(x, y, w, h, COL_BORDER)

	n     := len(s.pop_history)
	count := n if s.pop_hist_full else s.pop_hist_idx
	if count < 2 { return }

	// Find range
	peak := 1
	for i in 0..<count {
		idx := (s.pop_hist_idx - count + i + n) % n
		if s.pop_history[idx] > peak { peak = s.pop_history[idx] }
	}

	prev_px, prev_py := x, y + h - 1
	for i in 0..<count {
		idx  := (s.pop_hist_idx - count + i + n) % n
		val  := s.pop_history[idx]
		px2  := x + i32(i) * (w - 1) / i32(count - 1)
		py2  := y + h - 1 - i32(val) * (h - 2) / i32(peak)
		if i > 0 {
			frac   := f32(i) / f32(count - 1)
			line_c := rl.Color{
				u8(f32(COL_ACCENT.r) * frac + f32(COL_DANGER.r) * (1 - frac)),
				u8(f32(COL_ACCENT.g) * frac + f32(COL_DANGER.g) * (1 - frac)),
				u8(f32(COL_ACCENT.b) * frac + f32(COL_DANGER.b) * (1 - frac)),
				180,
			}
			rl.DrawLine(prev_px, prev_py, px2, py2, line_c)
		}
		prev_px = px2; prev_py = py2
	}

	// Current value dot
	cur  := len(s.citizens)
	cy   := y + h - 1 - i32(cur) * (h - 2) / i32(peak)
	rl.DrawCircle(x + w - 1, cy, 2, COL_ACCENT)
}

season_color :: proc(s: eng.Season) -> rl.Color {
	switch s {
	case .Spring: return {75,  210,  90, 255}   // fresh green
	case .Summer: return {255, 195,  45, 255}   // warm gold
	case .Autumn: return {225, 130,  40, 255}   // burnt orange
	case .Winter: return { 90, 175, 255, 255}   // cold blue
	}
	return COL_DIM
}

behavior_color :: proc(b: eng.Behavior) -> rl.Color {
	switch b {
	case .Eating:      return {220, 145,  40, 255}
	case .Sleeping:    return { 80, 155, 255, 255}
	case .Socializing: return {200,  95, 255, 255}
	case .Working:     return { 65, 210,  90, 255}
	case .Wandering:   return {150, 170, 195, 255}
	case .Idle:        return { 80,  98, 120, 255}
	}
	return COL_DIM
}
