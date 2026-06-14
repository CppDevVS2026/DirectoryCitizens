package gui

import rl   "vendor:raylib"
import eng  "../engine"
import      "core:fmt"
import      "core:math"

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

season_color :: proc(s: eng.Season) -> rl.Color {
	switch s {
	case .Spring: return { 85, 215,  90, 255}
	case .Summer: return {250, 220,  60, 255}
	case .Autumn: return {230, 120,  50, 255}
	case .Winter: return {120, 200, 255, 255}
	}
	return rl.WHITE
}

// ---------------------------------------------------------------------------
// Main draw proc
// ---------------------------------------------------------------------------

Draw_Hud :: proc(s: ^eng.GameState) {
	for _, &win in s.layout.windows {
		if !win.visible do continue
		draw_window_frame(win)
		switch win.id {
		case .Time:        draw_window_time(s, win)
		case .Directories: draw_window_directories(s, win)
		case .Citizens:    draw_window_citizens(s, win)
		case .Info:        draw_window_info(s, win)
		case .Events:      draw_window_events(s, win)
		}
	}
    
    Draw_Toasts(s)
}

draw_window_time :: proc(s: ^eng.GameState, win: Window) {
	px := i32(win.rect.x)
	pw := i32(win.rect.width)
	y  := i32(win.rect.y) + 20

	wname := s.world_name if s.world_name != nil else "ROOT DIRECTORY"
	tw    := rl.MeasureText(wname, 14)
	rl.DrawText(wname, px + (pw - tw) / 2, y + 6, 14, COL_ACCENT)

	sim_tick  := int(s.tick / s.tick_rate) if s.tick_rate > 0 else 0
	world_day := sim_tick / 24 + 1
	world_hr  := sim_tick % 24
	season      := eng.season_from_tick(sim_tick)
	season_str  := eng.season_name(season)
	season_col  := season_color(season)
	
	speed_tag := cstring("")
	if s.paused          { speed_tag = "  PAUSED" }
	else if s.speed >= 4 { speed_tag = "  x4" }
	else if s.speed >= 2 { speed_tag = "  x2" }

	base_str := fmt.ctprintf("Day %d  %02d:00  ", world_day, world_hr)
	bw       := rl.MeasureText(base_str, 10)
	rl.DrawText(base_str, px + 10, y + 26, 10, COL_TEXT_DIM)
	rl.DrawText(season_str, px + 10 + bw, y + 26, 10, season_col)
	
	if speed_tag != cstring("") {
		sw := rl.MeasureText(season_str, 10)
		rl.DrawText(speed_tag, px + 10 + bw + sw, y + 26, 10, COL_WARN if s.paused else COL_DIM)
	}

	bar_w := pw - 20
	bar_x := px + 10
	bar_y := y + 42
	rl.DrawRectangle(bar_x, bar_y, bar_w, 8, {18, 22, 34, 255})
	fill_w := i32(f32(bar_w) * s.unrest / 100)
	rl.DrawRectangle(bar_x, bar_y, fill_w, 8, COL_DANGER if s.unrest > 60 else COL_ACCENT)
	rl.DrawRectangleLines(bar_x, bar_y, bar_w, 8, COL_BORDER)
	
	draw_day_clock(px + pw - 35, y + 10, 15, world_hr, world_day)
}

draw_window_directories :: proc(s: ^eng.GameState, win: Window) {
	px := i32(win.rect.x)
	pw := i32(win.rect.width)
	y  := i32(win.rect.y) + 20

	map_h := i32(100)
	map_x := px + 10
	map_y := y + 10
	map_w := pw - 20
	rl.DrawRectangle(map_x, map_y, map_w, map_h, COL_BG_DARK)
	rl.DrawRectangleLines(map_x, map_y, map_w, map_h, COL_BORDER)
	
	min_x, min_z := f32(-10.0), f32(-10.0)
	max_x, max_z := f32(10.0), f32(10.0)
	for &z in s.zones {
		zx := map_x + i32((z.pos.x - min_x) / (max_x - min_x) * f32(map_w))
		zz := map_y + i32((z.pos.z - min_z) / (max_z - min_z) * f32(map_h))
		rl.DrawRectangleLines(zx - 5, zz - 5, 10, 10, {z.color.r, z.color.g, z.color.b, 180})
	}
	for &c in s.citizens {
		cx := map_x + i32((c.world_pos.x - min_x) / (max_x - min_x) * f32(map_w))
		cz := map_y + i32((c.world_pos.z - min_z) / (max_z - min_z) * f32(map_h))
		col := COL_DANGER if c.hunger >= 80 || c.sleep <= 20 else COL_ACCENT
		rl.DrawCircle(cx, cz, 2, col)
	}

	strip_y := map_y + map_h + 10
	if len(s.zones) > 0 {
		chip_w := (pw - 20) / i32(len(s.zones))
		for zi in 0..<len(s.zones) {
			z  := &s.zones[zi]
			cx := px + 10 + i32(zi) * chip_w
			rl.DrawRectangle(cx, strip_y, chip_w - 2, 25, {z.color.r/8, z.color.g/8, z.color.b/8, 255})
			rl.DrawText(z.name, cx + 2, strip_y + 4, 8, z.color)
			
			pop := 0
			for &c in s.citizens { if c.zone == z.name do pop += 1 }
			rl.DrawText(fmt.ctprintf("%d", pop), cx + 2, strip_y + 14, 8, COL_DIM)
		}
	}
}

