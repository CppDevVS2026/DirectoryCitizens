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
	hdr_h := i32(92)
	rl.DrawRectangle(px + 2, 0, pw - 2, hdr_h, COL_HEADER)
	rl.DrawRectangle(px + 2, hdr_h - 1, pw - 2, 1, COL_BORDER)

	// Title
	title := cstring("DIRECTORY CITIZENS")
	tw    := rl.MeasureText(title, 16)
	rl.DrawText(title, px + (pw - tw) / 2, 10, 16, COL_ACCENT)

	// Subtitle — eye status row
	blink_on := (i32(s.tick) % 2) == 0
	dot_col  := COL_OK if blink_on else COL_DIM
	rl.DrawCircle(px + 18, 36, 4, dot_col)
	eye_str := fmt.ctprintf("THE EYE  ·  %d citizens  ·  tick %.0f", len(s.citizens), s.tick)
	rl.DrawText(eye_str, px + 28, 30, 10, COL_DIM)

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

		// Click to select
		if hovered && rl.IsMouseButtonPressed(.LEFT) {
			s.selected = idx if s.selected != idx else -1
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

		rl.DrawText(c.name, px + 46, dy,      15, COL_TEXT)
		rl.DrawText(c.zone, px + 46, dy + 19, 10, COL_DIM)

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
			rl.DrawText(stress_label, px + 46, dy + 33, 9, COL_DANGER)
			// Dot chain
			for ti := i32(0); ti < i32(min(c.stress_ticks, 5)); ti += 1 {
				dot_col2 := COL_DANGER if ti < 3 else rl.Color{255, 30, 30, 255}
				rl.DrawCircle(px + 46 + 86 + ti * 10, dy + 37, 3, dot_col2)
			}
		}

		stat_top := dy + 50
		draw_stat_bar_ex(px + 10, stat_top,       pw - 20, "Health", c.health, {65,  210,  90, 255}, 20,  false)
		draw_stat_bar_ex(px + 10, stat_top + 36,  pw - 20, "Hunger", c.hunger, {225, 145,  35, 255}, 80,  true)
		draw_stat_bar_ex(px + 10, stat_top + 72,  pw - 20, "Sleep",  c.sleep,  { 90, 155, 255, 255}, 20,  false)
		draw_stat_bar_ex(px + 10, stat_top + 108, pw - 20, "Social", c.social, {200,  95, 255, 255}, 20,  false)
	} else {
		msg := cstring("— select a citizen —")
		mw  := rl.MeasureText(msg, 12)
		rl.DrawText(msg, px + (pw - mw) / 2, y + detail_h / 2 - 6, 12, COL_DIM)
	}

	y += detail_h + 8

	// ==========================================================================
	// EVENT LOG
	// ==========================================================================
	log_area := sh - y - 4
	if log_area < 30 { return }

	draw_section_header("EVENTS", px, pw, y)
	y += 20

	ev_h := i32(19)
	rl.BeginScissorMode(px + 2, y, pw - 4, log_area - 22)
	for i in 0..<len(s.events) {
		ev   := &s.events[i]
		ey   := y + i32(i) * ev_h
		col  := event_color(ev.kind)
		// Fade older entries
		age  := u8(max(60, 255 - i * 18))
		fcol := rl.Color{col.r, col.g, col.b, age}
		rl.DrawCircle(px + 14, ey + ev_h / 2, 3, fcol)
		rl.DrawText(ev.text, px + 24, ey + 4, 10, fcol)
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
