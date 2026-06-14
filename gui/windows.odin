package gui

import rl "vendor:raylib"

SCREEN_W :: i32(1280)
SCREEN_H :: i32(720)
PANEL_X :: i32(880)
PANEL_W :: SCREEN_W - PANEL_X

Window_ID :: enum {
	Time,
	Directories,
	Citizens,
	Info,
	Events,
}

Window :: struct {
	id:      Window_ID,
	title:   cstring,
	rect:    rl.Rectangle,
	visible: bool,
}

Gui_Layout :: struct {
	windows: [Window_ID]Window,
}

init_gui_layout :: proc() -> Gui_Layout {
	gl: Gui_Layout

	// Default layout
	gl.windows[.Time] = {
		id      = .Time,
		title   = "ENVIRONMENT",
		rect    = {10, 10, 300, 120},
		visible = true,
	}

	gl.windows[.Directories] = {
		id      = .Directories,
		title   = "DIRECTORIES",
		rect    = {10, 140, 300, 200},
		visible = true,
	}

	gl.windows[.Citizens] = {
		id      = .Citizens,
		title   = "POPULATION",
		rect    = {f32(SCREEN_W - 310), 10, 300, 400},
		visible = true,
	}

	gl.windows[.Info] = {
		id      = .Info,
		title   = "INFORMATION",
		rect    = {f32(SCREEN_W - 310), 420, 300, 290},
		visible = true,
	}

	gl.windows[.Events] = {
		id      = .Events,
		title   = "LOG",
		rect    = {320, f32(SCREEN_H - 130), 640, 120},
		visible = true,
	}

	return gl
}

draw_window_frame :: proc(win: Window) {
	if !win.visible do return

	// Semi-transparent background
	rl.DrawRectangleRec(win.rect, {10, 13, 20, 200})
	rl.DrawRectangleLinesEx(win.rect, 1, COL_BORDER)

	// Title bar
	title_h := f32(20)
	title_rect := rl.Rectangle{win.rect.x, win.rect.y, win.rect.width, title_h}
	rl.DrawRectangleRec(title_rect, COL_HEADER)
	rl.DrawRectangleLinesEx(title_rect, 1, COL_BORDER)

	rl.DrawText(win.title, i32(win.rect.x) + 6, i32(win.rect.y) + 4, 10, COL_ACCENT)
}

sky_color :: proc(game_tick: int) -> rl.Color {
	hour := game_tick % 24

	NIGHT :: rl.Color{3, 4, 9, 255}
	DAWN :: rl.Color{14, 9, 22, 255}
	DAY :: rl.Color{8, 10, 14, 255}
	DUSK :: rl.Color{16, 10, 20, 255}

	lerp_sky :: proc(a, b: rl.Color, t: f32) -> rl.Color {
		return rl.Color {
			u8(f32(a.r) + f32(i16(b.r) - i16(a.r)) * t),
			u8(f32(a.g) + f32(i16(b.g) - i16(a.g)) * t),
			u8(f32(a.b) + f32(i16(b.b) - i16(a.b)) * t),
			255,
		}
	}

	switch {
	case hour < 5:
		return NIGHT
	case hour < 7:
		return lerp_sky(NIGHT, DAWN, f32(hour - 5) / 2.0)
	case hour < 8:
		return lerp_sky(DAWN, DAY, f32(hour - 7))
	case hour < 18:
		return DAY
	case hour < 20:
		return lerp_sky(DAY, DUSK, f32(hour - 18) / 2.0)
	case hour < 22:
		return lerp_sky(DUSK, NIGHT, f32(hour - 20) / 2.0)
	case:
		return NIGHT
	}
}

is_nighttime :: proc(game_tick: int) -> bool {
	h := game_tick % 24
	return h < 7 || h >= 19
}

Draw_Night_Overlay :: proc(game_tick, vp_w, vp_h: i32) {
	hour := game_tick % 24
	alpha := f32(0)
	switch {
	case hour < 5:
		alpha = 0.3
	case hour < 6:
		alpha = 0.3 - f32(hour - 5) * 0.15
	case hour < 7:
		alpha = 0.15 - f32(hour - 6) * 0.15
	case hour < 18:
		alpha = 0
	case hour < 19:
		alpha = f32(hour - 18) * 0.1
	case hour < 21:
		alpha = 0.1 + f32(hour - 19) * 0.1
	case hour < 23:
		alpha = 0.3
	case:
		alpha = 0.3
	}

	if alpha > 0 {
		rl.DrawRectangle(0, 0, vp_w, vp_h, rl.Fade(rl.BLACK, alpha))
	}
}