draw_window_citizens :: proc(s: ^eng.GameState, win: Window) {
	px := i32(win.rect.x)
	pw := i32(win.rect.width)
	y  := i32(win.rect.y) + 20
	
	item_h := i32(52)
	visible_count := (i32(win.rect.height) - 30) / (item_h + 2)
	
	mouse := rl.GetMousePosition()
	in_win := rl.CheckCollisionPointRec(mouse, win.rect)
	
	if in_win {
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			s.citizen_scroll -= i32(wheel)
			if s.citizen_scroll < 0 do s.citizen_scroll = 0
			limit := i32(len(s.citizens)) - visible_count
			if s.citizen_scroll > limit do s.citizen_scroll = max(0, limit)
		}
	}

	for i in 0..<visible_count {
		idx := s.citizen_scroll + i
		if idx >= i32(len(s.citizens)) do break
		
		c := &s.citizens[idx]
		iy := y + 5 + i * (item_h + 2)
		
		is_sel := idx == s.selected
		bg := COL_SEL if is_sel else COL_BG_MID
		rl.DrawRectangle(px + 5, iy, pw - 10, item_h, bg)
		rl.DrawRectangleLines(px + 5, iy, pw - 10, item_h, COL_BORDER)
		
		if in_win && rl.CheckCollisionPointRec(mouse, {f32(px+5), f32(iy), f32(pw-10), f32(item_h)}) {
			rl.DrawRectangleLines(px + 5, iy, pw - 10, item_h, COL_ACCENT)
			if rl.IsMouseButtonPressed(.LEFT) {
				s.selected = idx if s.selected != idx else -1
				s.follow_sel = s.selected >= 0
			}
		}

		rl.DrawCircle(px + 25, iy + 26, 15, c.color)
		rl.DrawText(c.name, px + 50, iy + 8, 10, COL_TEXT)
		rl.DrawText(behavior_label(c.behavior), px + 50, iy + 22, 8, behavior_color(c.behavior))
		
		draw_mini_bar(px + 50, iy + 34, 40, c.health, COL_OK)
		draw_mini_bar(px + 95, iy + 34, 40, 100-c.hunger, COL_WARN)
		draw_mini_bar(px + 140, iy + 34, 40, c.sleep, COL_ACCENT)
	}
}

draw_window_info :: proc(s: ^eng.GameState, win: Window) {
	if s.selected < 0 || int(s.selected) >= len(s.citizens) {
		rl.DrawText("SELECT A CITIZEN", i32(win.rect.x) + 20, i32(win.rect.y) + 60, 10, COL_DIM)
		return
	}
	
	c := &s.citizens[s.selected]
	px := i32(win.rect.x)
	y  := i32(win.rect.y) + 30
	
	rl.DrawCircle(px + 45, y + 45, 30, c.color)
	rl.DrawText(c.name, px + 90, y + 20, 16, COL_ACCENT)
	rl.DrawText(c.zone, px + 90, y + 40, 10, COL_TEXT_DIM)
	
	sy := y + 90
	draw_stat_bar_ex(px + 20, sy, 260, "HEALTH", c.health, COL_OK, 30, false)
	draw_stat_bar_ex(px + 20, sy + 35, 260, "HUNGER", c.hunger, COL_WARN, 80, true)
	draw_stat_bar_ex(px + 20, sy + 70, 260, "SLEEP", c.sleep, COL_ACCENT, 30, false)
	draw_stat_bar_ex(px + 20, sy + 105, 260, "SOCIAL", c.social, {200, 95, 255, 255}, 30, false)
}

