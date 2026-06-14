package engine

/*
	the_eye.odin
	============
	The Eye is a live Win32 filesystem watcher. It runs on a background thread,
	watches the entire "world/" directory tree, and posts EyeEvents into a
	mutex-protected queue. The main thread drains that queue once per frame.

	Why a background thread?
	  ReadDirectoryChangesW blocks until a change occurs. If we ran it on the
	  main thread it would freeze the render loop. So we spin a separate OS
	  thread that does nothing but wait for changes and post them.

	Thread safety:
	  EyeState.events is touched by two threads:
	    - the watcher thread appends to it
	    - the main thread drains it each frame
	  We protect every access with EyeState.mu (a sync.Mutex).

	Event flow:
	  FILE_ACTION_ADDED    .citizen created   →  EyeEvent{.Spawn,      path}
	  FILE_ACTION_REMOVED  .citizen deleted   →  EyeEvent{.Death,      path}
	  FILE_ACTION_MODIFIED .citizen changed   →  EyeEvent{.StatChange, path}
	  FILE_ACTION_RENAMED_OLD_NAME + NEW_NAME →  EyeEvent{.Rename, new, old}
	  Subdir added                            →  EyeEvent{.ZoneAdded,   path}
	  Subdir removed                          →  EyeEvent{.ZoneRemoved, path}
*/

import "core:fmt"
import "core:path/filepath"
import "core:strings"
import "core:sync"
import "core:thread"
import win "core:sys/windows"

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

EyeAction :: enum {
	Spawn,       // a .citizen file was created
	Death,       // a .citizen file was deleted
	Rename,      // a .citizen file was renamed (name change = life event)
	StatChange,  // a .citizen file was modified (stats updated externally)
	ZoneAdded,   // a subdirectory was created (new zone)
	ZoneRemoved, // a subdirectory was removed (zone collapsed)
}

EyeEvent :: struct {
	action:   EyeAction,
	path:     string, // full relative path, e.g. "world/Market District/aldric.citizen"
	old_path: string, // only set for Rename — the old file path
}

EyeState :: struct {
	events:     [dynamic]EyeEvent,
	mu:         sync.Mutex,
	running:    bool,
	handle:     win.HANDLE,     // open directory handle used by ReadDirectoryChangesW
	thread:     ^thread.Thread,
	watch_root: string,         // e.g. "world" — stored for path reconstruction
}

// ---------------------------------------------------------------------------
// Internal watcher thread data
// ---------------------------------------------------------------------------

// Passed to the background thread proc — we can't close over EyeState directly.
@(private)
WatcherData :: struct {
	eye:  ^EyeState,
	root: string, // clone of watch_root
}

// 64 KB — ReadDirectoryChangesW recommended buffer size.
@(private)
RDCW_BUFFER_SIZE :: 65536

// ---------------------------------------------------------------------------
// start_the_eye
// ---------------------------------------------------------------------------

/*
	start_the_eye — opens the directory handle and spawns the watcher thread.

	After this returns, EyeState.events will start filling up. Call
	drain_eye_events each frame to consume them.
*/
start_the_eye :: proc(eye: ^EyeState, watch_path: string) {
	eye.watch_root = strings.clone(watch_path)
	eye.running    = true

	// utf8_to_wstring uses context.temp_allocator by default — fine here since
	// we only need the wide string for the CreateFileW call below.
	wide_path := win.utf8_to_wstring(watch_path)

	// FILE_LIST_DIRECTORY  — required access right for ReadDirectoryChangesW
	// FILE_FLAG_BACKUP_SEMANTICS — required when opening a *directory* handle
	eye.handle = win.CreateFileW(
		wide_path,
		win.FILE_LIST_DIRECTORY,
		win.FILE_SHARE_READ | win.FILE_SHARE_WRITE | win.FILE_SHARE_DELETE,
		nil,
		win.OPEN_EXISTING,
		win.FILE_FLAG_BACKUP_SEMANTICS,
		nil,
	)

	if eye.handle == win.INVALID_HANDLE_VALUE {
		eye.running = false
		return
	}

	data      := new(WatcherData)
	data.eye   = eye
	data.root  = strings.clone(watch_path)

	eye.thread = thread.create_and_start_with_data(data, watcher_thread_proc)
}

// ---------------------------------------------------------------------------
// stop_the_eye
// ---------------------------------------------------------------------------

/*
	stop_the_eye — signals the watcher to exit and cleans up.

	Closing the handle unblocks ReadDirectoryChangesW on the background thread
	so it can check eye.running and exit cleanly.
*/
stop_the_eye :: proc(eye: ^EyeState) {
	eye.running = false

	if eye.handle != nil && eye.handle != win.INVALID_HANDLE_VALUE {
		win.CloseHandle(eye.handle)
		eye.handle = nil
	}

	if eye.thread != nil {
		thread.join(eye.thread)
		thread.destroy(eye.thread)
		eye.thread = nil
	}

	// Free any events that were never drained.
	sync.mutex_lock(&eye.mu)
	for ev in eye.events {
		delete(ev.path)
		if ev.old_path != "" { delete(ev.old_path) }
	}
	delete(eye.events)
	sync.mutex_unlock(&eye.mu)

	delete(eye.watch_root)
}

