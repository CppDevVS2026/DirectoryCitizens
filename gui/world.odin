package gui

import rl  "vendor:raylib"
import eng "../engine"
import     "core:math"

Draw_World :: proc(s: ^eng.GameState) {
	rl.BeginMode3D(s.camera)

	rl.DrawGrid(40, 1)

	// Zones as semi-transparent boxes + bright wireframe
	for &z in s.zones {
		center := zone_center(z)
		fill   := z.color
		fill.a  = 45
		rl.DrawCube(center, z.size.x, z.size.y, z.size.z, fill)
		rl.DrawCubeWires(center, z.size.x, z.size.y, z.size.z, z.color)

		// Top edge highlight
		top   := rl.Vector3{center.x, center.y + z.size.y * 0.5, center.z}
		glow  := z.color
		glow.a = 120
		rl.DrawCubeWires(top, z.size.x * 0.95, 0.05, z.size.z * 0.95, glow)
	}

	// Citizens — bobbing spheres with a glow ring
	for &c, i in s.citizens {
		bob := f32(math.sin(s.tick * 1.8 + f64(i) * 1.1)) * 0.12
		pos := rl.Vector3{c.world_pos.x, c.world_pos.y + bob, c.world_pos.z}

		is_sel := i32(i) == s.selected

		glow   := c.color
		glow.a  = 60
		rl.DrawSphere(pos, 0.5, glow)
		rl.DrawSphere(pos, 0.32, c.color)
		rl.DrawCircle3D(pos, 0.55, {1, 0, 0}, 90, c.color)

		// Shadow blob on the floor
		rl.DrawCircle3D({c.world_pos.x, 0.01, c.world_pos.z}, 0.28, {1, 0, 0}, 90, {0, 0, 0, 80})

		if is_sel {
			rl.DrawSphereWires(pos, 0.58, 8, 8, {255, 255, 255, 200})
			rl.DrawCircle3D(pos, 0.75, {1, 0, 0}, 90, {255, 255, 255, 200})
		}
	}

	rl.EndMode3D()

	// Screen-space zone labels
	for &z in s.zones {
		label_pos := rl.Vector3{z.pos.x + z.size.x * 0.5, z.size.y + 1.0, z.pos.z + z.size.z * 0.5}
		sp := rl.GetWorldToScreen(label_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		tw := rl.MeasureText(z.name, 14)
		bx := i32(sp.x) - tw / 2 - 6
		by := i32(sp.y) - 12
		rl.DrawRectangle(bx, by, tw + 12, 22, {0, 0, 0, 160})
		rl.DrawRectangleLines(bx, by, tw + 12, 22, z.color)
		rl.DrawText(z.name, i32(sp.x) - tw / 2, by + 4, 14, z.color)
	}

	// Screen-space citizen name tags
	for &c, i in s.citizens {
		tag_pos := rl.Vector3{c.world_pos.x, c.world_pos.y + 0.9, c.world_pos.z}
		sp := rl.GetWorldToScreen(tag_pos, s.camera)
		if sp.x < 4 || sp.x > f32(PANEL_X) - 4 || sp.y < 4 || sp.y > f32(SCREEN_H) - 4 { continue }

		is_sel := i32(i) == s.selected
		tw := rl.MeasureText(c.name, 12)
		if is_sel {
			rl.DrawRectangle(i32(sp.x) - tw / 2 - 3, i32(sp.y) - 2, tw + 6, 17, {0, 0, 0, 180})
		}
		rl.DrawText(c.name, i32(sp.x) - tw / 2, i32(sp.y), 12, c.color)
	}

	// Viewport border
	rl.DrawRectangle(PANEL_X - 1, 0, 1, SCREEN_H, {40, 60, 90, 255})
	rl.DrawText("Left drag: orbit  |  Scroll: zoom  |  Click citizen: select", 10, SCREEN_H - 22, 11, {80, 100, 120, 200})
}

zone_center :: proc(z: eng.Zone) -> rl.Vector3 {
	return {z.pos.x + z.size.x * 0.5, z.size.y * 0.5, z.pos.z + z.size.z * 0.5}
}
