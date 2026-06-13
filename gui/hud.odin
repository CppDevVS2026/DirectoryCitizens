package gui

import rl  "vendor:raylib"
import eng "../engine"
import     "core:fmt"

// Layout constants — used by both gui and main
SCREEN_W :: i32(1280)
SCREEN_H :: i32(720)
PANEL_X  :: i32(880)
PANEL_W  :: SCREEN_W - PANEL_X

// Palette
COL_BG      :: rl.Color{12,  15,  22,  248}
COL_BG_DARK :: rl.Color{ 8,  10,  16,  255}
COL_BORDER  :: rl.Color{35,  55,  85,  255}
COL_HEADER  :: rl.Color{16,  20,  32,  255}
COL_SEL     :: rl.Color{25,  45,  75,  255}
COL_DIVIDER :: rl.Color{25,  32,  48,  255}
COL_TEXT    :: rl.Color{200, 215, 230, 255}
COL_DIM     :: rl.Color{100, 120, 145, 255}
COL_ACCENT  :: rl.Color{ 55, 145, 230, 255}

event_color :: proc(kind: eng.EventKind) -> rl.Color {
	switch kind {
	case .Spawn:  return { 90, 220,  90, 255}
	case .Death:  return {230,  70,  70, 255}
	case .Move:   return { 90, 175, 255, 255}
	case .Rename: return {255, 195,  70, 255}
	case .Info:   return {160, 160, 160, 255}
	}
	return rl.WHITE
}

