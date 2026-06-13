package main

// CitizenManager — reads and writes .citizen files.
//
// Each .citizen file lives inside a zone directory.
// Format is plain key = value, one field per line.
//
// Example  world/Market District/aldric.citizen:
//   name   = Aldric
//   health = 85
//   hunger = 40
//   sleep  = 70
//   social = 60
//   status = Trading goods

import "core:os"
import "core:strings"
import "core:strconv"
import "core:path/filepath"

// load_citizen parses a single .citizen file into a Citizen struct.
// Returns the Citizen and true on success, false on any read/parse error.
load_citizen :: proc(file_path: string, zone_name: string) -> (Citizen, bool) {
	data, err := os.read_entire_file(file_path, context.allocator)
	if err != nil { return {}, false }
	defer delete(data)

	c    := Citizen{}
	text := string(data)

	// Walk line by line
	for raw in strings.split_lines_iterator(&text) {
		line := strings.trim_space(raw)
		if line == "" || strings.has_prefix(line, "#") { continue }

		sep := strings.index(line, " = ")
		if sep < 0 { continue }

		key := strings.trim_space(line[:sep])
		val := strings.trim_space(line[sep + 3:])

		switch key {
		case "name":
			c.name = strings.clone_to_cstring(val, context.allocator)
		case "status":
			c.status = strings.clone_to_cstring(val, context.allocator)
		case "health":
			// TODO: parse val into c.health
			// HINT: v, ok := strconv.parse_f32(val)
			//       if ok { c.health = v }
		case "hunger":
			// TODO: c.hunger
		case "sleep":
			// TODO: c.sleep
		case "social":
			// TODO: c.social
		}
	}

	c.zone = strings.clone_to_cstring(zone_name, context.allocator)
	if c.name == nil { return {}, false }
	return c, true
}

// scan_zone opens a directory and loads every *.citizen file it finds.
// Returns a dynamic array of Citizens — caller owns it.
scan_zone :: proc(dir_path: string, zone_name: string) -> [dynamic]Citizen {
	result: [dynamic]Citizen

	// TODO: open the directory, iterate files, call load_citizen on each .citizen
	handle, open_err := os.open(dir_path) 
	if open_err != nil { return result }
	defer os.close(handle)

	// TODO: read the directory entries 
	infos, read_err := os.read_dir(handle, -1, context.allocator)
	for info in infos {
		if filepath.ext(info.name) == ".citizen" {
			full_path, _ := filepath.join({dir_path, info.name})
			c, ok := load_citizen(full_path, zone_name)
			if ok { append(&result, c) }
		}
	}

	_ = filepath.ext // suppress unused import until you use it
	return result
}

// save_citizen writes a Citizen back to disk as a .citizen file.
save_citizen :: proc(c: Citizen, file_path: string) -> bool {
	// TODO: build the key = value string and call os.write_entire_file
	// HINT: use strings.Builder to assemble the text, then:
	//   os.write_entire_file(file_path, transmute([]byte)result_string)
	return false
}
