package tests

import "core:testing"
import "core:os"
import "core:strings"
import wmng "../engine/world_manager"

@(test)
test_load_world_ini :: proc(t: ^testing.T) {
    // 1. Create a temporary INI file
    ini_content := "[Configuration]\nworld_name = Test World\ntick_rate = 1.5"
    ini_path := "test_world.ini"

    _ = os.write_entire_file(ini_path, transmute([]byte)ini_content)
    defer os.remove(ini_path)

    // 2. Load the INI
    world_config := wmng.load_world_ini(ini_path, 1.0)

    // 3. Convert cstring back to string for assertion
    world_name_str := string(world_config.world_name)

    // 4. Assertions
    testing.expectf(t, world_config.tick_rate == 1.5, "Expected tick_rate 1.5, got %f", world_config.tick_rate)
    testing.expectf(t, world_name_str == "Test World", "Expected world_name 'Test World', got '%s'", world_name_str)

    // 5. Free the cstring
    delete(world_config.world_name)
}
