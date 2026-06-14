package tests

import "base:runtime"
import pq "core:container/priority_queue"
import "core:testing"

import rl "vendor:raylib"

// QUEUE SPAWNS
@(test)
test_spawn_zone_queue :: proc(t: ^testing.T) {
    file_counter :: proc() {
        
    }
	Zone :: struct {
		name:  cstring,
		path:  cstring,
        file_count: 
		pos:   rl.Vector3,
		size:  rl.Vector3,
		color: rl.Color,
	}

    q: pq.Priority_Queue(Zone)
    pq.init(
        pq = &q,
        less = proc(a, b: Zone) -> bool {
            return a.
        }
    )
}
