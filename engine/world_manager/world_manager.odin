package world_manager

import "core:encoding/ini"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

/*
	load_world_ini — parses world/world.ini and returns the tick_rate value.

	The file uses the same "key = value" format as .citizen files.
	Returns the provided default if the file is missing or the field isn't found.

	Example world.ini:
    [Configuration]
	world_name = Root Directory
	tick_rate = 2.0
*/
WorldIni :: struct {
	tick_rate:  f64,
	world_name: cstring,
}

init_default_world_ini :: proc() -> WorldIni {
	return WorldIni{tick_rate = 2.0, world_name = "world"}
}


load_world_ini :: proc(ini_path: string, default_tick_rate: f64) -> WorldIni {


	file_data, success := os.read_entire_file_from_path(ini_path, context.allocator)
	if success != os.ERROR_NONE {
		fmt.eprintln("Failed to read file!", success)
	}
	defer delete(file_data)

	world_ini: WorldIni
	world_ini.tick_rate = default_tick_rate
	// Converting byte slice to a string and pass it to the iterator
	ini_string := string(file_data)

	it := ini.iterator_from_string(ini_string)

	// 2. Loop through every key/value pair
	// it.section automatically updates whenever the parser crosses a [section] header
	for key, val, ok := ini.iterate(&it); ok; key, val, ok = ini.iterate(&it) {

		if strings.to_lower(it.section) == "configuration" {
			switch key {
			case "tick_rate":
				world_ini.tick_rate, _ = strconv.parse_f64(val)
			case "world_name":
				// If values are wrapped in quotes, use strconv.unquote_string()
				// The INI parser might have already stripped outer quotes or not,
				// let's just use the value directly if it's not quoted.
				if strings.has_prefix(val, "\"") && strings.has_suffix(val, "\"") {
					unquoted, _, _ := strconv.unquote_string(val)
					world_ini.world_name = strings.clone_to_cstring(unquoted)
				} else {
					world_ini.world_name = strings.clone_to_cstring(val)
				}
			}
		}
	}
	return world_ini
}

