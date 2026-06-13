package engine

// TheEye — watches a directory tree for file system changes.
//
// File system event → game event:
//   FILE_ACTION_ADDED    .citizen created  →  citizen spawns
//   FILE_ACTION_REMOVED  .citizen deleted  →  citizen dies (permadeath)
//   FILE_ACTION_RENAMED  .citizen renamed  →  life event (marriage, title...)
//   FILE_ACTION_MODIFIED .citizen changed  →  stat update
//   Subdirectory added                    →  new zone
//   Subdirectory removed                  →  zone collapses
//
// Runs on a background thread — never blocks the render loop.
// Posts EyeEvents into a shared queue; main thread drains it each frame.

import "core:sync"
import "core:thread"

EyeAction :: enum {
	Spawn,
	Death,
	Rename,
	StatChange,
	ZoneAdded,
	ZoneRemoved,
}

EyeEvent :: struct {
	action:   EyeAction,
	path:     string,
	old_path: string, // only set for Rename
}

EyeState :: struct {
	events:  [dynamic]EyeEvent,
	mu:      sync.Mutex,
	running: bool,
	handle:  rawptr,       // Win32 HANDLE to the watched directory
	thread:  ^thread.Thread,
}

// start_the_eye launches the watcher on a background thread.
start_the_eye :: proc(eye: ^EyeState, watch_path: string) {
	eye.running = true

	// TODO (Win32):
	//   import win "core:sys/windows"
	//
	//   1. eye.handle = win.CreateFileW(path, win.FILE_LIST_DIRECTORY, ...)
	//   2. Spawn a thread that loops:
	//        win.ReadDirectoryChangesW(eye.handle, buf, size, true, flags, ...)
	//        Walk the FILE_NOTIFY_INFORMATION chain in buf
	//        Build an EyeEvent for each entry
	//        sync.mutex_lock(&eye.mu)
	//        append(&eye.events, ev)
	//        sync.mutex_unlock(&eye.mu)
	//        if !eye.running { break }
	//
	// Search "ReadDirectoryChangesW example" — the Win32 API is the same
	// from Odin, just called via the windows import package.
	_ = watch_path
}

stop_the_eye :: proc(eye: ^EyeState) {
	eye.running = false
	// TODO: close eye.handle so ReadDirectoryChangesW unblocks and the thread exits
}

// drain_eye_events pulls all pending events off the queue and applies them.
// Call this once per frame from main's update loop.
drain_eye_events :: proc(eye: ^EyeState, s: ^GameState) {
	sync.mutex_lock(&eye.mu)
	events := eye.events[:]
	clear(&eye.events)
	sync.mutex_unlock(&eye.mu)

	for ev in events {
		// TODO: react to each EyeAction, e.g.:
		//   case .Spawn:
		//     c, ok := load_citizen(ev.path, zone_name_from_path(ev.path))
		//     if ok { append(&s.citizens, c) }
		//     push_event(s, "Citizen arrived", .Spawn)
		_ = ev
		_ = s
	}
}