draw_window_events :: proc(s: ^eng.GameState, win: Window) {
	px := i32(win.rect.x)
	pw := i32(win.rect.width)
	y  := i32(win.rect.y) + 20
	
	rl.BeginScissorMode(px, y, pw, i32(win.rect.height) - 20)
	defer rl.EndScissorMode()

	for i := 0; i < len(s.events); i += 1 {
		ev := s.events[len(s.events) - 1 - i]
		ey := y + 5 + i32(i) * 16
		if ey > i32(win.rect.y + win.rect.height) do break
		
		rl.DrawCircle(px + 10, ey + 6, 3, event_color(ev.kind))
		rl.DrawText(ev.text, px + 20, ey, 10, COL_TEXT_DIM)
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

draw_section_header :: proc(label: cstring, px, pw, y: i32) {
	rl.DrawRectangle(px + 2, y, pw - 2, 18, COL_HEADER)
	rl.DrawRectangle(px + 2, y + 17, pw - 2, 1, COL_BORDER)
	rl.DrawText(label, px + 8, y + 4, 10, COL_ACCENT)
}

draw_mini_bar :: proc(x, y, w: i32, value: f32, col: rl.Color) {
	rl.DrawRectangle(x, y, w, 3, COL_BG_DARK)
	fill := i32(f32(w) * math.clamp(value, 0, 100) / 100)
	rl.DrawRectangle(x, y, fill, 3, col)
}

draw_stat_bar_ex :: proc(x, y, w: i32, label: cstring, value: f32, bar_col: rl.Color, danger_at: f32, danger_high: bool) {
	rl.DrawText(label, x, y, 9, COL_DIM)
	val_str := fmt.ctprintf("%.0f", value)
	rl.DrawText(val_str, x + w - 20, y, 9, COL_TEXT)

	by := y + 12
	rl.DrawRectangle(x, by, w, 10, COL_BG_DARK)
	
	fill_w := i32(f32(w) * math.clamp(value, 0, 100) / 100)
	
	is_danger := value >= danger_at if danger_high else value <= danger_at
	final_col := COL_DANGER if is_danger else bar_col
	
	rl.DrawRectangle(x, by, fill_w, 10, final_col)
	rl.DrawRectangleLines(x, by, w, 10, COL_BORDER)
}

draw_day_clock :: proc(cx, cy, r: i32, hour: int, day: int) {
	// Semi-circle arc for day/night
	rl.DrawCircleSectorLines({f32(cx), f32(cy + r)}, f32(r), 180, 360, 24, COL_BORDER)
	
	// Map 0-23 hour to 180-360 degrees
	angle := f32(hour) / 24.0 * 180.0 + 180.0
	
	// Sun or Moon position
	px := f32(cx) + math.cos(angle * math.RAD_PER_DEG) * f32(r)
	py := f32(cy + r) + math.sin(angle * math.RAD_PER_DEG) * f32(r)
	
	is_night := hour < 7 || hour > 19
	col := rl.YELLOW if !is_night else rl.WHITE
	rl.DrawCircleV({px, py}, 4, col)
}

draw_pop_sparkline :: proc(x, y, w, h: i32, s: ^eng.GameState) {
	if !s.pop_hist_full && s.pop_hist_idx < 2 do return
	
	count := 48 if s.pop_hist_full else s.pop_hist_idx
	if count < 2 do return

	for i in 0..<count-1 {
		idx1 := (s.pop_hist_idx - count + i + 48) % 48
		idx2 := (idx1 + 1) % 48
		
		v1 := f32(s.pop_history[idx1])
		v2 := f32(s.pop_history[idx2])
		max_v := f32(max(1, s.max_pop_seen))
		
		x1 := x + i32(f32(i) / f32(count-1) * f32(w))
		x2 := x + i32(f32(i+1) / f32(count-1) * f32(w))
		y1 := y + h - i32(v1 / max_v * f32(h))
		y2 := y + h - i32(v2 / max_v * f32(h))
		
		rl.DrawLine(x1, y1, x2, y2, COL_ACCENT)
	}
}

// ---------------------------------------------------------------------------
// World / Sky helpers (re-implemented as they were in world.odin or used in Draw_Hud)
// ---------------------------------------------------------------------------



