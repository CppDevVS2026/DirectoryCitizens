package tests

import eng "../engine"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sync"
import "core:testing"
import "core:time"

// Helper to drain events into a slice for testing
drain_events :: proc(eye: ^eng.EyeState) -> [dynamic]eng.EyeEvent {
	sync.mutex_lock(&eye.mu)
	events := eye.events
	eye.events = {}
	sync.mutex_unlock(&eye.mu)
	return events
}

free_events :: proc(events: [dynamic]eng.EyeEvent) {
	for ev in events {
		delete(ev.path)
		if ev.old_path != "" {delete(ev.old_path)}
	}
	delete(events)
}

@(test)
test_the_eye_spawn_citizen :: proc(t: ^testing.T) {
	eye: eng.EyeState
	watch_path := "test_world_spawn"
	os.make_directory(watch_path)
	defer os.remove_all(watch_path)

	eng.start_the_eye(&eye, watch_path)
	// IMPORTANT: stop_the_eye joins the thread, preventing crashes
	defer eng.stop_the_eye(&eye)

	time.sleep(100 * time.Millisecond)

	citizen_path, _ := filepath.join({watch_path, "test.citizen"})
	_ = os.write_entire_file(citizen_path, transmute([]byte)string("name = Test\n"))

	found := false
	for _ in 0 ..< 20 {
		time.sleep(200 * time.Millisecond)

		events := drain_events(&eye)
		defer free_events(events)

		if len(events) > 0 {
			for ev in events {
				fmt.printf("Event: %v path: %s\n", ev.action, ev.path)
				if (ev.action == .Spawn || ev.action == .StatChange) && strings.contains(ev.path, "test.citizen") {
					found = true
				}
			}
		}
		if found do break
	}

	testing.expect_value(t, found, true)
}

@(test)
test_the_eye_death_citizen :: proc(t: ^testing.T) {
	eye: eng.EyeState
	watch_path := "test_world_death"
	os.make_directory(watch_path)
	defer os.remove_all(watch_path)

	citizen_path, _ := filepath.join({watch_path, "dying.citizen"})
	_ = os.write_entire_file(citizen_path, transmute([]byte)string("name = Dying\n"))

	eng.start_the_eye(&eye, watch_path)
	defer eng.stop_the_eye(&eye)

	time.sleep(200 * time.Millisecond)

	// Clear initial events
	free_events(drain_events(&eye))

	os.remove(citizen_path)

	found := false
	for _ in 0 ..< 20 {
		time.sleep(200 * time.Millisecond)

		events := drain_events(&eye)
		defer free_events(events)

		if len(events) > 0 {
			for ev in events {
				fmt.printf("Event: %v path: %s\n", ev.action, ev.path)
				if ev.action == .Death && strings.contains(ev.path, "dying.citizen") {
					found = true
				}
			}
		}
		if found do break
	}

	testing.expect_value(t, found, true)
}

@(test)
test_the_eye_rename_citizen :: proc(t: ^testing.T) {
	eye: eng.EyeState
	watch_path := "test_world_rename"
	os.make_directory(watch_path)
	defer os.remove_all(watch_path)

	old_path, _ := filepath.join({watch_path, "old.citizen"})
	new_path, _ := filepath.join({watch_path, "new.citizen"})
	_ = os.write_entire_file(old_path, transmute([]byte)string("name = Old\n"))

	eng.start_the_eye(&eye, watch_path)
	defer eng.stop_the_eye(&eye)

	time.sleep(200 * time.Millisecond)
	free_events(drain_events(&eye))

	os.rename(old_path, new_path)

	found := false
	for _ in 0 ..< 20 {
		time.sleep(200 * time.Millisecond)

		events := drain_events(&eye)
		defer free_events(events)

		if len(events) > 0 {
			for ev in events {
				fmt.printf("Event: %v path: %s old: %s\n", ev.action, ev.path, ev.old_path)
				if ev.action == .Rename &&
				   strings.contains(ev.path, "new.citizen") &&
				   strings.contains(ev.old_path, "old.citizen") {
					found = true
				}
			}
		}
		if found do break
	}

	testing.expect_value(t, found, true)
}

@(test)
test_the_eye_zone_added :: proc(t: ^testing.T) {
	eye: eng.EyeState
	watch_path := "test_world_zone"
	os.make_directory(watch_path)
	defer os.remove_all(watch_path)

	eng.start_the_eye(&eye, watch_path)
	defer eng.stop_the_eye(&eye)

	time.sleep(100 * time.Millisecond)

	zone_path, _ := filepath.join({watch_path, "NewZone"})
	os.make_directory(zone_path)

	found := false
	for _ in 0 ..< 20 {
		time.sleep(200 * time.Millisecond)
		events := drain_events(&eye)
		defer free_events(events)

		if len(events) > 0 {
			for ev in events {
				fmt.printf("Event: %v path: %s\n", ev.action, ev.path)
				if ev.action == .ZoneAdded && strings.contains(ev.path, "NewZone") {
					found = true
				}
			}
		}
		if found do break
	}

	testing.expect_value(t, found, true)
}


