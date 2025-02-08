package quicklz

import "base:intrinsics"
import "base:runtime"

MAX_COMPRESSION_SIZE :: UINT32_MAX - 400

HASH_TABLE_COUNT :: 1 << 4

CompressionLvl1ScratchSpace :: struct {
	hash_table:        HashTable,
	cache_table:       CacheTable,
	hash_counter_bits: HashCounterBits,
}

CompressionLvl3ScratchSpace :: struct {
	hash_counter:   [HASH_TABLE_SIZE]u8,
	hash_table_arr: [HASH_TABLE_COUNT]HashTable,
}

CompressionError :: union {
	NoScratchSpaceProvided,
	FailedToAllocateScratchSpace,
	SourceTooLarge,
	BufferAccessError,
	UnsupportedCompressionLevel,
}

SourceTooLarge :: struct {
	length:     int,
	max_length: int,
}

compress :: proc {
	compress_with_allocator,
	compress_with_scratch,
}

compress_with_allocator :: proc(
	dest: []u8,
	src: []u8,
	level: int,
	scratch_allocator := context.temp_allocator,
	loc := #caller_location,
) -> (
	bytes_read: int,
	bytes_written: int,
	err: CompressionError,
) {
	scratch: rawptr
	alloc_err: runtime.Allocator_Error
	switch level {
	case 1:
		scratch, alloc_err = new(CompressionLvl1ScratchSpace, scratch_allocator, loc)
	case 3:
		scratch, alloc_err = new(CompressionLvl3ScratchSpace, scratch_allocator, loc)
	}
	if alloc_err != nil {
		err = FailedToAllocateScratchSpace {
			error = alloc_err,
		}
		return
	}
	return compress_with_scratch(dest, src, level, scratch)
}

