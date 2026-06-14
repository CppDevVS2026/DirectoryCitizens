package gui

import rl "vendor:raylib"

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
