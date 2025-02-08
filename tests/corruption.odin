package tests

import "base:intrinsics"
import "core:log"
import "core:math/rand"
import "core:os"
import "core:slice"
import "core:testing"

import qlz "../"

CORRUPTION_TEST_ITERATIONS :: #config(CORRUPTION_TEST_ITERATIONS, 64)
CORRUPTION_MIN_DISTANCE :: #config(CORRUPTION_MIN_DISTANCE, 128)

@(test)
corruption_stress_lvl1 :: proc(t: ^testing.T) {
	corruption_file(t, "tests/test_files/constitution.txt", 1, 0.6)
}

@(test)
corruption_stress_lvl3 :: proc(t: ^testing.T) {
	corruption_file(t, "tests/test_files/constitution.txt", 3, 0.6)
}

corruption_file :: proc(
	t: ^testing.T,
	path: string,
	level: int,
	max_corruption: f64,
	loc := #caller_location,
) {
	file_content, file_read_ok := os.read_entire_file_from_filename(path)
	if !testing.expectf(nil, file_read_ok, "Failed to read file: %s", path) {
		return
	}
	defer delete(file_content)

	comp := make([]u8, 9 + len(file_content) + len(file_content) / 2)
	dest := make([]u8, len(file_content))
	defer delete(dest)
	defer delete(comp)

	rand.reset(t.seed)
	for test_idx in 0 ..< CORRUPTION_TEST_ITERATIONS {
		comp_size := test_compression(t, file_content, comp, level, loc)

		corruption_count := rand.int_max(int(f64(comp_size) * min(max_corruption, 1.0)))
		corrupted_bytes := make([]int, corruption_count)
		defer delete(corrupted_bytes)
		for i in 0 ..< corruption_count {
			rand_idx := rand.int_max(comp_size)
			comp[rand_idx] ~= u8(rand.uint32())
			corrupted_bytes[i] = rand_idx
		}

		bytes_read, bytes_written, err := qlz.decompress(dest, comp[:comp_size])
		if err != nil {
			nearest_byte: int
			nearest_byte_distance: int = -1
			for idx in corrupted_bytes {
				dist := abs(idx - bytes_read)
				if nearest_byte_distance == -1 || dist < nearest_byte_distance {
					nearest_byte_distance = dist
					nearest_byte = idx
				}
			}

			if nearest_byte_distance > CORRUPTION_MIN_DISTANCE {
				/*
                  NOTE(imp0s5ible): This is mostly for gauging the distance from a corrupted byte
                  the algorithm tends to stop, we can't really expect any hard bounds on this.

                  You can configure this via defines.
                */
				log.warn(
					"Reading did not stop within ",
					CORRUPTION_MIN_DISTANCE,
					" bytes of a corrupted byte!",
					"\nNOTE: Corrupted data resulted in ",
					err,
					" at ",
					bytes_read,
					"\nNOTE: Nearest corrupted byte is at ",
					nearest_byte,
					" at a distance of ",
					nearest_byte_distance,
					" bytes",
					"\nNOTE: Seed used was ",
					t.seed,
					"\nNOTE: Test iteration was ",
					test_idx,
					sep = "",
				)
			}
		} else {
			testing.expect_value(t, bytes_written, len(file_content))
			testing.expect(t, !slice.equal(dest, file_content))
		}

		intrinsics.mem_zero(&comp[0], len(comp))
		intrinsics.mem_zero(&dest[0], len(dest))
	}
}