compress_with_scratch :: proc(
	dest: []u8,
	src: []u8,
	level: int,
	scratch: rawptr,
) -> (
	bytes_read: int,
	bytes_written: int,
	err: CompressionError,
) #no_bounds_check {
	if len(src) > MAX_COMPRESSION_SIZE {
		err = SourceTooLarge{len(src), MAX_COMPRESSION_SIZE}
		return
	}
	if scratch == nil {
		err = NoScratchSpaceProvided{}
		return
	}

	header_len: int
	if len(src) < 216 {
		header_len = 3
	} else {
		header_len = 9
	}
	if len(dest) < header_len {
		err = BufferAccessError(
			DestinationBufferTooSmall{expected_len = header_len, actual_len = len(dest)},
		)
		return
	}

	control: u32 = 1 << 31
	control_pos := header_len
	src_cursor := &bytes_read
	dest_cursor := &bytes_written
	dest_cursor^ = header_len + 4

	switch level {
	case 1:
		scratch := (^CompressionLvl1ScratchSpace)(scratch)
		scratch^ = {}

		literal_count := 0

		for src_cursor^ + 10 < len(src) {
			if !(begin_sector(
					   &control,
					   dest,
					   dest_cursor,
					   src,
					   src_cursor,
					   level,
					   &control_pos,
				   ) or_return) {
				return
			}

			next := read_u24(src[src_cursor^:])
			hash := hash(next)
			offset := scratch.hash_table[int(hash)]
			cache := scratch.cache_table[int(hash)]
			counter := get_bit(scratch.hash_counter_bits, int(hash))

			scratch.cache_table[int(hash)] = next
			scratch.hash_table[int(hash)] = (u32)(src_cursor^)

			if cache == next &&
			   counter &&
			   (src_cursor^ - int(offset) >= 3 ||
					   src_cursor^ == int(offset + 1) &&
						   literal_count >= 3 &&
						   src_cursor^ > 3 &&
						   is_homogeneous(src[src_cursor^ - 3:src_cursor^ + 3])) {
				control = (control >> 1) | (1 << 31)
				matchlen := 3
				remainder := min(len(src) - 4 - src_cursor^, 0xff)
				for src[int(offset) + matchlen] == src[src_cursor^ + matchlen] &&
				    matchlen < remainder {
					matchlen += 1
				}

				if matchlen < 18 {
					cursor_write(
						dest,
						dest_cursor,
						u16le(u16(hash) << 4 | u16(matchlen - 2)),
					) or_return
				} else {
					cursor_write_u24(dest, dest_cursor, hash << 4 | u32(matchlen) << 16) or_return
				}
				src_cursor^ += matchlen
				literal_count = 0
			} else {
				literal_count += 1
				set_bit(&scratch.hash_counter_bits, int(hash), true)

				cursor_copy(u8, dest, dest_cursor, src, src_cursor) or_return
				control >>= 1
			}
		}
	case 3:
		scratch := (^CompressionLvl3ScratchSpace)(scratch)
		scratch^ = {}

		for src_cursor^ + 10 < len(src) {
			if !(begin_sector(
					   &control,
					   dest,
					   dest_cursor,
					   src,
					   src_cursor,
					   level,
					   &control_pos,
				   ) or_return) {
				return
			}

			next := (^[3]u8)(&src[src_cursor^:][:3][0])^
			remainder := min(len(src) - 4 - src_cursor^, 0xff)
			hash_value := int(hash(read_u24(next[:])))
			counter := scratch.hash_counter[hash_value]
			matchlen := 0
			offset := 0

			for &hashtable, i in scratch.hash_table_arr {
				if i >= int(counter) {
					break
				}

				hash_offset := int(hashtable[hash_value])
				content_at_offset := (^[3]u8)(&src[hash_offset:][:3][0])^

				if content_at_offset == next && hash_offset + 2 < src_cursor^ {
					m := 3
					for src[hash_offset + m] == src[src_cursor^ + m] && m < remainder {
						m += 1
					}

					if m > matchlen || (m == matchlen && hash_offset > offset) {
						offset = hash_offset
						matchlen = m
					}
				}
			}

			scratch.hash_table_arr[int(counter) % HASH_TABLE_COUNT][hash_value] = u32(src_cursor^)
			scratch.hash_counter[hash_value] = counter + 1

			if matchlen >= 3 && src_cursor^ - offset < 0x1ffff {
				// We write a back-reference
				offset = src_cursor^ - offset
				assert(offset != 0)

				for u in 1 ..< matchlen {
					hash := int(hash(read_u24(src[src_cursor^ + u:])))
					hash_counter := scratch.hash_counter[hash]

					scratch.hash_counter[hash] = hash_counter + 1
					scratch.hash_table_arr[int(hash_counter) % HASH_TABLE_COUNT][hash_value] = u32(
						src_cursor^ + u,
					)
				}

				src_cursor^ += matchlen
				control = (control >> 1) | (1 << 31)

				// Last 2 bits is offset magnitude
				if matchlen == 3 && offset < (1 << 6) {
					// Magnitude 0, mag on 2 bits, offset on 6 bits, length implicit 3
					cursor_write(dest, dest_cursor, u8(offset << 2)) or_return
				} else if matchlen == 3 && offset < (1 << 14) {
					// Magnitude 1, mag on 2 bits, offset on 14 bits, length implicit 3
					cursor_write(dest, dest_cursor, u16le((offset << 2) | 1)) or_return
				} else if (matchlen - 3) < (1 << 4) && offset < (1 << 10) {
					// Magnitude 2, mag on 2 bits, offset on 10 bits, length - 3 on 4 bits
					cursor_write(
						dest,
						dest_cursor,
						u16le(((offset << 6) | ((matchlen - 3) << 2) | 2)),
					) or_return
				} else if (matchlen - 2) < (1 << 5) {
					// Magnitude 3, mag on 2 bits, length - 2 on 5 bits, offset on 25 bits
					cursor_write_u24(
						dest,
						dest_cursor,
						u32((offset << 7) | ((matchlen - 2) << 2) | 3),
					) or_return
				} else {
					// Magnitude 3a, mag on 7 bits, length - 3 on 8 bits, offset on 17 bits, 
					cursor_write(
						dest,
						dest_cursor,
						u32le(((offset << 15) | ((matchlen - 3) << 7) | 3)),
					) or_return
				}
			} else {
				cursor_copy(u8, dest, dest_cursor, src, src_cursor) or_return
				control >>= 1
			}
		}
	case:
		err = UnsupportedCompressionLevel {
			level = level,
		}
		return
	}

	for src_cursor^ < len(src) {
		if control & 1 != 0 {
			write_control(dest[control_pos:], (control >> 1) | (1 << 31))
			control_pos = dest_cursor^
			cursor_write(dest, dest_cursor, u32le(0)) or_return
			control = 1 << 31
		}
		cursor_copy(u8, dest, dest_cursor, src, src_cursor) or_return
		control >>= 1
	}

	for control & 1 == 0 {
		control >>= 1
	}
	write_control(dest[control_pos:], (control >> 1) | (1 << 31))

	write_header(dest[:header_len], dest_cursor^, len(src), level, true)

	return
}

is_homogeneous :: #force_inline proc "contextless" (buf: []u8) -> bool #no_bounds_check {
	assert_contextless(len(buf) != 0)

	for v in buf[1:] {
		if v != buf[0] {
			return false
		}
	}

	return true
}