// ---------------------------------------------------------------------------
// drain_eye_events — apply pending events to the game state (call each frame)
// ---------------------------------------------------------------------------

/*
	drain_eye_events — pops every pending EyeEvent and mutates GameState.

	We swap the queue under the lock (very fast) then process outside the lock
	(safe — the watcher never touches the swapped-out slice).
*/
drain_eye_events :: proc(eye: ^EyeState, s: ^GameState) {
	sync.mutex_lock(&eye.mu)
	pending   := eye.events
	eye.events = {}
	sync.mutex_unlock(&eye.mu)

	defer {
		for ev in pending {
			delete(ev.path)
			if ev.old_path != "" { delete(ev.old_path) }
		}
		delete(pending)
	}

	for ev in pending {
		switch ev.action {

		case .Spawn:
			zone_name := zone_name_from_path(ev.path)
			if c, ok := load_citizen(ev.path, zone_name); ok {
				append(&s.citizens, c)
				push_event(s, fmt.ctprintf("%s arrived in %s", c.name, c.zone), .Spawn)
			}

		case .Death:
			for i := len(s.citizens) - 1; i >= 0; i -= 1 {
				if string(s.citizens[i].path) == ev.path {
					name := s.citizens[i].name
					push_event(s, fmt.ctprintf("%s was erased", name), .Death)
					ordered_remove(&s.citizens, i)
					break
				}
			}

		case .StatChange:
			// Reload stats from disk; preserve runtime-only fields not stored on disk.
			// No event is pushed — this fires on every auto-save tick, not just
			// external edits, and would flood the log with noise.
			for i in 0..<len(s.citizens) {
				c := &s.citizens[i]
				if string(c.path) == ev.path {
					zone_name := string(c.zone)
					if fresh, ok := load_citizen(ev.path, zone_name); ok {
						fresh.stress_ticks = c.stress_ticks
						fresh.behavior     = c.behavior
						s.citizens[i] = fresh
					}
					break
				}
			}

		case .Rename:
			for i in 0..<len(s.citizens) {
				c := &s.citizens[i]
				if string(c.path) == ev.old_path {
					old_name  := c.name
					zone_name := string(c.zone)
					if fresh, ok := load_citizen(ev.path, zone_name); ok {
						fresh.stress_ticks = c.stress_ticks
						s.citizens[i] = fresh
						push_event(s, fmt.ctprintf("%s is now known as %s", old_name, fresh.name), .Rename)
					}
					break
				}
			}

		case .ZoneAdded:
			zone_name := filepath.base(ev.path)
			already   := false
			for &z in s.zones {
				if string(z.path) == ev.path { already = true; break }
			}
			if !already {
				pos, size := zone_layout(zone_name, len(s.zones))
				zname_c   := strings.clone_to_cstring(zone_name, context.allocator)
				append(&s.zones, Zone{
					name  = zname_c,
					path  = strings.clone_to_cstring(ev.path, context.allocator),
					pos   = pos,
					size  = size,
					color = zone_color(zone_name),
				})
				push_event(s, fmt.ctprintf("Zone '%s' opened", zname_c), .Info)
			}

		case .ZoneRemoved:
			for i := len(s.zones) - 1; i >= 0; i -= 1 {
				if string(s.zones[i].path) == ev.path {
					zone_name := s.zones[i].name
					for j := len(s.citizens) - 1; j >= 0; j -= 1 {
						if s.citizens[j].zone == zone_name {
							push_event(s, fmt.ctprintf("%s vanished with the zone", s.citizens[j].name), .Death)
							ordered_remove(&s.citizens, j)
						}
					}
					push_event(s, fmt.ctprintf("Zone '%s' collapsed", zone_name), .Death)
					ordered_remove(&s.zones, i)
					break
				}
			}
		}
	}
}

// ---------------------------------------------------------------------------
// watcher_thread_proc — background thread; loops ReadDirectoryChangesW.
// ---------------------------------------------------------------------------