Draw_Hud :: proc(s: ^eng.GameState) {
	px := PANEL_X
	pw := PANEL_W
	sh := SCREEN_H

	rl.DrawRectangle(px, 0, pw, sh, COL_BG)
	rl.DrawRectangle(px, 0, 1,  sh, COL_BORDER)

	y := i32(0)

	// =====================================================================
	// HEADER
	// =====================================================================
	hdr_h := i32(68)
	rl.DrawRectangle(px, 0, pw, hdr_h, COL_HEADER)
	rl.DrawRectangle(px, hdr_h - 1, pw, 1, COL_BORDER)

	title := cstring("DIRECTORY CITIZENS")
	tw    := rl.MeasureText(title, 17)
	rl.DrawText(title, px + (pw - tw) / 2, 10, 17, COL_ACCENT)
	rl.DrawText("[ THE  EYE ]", px + 12, 34, 11, COL_DIM)

	tick_str := fmt.ctprintf("tick %.1f", s.tick)
	tw2      := rl.MeasureText(tick_str, 11)
	rl.DrawText(tick_str, px + pw - tw2 - 12, 34, 11, COL_DIM)
	rl.DrawText("Watching: world/", px + 12, 50, 11, COL_DIM)

	y = hdr_h + 6

	// =====================================================================
	// CITIZEN LIST
	// =====================================================================
	rl.DrawText("CITIZENS", px + 12, y, 12, COL_ACCENT)
	rl.DrawRectangle(px + 12, y + 15, 60, 1, COL_ACCENT)
	y += 20

	item_h    := i32(46)
	vis_count := i32(5)
	list_h    := item_h * vis_count

	mouse := rl.GetMousePosition()
	if mouse.x > f32(px) {
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			s.citizen_scroll -= i32(wheel)
			max_s := i32(len(s.citizens)) - vis_count
			if max_s < 0      { max_s = 0 }
			if s.citizen_scroll < 0    { s.citizen_scroll = 0 }
			if s.citizen_scroll > max_s { s.citizen_scroll = max_s }
		}
	}

	rl.BeginScissorMode(px, y, pw, list_h)
	for idx := s.citizen_scroll; idx < s.citizen_scroll + vis_count && idx < i32(len(s.citizens)); idx += 1 {
		c    := &s.citizens[idx]
		iy   := y + (idx - s.citizen_scroll) * item_h
		isel := idx == s.selected

		rl.DrawRectangle(px + 3, iy + 1, pw - 6, item_h - 2, COL_SEL if isel else {0, 0, 0, 0})
		rl.DrawCircle(px + 20, iy + item_h / 2 - 4, 6, c.color)
		rl.DrawText(c.name,   px + 34, iy + 8,  14, COL_TEXT)
		rl.DrawText(c.status, px + 34, iy + 26, 11, COL_DIM)

		// Health bar
		bx := px + 220
		by := iy + item_h / 2 - 4
		bw := pw - 230
		bh := i32(8)
		rl.DrawRectangle(bx, by, bw, bh, {28, 30, 40, 255})
		hw   := i32(f32(bw) * c.health / 100)
		hcol := rl.Color{75, 215, 75, 255} if c.health > 50 else rl.Color{215, 110, 40, 255}
		rl.DrawRectangle(bx, by, hw, bh, hcol)
		rl.DrawRectangleLines(bx, by, bw, bh, {50, 55, 70, 255})

		rect := rl.Rectangle{f32(px + 3), f32(iy + 1), f32(pw - 6), f32(item_h - 2)}
		if rl.CheckCollisionPointRec(mouse, rect) && rl.IsMouseButtonPressed(.LEFT) {
			s.selected = idx if s.selected != idx else -1
		}

		rl.DrawRectangle(px + 8, iy + item_h - 1, pw - 16, 1, COL_DIVIDER)
	}
	rl.EndScissorMode()

	y += list_h + 16

	// =====================================================================
	// SELECTED CITIZEN DETAILS
	// =====================================================================
	detail_h := i32(195)
	rl.DrawRectangle(px, y, pw, detail_h, COL_BG_DARK)
	rl.DrawRectangle(px, y, pw, 1, COL_BORDER)
	rl.DrawRectangle(px, y + detail_h - 1, pw, 1, COL_BORDER)

	if s.selected >= 0 && int(s.selected) < len(s.citizens) {
		c  := &s.citizens[s.selected]
		dy := y + 12
		rl.DrawCircle(px + 26, dy + 12, 11, c.color)
		rl.DrawText(c.name, px + 44, dy,      16, COL_TEXT)
		rl.DrawText(c.zone, px + 44, dy + 20, 12, COL_DIM)
		dy += 46
		draw_stat_bar(px + 10, dy,       pw - 20, "Health", c.health, {75,  215, 75,  255})
		draw_stat_bar(px + 10, dy + 34,  pw - 20, "Hunger", c.hunger, {220, 135, 45,  255})
		draw_stat_bar(px + 10, dy + 68,  pw - 20, "Sleep",  c.sleep,  {90,  155, 255, 255})
		draw_stat_bar(px + 10, dy + 102, pw - 20, "Social", c.social, {200, 95,  255, 255})
	} else {
		msg := cstring("-- Select a citizen --")
		mw  := rl.MeasureText(msg, 13)
		rl.DrawText(msg, px + (pw - mw) / 2, y + detail_h / 2 - 7, 13, COL_DIM)
	}

	y += detail_h + 6

	// =====================================================================
	// EVENT LOG
	// =====================================================================
	log_area := sh - y - 4
	if log_area < 30 { return }

	rl.DrawText("EVENT LOG", px + 12, y, 12, COL_ACCENT)
	rl.DrawRectangle(px + 12, y + 15, 60, 1, COL_ACCENT)
	y += 22

	ev_h := i32(21)
	rl.BeginScissorMode(px, y, pw, log_area - 22)
	for i in 0..<len(s.events) {
		ev  := &s.events[i]
		ey  := y + i32(i) * ev_h
		col := event_color(ev.kind)
		rl.DrawCircle(px + 16, ey + ev_h / 2, 4, col)
		rl.DrawText(ev.text, px + 28, ey + 5, 11, col)
	}
	rl.EndScissorMode()
}

draw_stat_bar :: proc(x, y, w: i32, label: cstring, value: f32, bar_col: rl.Color) {
	label_w := i32(50)
	bar_h   := i32(13)
	bx      := x + label_w
	bw      := w - label_w - 44

	rl.DrawText(label, x, y + 1, 11, COL_DIM)
	rl.DrawRectangle(bx, y, bw, bar_h, {22, 25, 36, 255})
	rl.DrawRectangle(bx, y, i32(f32(bw) * value / 100), bar_h, bar_col)
	rl.DrawRectangleLines(bx, y, bw, bar_h, {40, 48, 65, 255})

	val_str := fmt.ctprintf("%.0f", value)
	rl.DrawText(val_str, bx + bw + 5, y + 1, 11, COL_TEXT)
}