@(private = "file")
begin_sector :: #force_inline proc "contextless" (
	control: ^u32,
	dest: []u8,
	dest_cursor: ^int,
	src: []u8,
	src_pos: ^int,
	level: int,
	control_pos: ^int,
) -> (
	can_continue: bool,
	err: CompressionError,
) #no_bounds_check {
	if control^ & 1 != 0 {
		if src_pos^ > 3 * (len(src) / 4) && dest_cursor^ > src_pos^ - (src_pos^ / 32) {
			// Failed to compress buffer, write header + uncompressed data instead
			headerlen: int
			if len(src) < 216 {headerlen = 3} else {headerlen = 9}

			if len(dest) < headerlen + len(src) {
				err = BufferAccessError(
					DestinationBufferTooSmall {
						expected_len = headerlen + len(src),
						actual_len = len(dest),
					},
				)
				return
			}

			write_header(dest[:headerlen], headerlen + len(src), len(src), level, false)
			intrinsics.mem_copy(&dest[headerlen], &src[0], len(src))
			dest_cursor^ = headerlen + len(src)
			src_pos^ = len(src)
			return
		} else {
			write_control(dest[control_pos^:], (control^ >> 1) | (1 << 31))
			control_pos^ = dest_cursor^
			cursor_write(dest, dest_cursor, u32le(0)) or_return
			control^ = 1 << 31
		}
	}

	can_continue = true
	return
}

write_control :: #force_inline proc "contextless" (dest: []u8, control: u32) #no_bounds_check {
	assert_contextless(len(dest) >= size_of(u32le))
	intrinsics.unaligned_store((^u32le)(&dest[0]), (u32le)(control))
}

write_header :: #force_inline proc "contextless" (
	dest: []u8,
	dest_total_len: int,
	src_total_len: int,
	level: int,
	compressed: bool,
) #no_bounds_check {
	flags: u8
	if compressed {
		flags = u8(0x01 | (level << 2) | 0x40)
	} else {
		flags = u8((level << 2) | 0x40)
	}

	if len(dest) == 3 {
		dest[0] = u8(flags)
		dest[1] = u8(dest_total_len)
		dest[2] = u8(src_total_len)
	} else if len(dest) == 9 {
		dest[0] = u8(flags | 0x02)
		intrinsics.unaligned_store(
			(^[2]u32le)(&dest[1]),
			{u32le(dest_total_len), u32le(src_total_len)},
		)
	} else {
		unreachable()
	}
}

cursor_write :: #force_inline proc "contextless" (
	dest: []u8,
	dest_cursor: ^int,
	src: $T,
) -> CompressionError #no_bounds_check {
	if dest_cursor^ + size_of(T) > len(dest) {
		return BufferAccessError(
			DestinationBufferTooSmall {
				expected_len = dest_cursor^ + size_of(T),
				actual_len = len(dest),
			},
		)
	}
	intrinsics.unaligned_store((^T)(&dest[dest_cursor^]), src)
	dest_cursor^ += size_of(T)

	return nil
}


@(private = "file")
cursor_write_u24 :: #force_inline proc "contextless" (
	dest: []u8,
	dest_cursor: ^int,
	src: u32,
) -> CompressionError #no_bounds_check {
	le := u32le(src)
	u24 := (^[3]u8)(&le)^
	return cursor_write(dest, dest_cursor, u24)
}

@(private = "file")
CacheTable :: distinct [HASH_TABLE_SIZE]u32
@(private = "file")
CacheCounter :: distinct [HASH_TABLE_SIZE]u8
@(private = "file")
HashCounterBits :: BitArray(HASH_TABLE_SIZE)

@(private = "file")
INDEX_SHIFT :: 6

@(private = "file")
INDEX_MASK :: 63

@(private = "file")
BitArray :: struct($N: int) where N > 0 {
	bits: [(N - 1) / size_of(u64) + 1]u64,
}


@(private = "file")
get_bit :: #force_inline proc(
	arr: BitArray($N),
	#any_int index: int,
) -> (
	result: bool,
) #no_bounds_check {
	assert_contextless(index < N)

	leg_index := index >> INDEX_SHIFT
	bit_index := index & INDEX_MASK

	val := u64(1 << uint(bit_index))
	result = arr.bits[leg_index] & val == val

	return
}


@(private = "file")
set_bit :: #force_inline proc "contextless" (
	arr: ^BitArray($N),
	#any_int index: int,
	set_to: bool = true,
) #no_bounds_check {
	assert_contextless(index < N)

	leg_index := index >> INDEX_SHIFT
	bit_index := index & INDEX_MASK

	if set_to {
		arr.bits[leg_index] |= 1 << uint(bit_index)
	} else {
		arr.bits[leg_index] &~= 1 << uint(bit_index)
	}
}
