package tests

import qlz "../"
import "base:intrinsics"
import "core:log"
import "core:mem"
import "core:os"
import "core:slice"
import "core:testing"
import "core:time"

RUN_BENCHMARKS :: #config(BENCHMARK, false)

when (RUN_BENCHMARKS) {
	@(test)
	benchmark_constitution :: proc(t: ^testing.T) {
		benchmark_file(t, "tests/test_files/constitution.txt", 1, 5)
		benchmark_file(t, "tests/test_files/constitution.txt", 3, 5)
	}


	@(test)
	benchmark_bible :: proc(t: ^testing.T) {
		benchmark_file(t, "tests/test_files/bible.txt", 1, 5)
		benchmark_file(t, "tests/test_files/bible.txt", 3, 5)
	}
}


@(private = "file")
benchmark_file :: proc(t: ^testing.T, path: string, level: int, copies: int) {
	file_content, file_read_ok := os.read_entire_file_from_filename(path)
	if !testing.expectf(nil, file_read_ok, "Failed to read file: %s", path) {
		return
	}
	content := make([]u8, len(file_content) * copies)
	for c in 0 ..< copies {
		intrinsics.mem_copy(&content[c * len(file_content)], &file_content[0], len(file_content))
	}
	delete(file_content)
	defer delete(content)

	opts: time.Benchmark_Options

	log.info("--- BENCH BEGIN ---")
	defer log.info("--- BENCH END ---")
	log.infof("File: %s (x%d)", path, copies)
	log.infof("File size: %3.2f Mb", f64(len(content)) / f64(mem.Megabyte))
	log.info("Compression level:", level)

	{
		log.info("-- Compression:")
		opts.setup = bench_setup_comp
		opts.bench = bench_comp
		opts.input = content
		opts.rounds = level
		time.benchmark(&opts)

		testing.expect_value(t, opts.processed, len(content))

		comp_sizef := f64(len(opts.output)) / f64(mem.Megabyte)
		log.infof(
			"Compressed size: %3.2f Mb (%.0f:1)",
			comp_sizef,
			(f64(len(content)) / f64(mem.Megabyte)) / comp_sizef,
		)
		print_results(opts)
	}

	{
		log.info("-- Decompression:")
		opts.setup = bench_setup_dec
		opts.bench = bench_dec
		opts.input = opts.output
		time.benchmark(&opts)

		testing.expect_value(t, opts.processed, len(opts.input))
		testing.expect(t, slice.equal(opts.output, content))

		print_results(opts)

		delete(opts.input)
		delete(opts.output)
	}
}

@(private = "file")
print_results :: proc(opts: time.Benchmark_Options, loc := #caller_location) {
	log.infof("Total duration: %3.1f ms", f64(opts.duration) / 1000000.0, location = loc)
	log.infof("Processed: %3.2f Mb", f64(opts.processed) / f64(mem.Megabyte), location = loc)
	log.infof("Speed: %3.2f Mb/s", opts.megabytes_per_second, location = loc)
	log.infof("CPU Counts: %3.2f gigacycles", f64(opts.rounds) / (1000.0 * 1000.0), location = loc)
}

@(private = "file")
bench_comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> (
	err: time.Benchmark_Error,
) {
	time_before := intrinsics.read_cycle_counter()
	bytes_read, bytes_written, com_err := qlz.compress(
		options.output,
		options.input,
		options.rounds,
	)
	options.output = options.output[:bytes_written]
	options.rounds = int(intrinsics.read_cycle_counter() - time_before)
	testing.expect_value(nil, com_err, nil)
	options.count = 1
	options.processed = bytes_read
	return
}


@(private = "file")
bench_dec :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> (
	err: time.Benchmark_Error,
) {
	time_before := intrinsics.read_cycle_counter()
	qlz.decompress(options.output, options.input)
	options.rounds = int(intrinsics.read_cycle_counter() - time_before)
	options.count = 1
	options.processed = len(options.input)
	return
}


@(private = "file")
bench_setup_comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> (
	err: time.Benchmark_Error,
) {
	options.output = make([]u8, 9 + len(options.input) + len(options.input) / 2)
	options.bytes = len(options.input)
	return
}


@(private = "file")
bench_teardown :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> (
	err: time.Benchmark_Error,
) {
	delete(options.output)
	return
}


@(private = "file")
bench_setup_dec :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> (
	err: time.Benchmark_Error,
) {
	header, read_err := qlz.read_header(options.input)
	if read_err != nil {
		err = .Allocation_Error
		return
	}
	options.output = make([]u8, header.decompressed_size)
	options.bytes = len(options.input)
	return
}
