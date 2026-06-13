package main

// TheEye — watches a directory tree for file system changes.
//
// How it maps to game events:
//   FILE_ACTION_ADDED    .citizen created  →  citizen spawns
//   FILE_ACTION_REMOVED  .citizen deleted  →  citizen dies (permadeath)
//   FILE_ACTION_RENAMED  .citizen renamed  →  life event (marriage, title change)
//   FILE_ACTION_MODIFIED .citizen changed  →  stat update
//   Subdirectory added/removed            →  new zone / zone collapses
//
// The watcher runs on a background thread so it never blocks the render loop.
// It posts EyeEvents into a shared queue; the main thread drains it each frame.

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
	path:     string, // full path of the changed file/directory
	old_path: string, // only set for Rename
}

EyeState :: struct {
	events:  [dynamic]EyeEvent,
	mu:      sync.Mutex,
	running: bool,
	handle:  rawptr, // Win32 HANDLE to the watched directory
	thread:  ^thread.Thread,
}

// start_the_eye launches the watcher thread on watch_path.
// Post EyeEvents into eye.events — always lock eye.mu first.
start_the_eye :: proc(eye: ^EyeState, watch_path: string) {
	eye.running = true
	// TODO (Win32):
	//   1. CreateFileW(watch_path, ...) to get a directory handle
	//   2. In a loop: ReadDirectoryChangesW(handle, buf, ..., FILE_NOTIFY_CHANGE_FILE_NAME | ...)
	//   3. Walk the FILE_NOTIFY_INFORMATION chain in buf
	//   4. Translate each Action + FileName into an EyeEvent
	//   5. Lock eye.mu, append the event, unlock
	//   6. Break the loop when eye.running == false
	//
	// HINT: look up "ReadDirectoryChangesW example C++" — the Win32 API is
	// the same from Odin, you just call it via the windows import package:
	//   import win "core:sys/windows"
}

stop_the_eye :: proc(eye: ^EyeState) {
	eye.running = false
	// TODO: close the directory handle so ReadDirectoryChangesW unblocks
}

// drain_eye_events should be called once per frame from update().
// It pulls all pending events off the queue and applies them to game state.
drain_eye_events :: proc(eye: ^EyeState, s: ^GameState) {
	sync.mutex_lock(&eye.mu)
	events := eye.events[:]
	clear(&eye.events)
	sync.mutex_unlock(&eye.mu)

	for ev in events {
		// TODO: react to each EyeAction
		// Example:
		//   case .Spawn:
		//     c, ok := load_citizen(ev.path, zone_from_path(ev.path))
		//     if ok { append(&s.citizens, c) }
		//     push_event(s, ev.path, .Spawn)
		_ = ev
	}
}
