package tests

import "base:intrinsics"
import "core:log"
import "core:math/rand"
import "core:os"
import "core:testing"

FUZZ_ITERATIONS :: #config(FUZZ_ITERATIONS, 64)
FUZZ_BUF_MIN :: #config(FUZZ_SRC_MIN, 128)
FUZZ_BUF_MAX :: #config(FUZZ_SRC_MIN, 1024 * 1024 * 10)
FUZZ_SNIPPET_MIN :: #config(FUZZ_SNIPPET_MIN, 12)
FUZZ_SNIPPET_MAX :: #config(FUZZ_SNIPPET_MAX, 1024 * 1024)

RUN_FUZZ :: #config(RUN_FUZZ, true)

@(rodata)
FUZZ_SOURCE_BUFFER: string = "abcdefghijklmnopqrstuvwxyz0123456789-="

when RUN_FUZZ {
	@(test)
	fuzz_lvl1 :: proc(t: ^testing.T) {
		fuzz(t, {"tests/test_files/constitution.txt", "tests/test_files/bible.txt"}, 1)
	}

	@(test)
	fuzz_lvl3 :: proc(t: ^testing.T) {
		fuzz(t, {"tests/test_files/constitution.txt", "tests/test_files/bible.txt"}, 3)
	}
}

fuzz :: proc(t: ^testing.T, paths: []string, level: int, loc := #caller_location) {
	rand.reset(t.seed)

	source_buffers, ok := fuzz_read_source_buffers(paths)
	if !ok {
		return
	}
	defer fuzz_destroy_source_buffers(source_buffers)

	for iter_idx in 0 ..< FUZZ_ITERATIONS {
		test_buf := fuzz_random_source(source_buffers, loc)
		defer delete(test_buf)

		roundtrip(t, test_buf, level, loc)
		if t.error_count != 0 {
			log.error(
				"\nNOTE: Test buffer length was ",
				len(test_buf),
				"\nNOTE: Seed was ",
				t.seed,
				"\nNOTE: Test iteration was ",
				iter_idx,
				sep = "",
			)
		}
	}
}

fuzz_random_source :: proc(source_buffers: [][]u8, loc := #caller_location) -> []u8 {
	test_size := FUZZ_BUF_MIN + rand.int_max(FUZZ_BUF_MAX - FUZZ_BUF_MIN)
	test_buf := make([]u8, test_size)
	fill_test_buffer(test_buf, source_buffers)
	return test_buf
}


fuzz_read_source_buffers :: proc(
	paths: []string,
	loc := #caller_location,
) -> (
	result: [][]u8,
	ok: bool,
) {
	if len(paths) == 0 {
		ok = true
		return
	}

	result = make([][]u8, len(paths))
	defer if !ok {
		fuzz_destroy_source_buffers(result)
	}
	for &path, i in paths {
		file_content, file_read_ok := os.read_entire_file_from_filename(path)
		if !testing.expectf(nil, file_read_ok, "Failed to read file: %s", path, loc = loc) {
			return
		}
		result[i] = file_content
	}
	ok = true
	return
}

fuzz_destroy_source_buffers :: proc(source_buffers: [][]u8) {
	for &buf in source_buffers {
		if len(buf) != 0 {
			delete(buf)
			buf = {}
		}
	}
	delete(source_buffers)
}


fill_test_buffer :: proc(buf: []u8, source_buffers: [][]u8) {
	cursor: int
	for cursor < len(buf) {
		snippet_length := min(
			FUZZ_SNIPPET_MIN + rand.int_max(FUZZ_SNIPPET_MAX - FUZZ_SNIPPET_MIN),
			len(buf) - cursor,
		)
		snippet_type := rand.int_max(3 + len(source_buffers))
		switch snippet_type {
		case 0:
			fill_snippet(buf[cursor:], transmute([]u8)FUZZ_SOURCE_BUFFER, snippet_length)
		case 1:
			for i in 0 ..< snippet_length {
				buf[cursor + i] = u8(rand.uint32())
			}
		case 2:
			intrinsics.mem_zero(&buf[cursor], snippet_length)
		case:
			idx := (snippet_type - 2) % len(source_buffers)
			source := source_buffers[idx]
			fill_snippet(buf, source, snippet_length)
		}
		cursor += snippet_length
	}
}


@(private = "file")
fill_snippet :: #force_inline proc(buf: []u8, src: []u8, snippet_length: int) {
	assert(len(src) != 0)
	snippet_length := snippet_length
	start := rand.int_max(len(src))
	cursor: int
	for snippet_length > 0 {
		copied := min(snippet_length, len(src) - start)
		intrinsics.mem_copy(&buf[cursor], &src[0], copied)
		cursor += copied
		start += copied
		start %= len(src)
		snippet_length -= copied
	}
}
