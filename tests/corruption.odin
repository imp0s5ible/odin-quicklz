package tests

import "base:intrinsics"
import "core:log"
import "core:math/rand"
import "core:slice"
import "core:testing"

import qlz "../"

CORRUPTION_ITERATIONS :: #config(CORRUPTION_ITERATIONS, 64)
CORRUPTION_MIN_DISTANCE :: #config(CORRUPTION_MIN_DISTANCE, 128)
CORRUPTION_RATIO_MIN :: #config(CORRUPTION_RATIO_MAX, 0.1)
CORRUPTION_RATIO_MAX :: #config(CORRUPTION_RATIO_MAX, 0.6)

@(test)
corruption_stress_lvl1 :: proc(t: ^testing.T) {
	corruption_file(t, {"tests/test_files/constitution.txt", "tests/test_files/bible.txt"}, 1)
}

@(test)
corruption_stress_lvl3 :: proc(t: ^testing.T) {
	corruption_file(t, {"tests/test_files/constitution.txt", "tests/test_files/bible.txt"}, 3)
}

corruption_file :: proc(t: ^testing.T, paths: []string, level: int, loc := #caller_location) {
	source_buffers, ok := fuzz_read_source_buffers(paths)
	if !ok {
		return
	}
	defer fuzz_destroy_source_buffers(source_buffers)

	test_buf := fuzz_random_source(source_buffers)
	defer delete(test_buf)

	comp := make([]u8, 9 + len(test_buf) + len(test_buf) / 2)
	dest := make([]u8, len(test_buf))
	defer delete(dest)
	defer delete(comp)

	rand.reset(t.seed)
	for test_idx in 0 ..< CORRUPTION_ITERATIONS {
		comp_size := test_compression(t, test_buf, comp, level, loc)

		corruption_ratio := rand.float64_range(CORRUPTION_RATIO_MIN, CORRUPTION_RATIO_MAX)
		corruption_count := min(int(f64(comp_size) * corruption_ratio), comp_size)
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
			testing.expect_value(t, bytes_written, len(test_buf))
			testing.expect(t, !slice.equal(dest, test_buf))
		}

		intrinsics.mem_zero(&comp[0], len(comp))
		intrinsics.mem_zero(&dest[0], len(dest))
	}
}