@(private)
watcher_thread_proc :: proc(raw: rawptr) {
	data := (^WatcherData)(raw)
	eye  := data.eye
	root := data.root
	defer {
		delete(root)
		free(data)
	}

	// What change types we watch for.
	notify_filter := win.DWORD(
		win.FILE_NOTIFY_CHANGE_FILE_NAME  |
		win.FILE_NOTIFY_CHANGE_DIR_NAME   |
		win.FILE_NOTIFY_CHANGE_LAST_WRITE,
	)

	buf := make([]u8, RDCW_BUFFER_SIZE)
	defer delete(buf)

	// Holds the old file path between RENAMED_OLD_NAME and RENAMED_NEW_NAME.
	rename_old := ""

	for eye.running {
		bytes_returned: win.DWORD

		// Blocks here until a change occurs, then fills buf.
		// Returns FALSE when the handle is closed from stop_the_eye.
		ok := win.ReadDirectoryChangesW(
			eye.handle,
			raw_data(buf),
			win.DWORD(len(buf)),
			win.TRUE,         // bWatchSubtree
			notify_filter,
			&bytes_returned,
			nil,
			nil,
		)

		if ok == win.FALSE || bytes_returned == 0 { break }

		// Walk the variable-length FILE_NOTIFY_INFORMATION chain.
		// NextEntryOffset == 0 means this is the last entry.
		base   := uintptr(raw_data(buf))
		offset := uintptr(0)

		for {
			info := (^win.FILE_NOTIFY_INFORMATION)(rawptr(base + offset))

			// file_name is declared as [1]WCHAR but is actually file_name_length bytes long.
			// file_name_length is in *bytes* — divide by 2 for u16 count.
			n_chars   := int(info.file_name_length) / 2
			name_ptr  := ([^]u16)(rawptr(uintptr(rawptr(info)) + offset_of(win.FILE_NOTIFY_INFORMATION, file_name)))
			rel_name, _ := win.wstring_to_utf8(win.wstring(name_ptr), n_chars, context.allocator)

			// Win32 gives us a path relative to the watched root with backslashes.
			// Normalize to forward slashes to match our filepath conventions.
			for i in 0..<len(rel_name) {
				if rel_name[i] == '\\' { (transmute([]u8)rel_name)[i] = '/' }
			}

			full_path, _ := filepath.join({root, rel_name}, context.allocator)
			delete(rel_name)

			ext    := filepath.ext(filepath.base(full_path))
			is_cit := ext == ".citizen"
			// Treat as a directory if it has no extension (crude but works for world/ layout).
			is_dir := !strings.contains(filepath.base(full_path), ".")

			ev        := EyeEvent{}
			emit      := false
			path_used := false // true when full_path ownership was transferred or freed

			switch info.action {
			case win.FILE_ACTION_ADDED:
				if is_cit {
					ev   = EyeEvent{action = .Spawn,     path = full_path}
					emit = true
				} else if is_dir {
					ev   = EyeEvent{action = .ZoneAdded, path = full_path}
					emit = true
				}

			case win.FILE_ACTION_REMOVED:
				if is_cit {
					ev   = EyeEvent{action = .Death,        path = full_path}
					emit = true
				} else if is_dir {
					ev   = EyeEvent{action = .ZoneRemoved,  path = full_path}
					emit = true
				}

			case win.FILE_ACTION_MODIFIED:
				if is_cit {
					ev   = EyeEvent{action = .StatChange, path = full_path}
					emit = true
				}

			case win.FILE_ACTION_RENAMED_OLD_NAME:
				// Store the old path and wait for the matching NEW_NAME event.
				if rename_old != "" { delete(rename_old) }
				rename_old = strings.clone(full_path, context.allocator)
				delete(full_path)
				path_used = true // already freed above — don't touch it again

			case win.FILE_ACTION_RENAMED_NEW_NAME:
				if is_cit {
					ev   = EyeEvent{action = .Rename, path = full_path, old_path = rename_old}
					emit = true
					rename_old = ""
				} else {
					// Directory rename → remove old zone, add new one.
					if rename_old != "" {
						old_ev := EyeEvent{action = .ZoneRemoved, path = strings.clone(rename_old, context.allocator)}
						sync.mutex_lock(&eye.mu)
						append(&eye.events, old_ev)
						sync.mutex_unlock(&eye.mu)
						delete(rename_old)
						rename_old = ""
					}
					ev   = EyeEvent{action = .ZoneAdded, path = full_path}
					emit = true
				}
			}

			if emit {
				sync.mutex_lock(&eye.mu)
				append(&eye.events, ev)
				sync.mutex_unlock(&eye.mu)
			} else if !path_used {
				// full_path was allocated but not consumed — free it.
				delete(full_path)
			}

			if info.next_entry_offset == 0 { break }
			offset += uintptr(info.next_entry_offset)
		}
	}

	if rename_old != "" { delete(rename_old) }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/*
	zone_name_from_path — extracts the zone directory name from a citizen path.
	  "world/Market District/aldric.citizen"  →  "Market District"
*/
@(private)
zone_name_from_path :: proc(path: string) -> string {
	dir := filepath.dir(path)         // "world/Market District"
	return filepath.base(dir)         // "Market District"  (no allocation — slice of dir)
}
