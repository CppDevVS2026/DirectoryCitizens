package engine

/*
	citizen_manager.odin
	====================
	Responsible for everything that touches the disk:

	  READING
	    load_citizen  — parse one .citizen file into a Citizen struct
	    scan_zone     — load every citizen inside a zone directory
	    scan_world    — discover all zone directories under "world/"

	  WRITING
	    save_citizen  — serialize a Citizen struct back to its .citizen file

	  HELPERS (private)
	    name_hash     — stable hash of any string (used for color picking)
	    zone_color    — pick a zone color from ZONE_PALETTE by name hash
	    citizen_color — pick a citizen color from CITIZEN_PALETTE by name hash
	    zone_layout   — return hardcoded pos+size for a known zone name

	File format (.citizen):
	  Plain text, one field per line, separated by " = " (space equals space).
	  Lines starting with # are comments. Blank lines are ignored.

	  Example  world/Market District/aldric.citizen
	  -----------------------------------------------
	  name   = Aldric
	  status = Arguing with the fishmonger
	  health = 85
	  hunger = 40
	  sleep  = 70
	  social = 60
	  pos_x  = -7.50
	  pos_y  =  0.50
	  pos_z  = -7.50
*/

import rl "vendor:raylib"
import "core:os"
import "core:fmt"
import "core:path/filepath"
import "core:strconv"
import "core:strings"

// ---------------------------------------------------------------------------
// Color palettes
// ---------------------------------------------------------------------------

/*
	ZONE_PALETTE — 8 colors used for zone boxes in the 3D world.
	Semi-transparent (alpha 200) so you can see citizens inside.

	We never assign colors by index directly. Instead we hash the zone name
	and take palette[hash % 8], so the same zone always gets the same color
	no matter what order the OS returns directories.
*/
@(private)
ZONE_PALETTE := [8]rl.Color{
	{60,  130, 210, 200}, // blue
	{80,  190,  80, 200}, // green
	{190,  80,  60, 200}, // red
	{190, 150,  40, 200}, // amber
	{120,  60, 190, 200}, // purple
	{40,  180, 170, 200}, // teal
	{190,  80, 150, 200}, // pink
	{90,   90,  90, 200}, // gray  ← The Null Quarter lands here
}

