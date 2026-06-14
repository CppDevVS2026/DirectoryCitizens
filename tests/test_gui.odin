package tests

import gui "../gui"
import "core:testing"

@(test)
test_gui_window_initialization :: proc(t: ^testing.T) {
	layout := gui.init_gui_layout()

	// Check if all windows are initialized and visible
	testing.expect(t, layout.windows[.Time].visible == true)
	testing.expect(t, layout.windows[.Directories].visible == true)
	testing.expect(t, layout.windows[.Citizens].visible == true)
	testing.expect(t, layout.windows[.Info].visible == true)
	testing.expect(t, layout.windows[.Events].visible == true)

	// Check titles
	testing.expect(t, string(layout.windows[.Time].title) == "ENVIRONMENT")
	testing.expect(t, string(layout.windows[.Citizens].title) == "POPULATION")
}

@(test)
test_gui_window_separation :: proc(t: ^testing.T) {
	layout := gui.init_gui_layout()

	time_win := layout.windows[.Time].rect
	citizen_win := layout.windows[.Citizens].rect

	// Windows should not be at the same position (monolithic HUD was at PANEL_X)
	testing.expect(t, time_win.x != citizen_win.x)
}

