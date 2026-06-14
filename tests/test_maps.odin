package tests

import "core:testing"
import types "../engine"

@(test)
test_citizen_map :: proc(t: ^testing.T) {
    citizen_map: map[string]int

    citizen_map["age"] = 23
    delete_key(&citizen_map, "age")

    age, ok := citizen_map["age"]; ok {
        
    }

}