/*
	CITIZEN_PALETTE — 8 bright colors for citizen spheres.
	Fully opaque (alpha 255) so they stand out against zone boxes.
*/
@(private)
CITIZEN_PALETTE := [8]rl.Color{
	{255, 200,  80, 255}, // gold
	{100, 220, 255, 255}, // sky blue
	{255, 110, 180, 255}, // pink
	{150, 255, 150, 255}, // mint
	{255, 160, 100, 255}, // orange
	{200, 140, 255, 255}, // lavender
	{80,  210, 200, 255}, // cyan
	{255, 255, 140, 255}, // yellow
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/*
	name_hash — produces a stable u32 from any string.

	Algorithm: classic polynomial rolling hash (djb2-style).
	  h starts at 0
	  for each byte b in the string: h = h * 31 + b

	"transmute([]u8)name" reinterprets the string's memory as a byte slice
	without copying — Odin's way of saying "treat these bytes as []u8".

	Why u32? The palette arrays have 8 entries, so we just take h % 8.
	u32 is plenty of range and avoids negative modulo issues.
*/
@(private)
name_hash :: proc(name: string) -> u32 {
	h := u32(0)
	for b in transmute([]u8)name {
		h = h * 31 + u32(b)
	}
	return h
}

/*
	zone_color — returns a color from ZONE_PALETTE based on the zone name.
	Same name always returns the same color (hash is deterministic).
*/
zone_color :: proc(name: string) -> rl.Color {
	return ZONE_PALETTE[name_hash(name) % len(ZONE_PALETTE)]
}

/*
	citizen_color — returns a color from CITIZEN_PALETTE based on the citizen name.
	Same name always returns the same color.
*/
citizen_color :: proc(name: string) -> rl.Color {
	return CITIZEN_PALETTE[name_hash(name) % len(CITIZEN_PALETTE)]
}

/*
	zone_layout — returns the 3D position and size for a known zone name.

	This is a hardcoded lookup table. Each zone in "world/" has a fixed place
	in the 3D scene so that citizen pos_x/pos_z values make sense spatially
	(a citizen in Market District should be inside the Market District box).

	pos  — bottom-left-front corner of the zone box in world space (Y is always 0)
	size — width (X), height (Y), depth (Z) of the box

	Unknown zones (ones you add to disk that aren't listed here) fall through
	to the default case and get placed in a row beyond the known zones so they
	at least appear on screen. Add them to the switch when you give them a real
	position.

	fallback_index is how many unknown zones we've seen so far — used to space
	them out so they don't all stack on top of each other.
*/
@(private)
zone_layout :: proc(name: string, fallback_index: int) -> (pos: rl.Vector3, size: rl.Vector3) {
	switch name {
	case "Market District":     return {-9,  0, -9}, {7, 2.5, 7}
	case "Residential Quarter": return { 3,  0, -6}, {8, 2.0, 6}
	case "The Keep":            return {-2,  0,  4}, {5, 6.0, 5}
	case "The Archive":         return {10,  0,  0}, {6, 3.0, 5}
	case "The Null Quarter":    return {-13, 0, 10}, {5, 1.5, 5}
	case "The Jail":            return {-6,  0, 16}, {4, 5.0, 4} // tall walls, isolated
	}
	// Fallback: lay unknown zones in a row past z=16 so they're visible
	return {f32(fallback_index) * 10, 0, 16}, {6, 2, 6}
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/*
	load_citizen — reads one .citizen file from disk and returns a Citizen.

	Parameters:
	  file_path — absolute or relative path to the .citizen file
	  zone_name — the name of the zone this citizen belongs to
	              (we can't derive it from the file itself, so the caller passes it)

	Returns:
	  (Citizen, true)  on success
	  ({},      false) if the file can't be read or has no "name" field

	How parsing works:
	  1. Read the whole file into a []u8 byte slice.
	  2. Treat it as a string and walk line by line with split_lines_iterator.
	  3. Each line looks like "key = value". Find the " = " separator.
	  4. Switch on the key and store the value in the right field.
	  5. Numbers are parsed with strconv.parse_f32 — returns (value, ok bool).

	Memory:
	  Strings (name, status, zone) are cloned into context.allocator so they
	  outlive this function. The raw file bytes are deleted via "defer delete(data)"
	  — "defer" means "run this when the function exits", no matter how it exits.
*/
load_citizen :: proc(file_path: string, zone_name: string) -> (Citizen, bool) {
	// Read the entire file. err is nil on success (Odin uses nil for no-error).
	data, err := os.read_entire_file(file_path, context.allocator)
	if err != nil {return {}, false}
	defer delete(data) // free raw bytes when we leave this proc

	c    := Citizen{}
	text := string(data) // reinterpret bytes as a string (no copy)

	for raw in strings.split_lines_iterator(&text) {
		line := strings.trim_space(raw)

		// Skip blank lines and comment lines
		if line == "" || strings.has_prefix(line, "#") {continue}

		// Find the " = " separator. strings.index returns -1 if not found.
		sep := strings.index(line, " = ")
		if sep < 0 {continue}

		key := strings.trim_space(line[:sep])      // everything before " = "
		val := strings.trim_space(line[sep + 3:])  // everything after " = "

		switch key {
		case "name":
			// clone_to_cstring allocates a null-terminated C string copy.
			// Raylib draw calls want cstring, not string.
			c.name = strings.clone_to_cstring(val, context.allocator)
		case "status":
			c.status = strings.clone_to_cstring(val, context.allocator)
		case "health":
			v, ok := strconv.parse_f32(val)
			if ok {c.health = v}
		case "hunger":
			v, ok := strconv.parse_f32(val)
			if ok {c.hunger = v}
		case "sleep":
			v, ok := strconv.parse_f32(val)
			if ok {c.sleep = v}
		case "social":
			v, ok := strconv.parse_f32(val)
			if ok {c.social = v}
		case "pos_x":
			v, ok := strconv.parse_f32(val)
			if ok {c.world_pos.x = v}
		case "pos_y":
			v, ok := strconv.parse_f32(val)
			if ok {c.world_pos.y = v}
		case "pos_z":
			v, ok := strconv.parse_f32(val)
			if ok {c.world_pos.z = v}
		}
	}

	c.zone  = strings.clone_to_cstring(zone_name, context.allocator)
	c.path  = strings.clone_to_cstring(file_path, context.allocator)
	c.color = citizen_color(string(c.name) if c.name != nil else "")

	// A citizen with no name is malformed — reject it
	if c.name == nil {return {}, false}
	return c, true
}

/*
	scan_zone — loads every .citizen file inside a zone directory.

	Parameters:
	  dir_path  — path to the zone directory (e.g. "world/Market District")
	  zone_name — display name for the zone (passed through to each Citizen)

	Returns a [dynamic]Citizen — a heap-allocated growable array.
	The CALLER is responsible for deleting it when done:
	  citizens := scan_zone(...)
	  defer delete(citizens)

	How it works:
	  1. Open the directory with os.open.
	  2. os.read_dir returns a slice of File_Info structs (name, size, is_dir, etc.)
	  3. Skip anything that doesn't have the ".citizen" extension.
	  4. Build the full path with filepath.join and call load_citizen.
	  5. Append successful results to the output array.
*/
scan_zone :: proc(dir_path: string, zone_name: string) -> [dynamic]Citizen {
	result: [dynamic]Citizen

	handle, open_err := os.open(dir_path)
	if open_err != nil {return result} // return empty array if dir doesn't exist
	defer os.close(handle)

	// -1 means "read all entries at once"
	infos, read_err:= os.read_dir(handle, -1, context.allocator) 
	defer os.file_info_slice_delete(infos, context.allocator)

	for info in infos {
		// filepath.ext returns ".citizen" (with the dot)
		if filepath.ext(info.name) != ".citizen" {continue}

		// Build "world/Market District/aldric.citizen"
		full_path, _ := filepath.join({dir_path, info.name})
		defer delete(full_path)

		if c, ok := load_citizen(full_path, zone_name); ok {
			append(&result, c)
		}
	}

	return result
}

/*
	scan_world — discovers all zone directories under the world root.

	Parameters:
	  world_path — path to the root world directory (e.g. "world")

	Returns a [dynamic]Zone.
	The CALLER is responsible for deleting it.

	How it works:
	  1. Open the world root directory.
	  2. Walk every entry. If info.is_dir is true, it's a zone.
	  3. Look up the position and size from zone_layout (hardcoded table).
	  4. Assign a color by hashing the zone name.
	  5. Clone name and path strings into permanent memory (cstring).

	Note: world.cfg is a file in this directory, not a subdir, so it's
	automatically skipped by the "if !info.is_dir" check.
*/
scan_world :: proc(world_path: string) -> [dynamic]Zone {
	result: [dynamic]Zone

	handle, open_err := os.open(world_path)
	if open_err != nil {return result}
	defer os.close(handle)

	infos, _ := os.read_dir(handle, -1, context.allocator)
	defer os.file_info_slice_delete(infos, context.allocator)

	fallback := 0 // counter for zones not in the layout table
	for info in infos {
		if !os.is_dir(info.fullpath) {continue} // skip files like world.cfg

		name      := info.name
		path, _   := filepath.join({world_path, name})
		pos, size := zone_layout(name, fallback)

		// Track how many unknown zones we've seen for spacing
		switch name {
		case "Market District", "Residential Quarter", "The Keep",
		     "The Archive", "The Null Quarter", "The Jail":
			// known zone — no fallback increment needed
		case:
			fallback += 1
		}

		append(&result, Zone{
			name  = strings.clone_to_cstring(name, context.allocator),
			path  = strings.clone_to_cstring(path, context.allocator),
			pos   = pos,
			size  = size,
			color = zone_color(name),
		})
	}

	return result
}

// ---------------------------------------------------------------------------
// World config
// ---------------------------------------------------------------------------

/*
	load_world_cfg — parses world/world.cfg and returns the tick_rate value.

	The file uses the same "key = value" format as .citizen files.
	Returns the provided default if the file is missing or the field isn't found.

	Example world.cfg:
	  world_name = Root Directory
	  tick_rate  = 2.0
*/
load_world_cfg :: proc(cfg_path: string, default_tick_rate: f64) -> f64 {
	data, err := os.read_entire_file(cfg_path, context.allocator)
	if err != nil { return default_tick_rate }
	defer delete(data)

	tick_rate := default_tick_rate
	text      := string(data)

	for raw in strings.split_lines_iterator(&text) {
		line := strings.trim_space(raw)
		if line == "" || strings.has_prefix(line, "#") { continue }

		sep := strings.index(line, " = ")
		if sep < 0 { continue }

		key := strings.trim_space(line[:sep])
		val := strings.trim_space(line[sep + 3:])

		if key == "tick_rate" {
			if v, ok := strconv.parse_f64(val); ok {
				tick_rate = v
			}
		}
	}

	return tick_rate
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/*
	save_citizen — writes a Citizen struct back to disk as a .citizen file.

	Parameters:
	  c         — the citizen to serialize
	  file_path — where to write (overwrites if it exists)

	Returns true on success, false if the write failed.

	How it works:
	  1. Build the file content in a strings.Builder (an in-memory string buffer).
	  2. fmt.sbprintf writes formatted text into the builder — like printf but
	     into a buffer instead of stdout.
	  3. strings.to_string returns the builder's content as a string (no copy).
	  4. transmute([]u8) reinterprets the string as bytes for os.write_entire_file.
	  5. The builder is freed on exit via defer strings.builder_destroy.

	This is the inverse of load_citizen — the format must match exactly so a
	round-trip (save then load) gives back the same values.
*/
save_citizen :: proc(c: Citizen, file_path: string) -> bool {
	b: strings.Builder
	strings.builder_init(&b, context.allocator)
	defer strings.builder_destroy(&b)

	fmt.sbprintf(&b, "name   = %s\n",   c.name)
	fmt.sbprintf(&b, "status = %s\n",   c.status)
	fmt.sbprintf(&b, "health = %.0f\n", c.health)
	fmt.sbprintf(&b, "hunger = %.0f\n", c.hunger)
	fmt.sbprintf(&b, "sleep  = %.0f\n", c.sleep)
	fmt.sbprintf(&b, "social = %.0f\n", c.social)
	fmt.sbprintf(&b, "pos_x  = %.2f\n", c.world_pos.x)
	fmt.sbprintf(&b, "pos_y  = %.2f\n", c.world_pos.y)
	fmt.sbprintf(&b, "pos_z  = %.2f\n", c.world_pos.z)

	text := strings.to_string(b)
	// os.write_entire_file returns os.Error, not bool.
	// nil means success — so we convert: (err == nil) gives us the bool we return.
	err := os.write_entire_file(file_path, transmute([]u8)text)
	return err == nil
}
