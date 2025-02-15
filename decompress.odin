package quicklz

import "base:intrinsics"

DecompressionScratchSpace :: HashTable

DecompressionError :: union {
	NoScratchSpaceProvided,
	FailedToAllocateScratchSpace,
	BufferAccessError,
	InvalidBackReference,
	UnsupportedCompressionLevel,
	CompressedSizeTooSmall,
	InvalidUncompressedBuffer,
	ZeroControlByteEncountered,
	ReferenceTooSmall,
	ReferenceTooLarge,
	ReferenceOffsetTooLarge,
	InvalidHashTableEntry,
	DecompressedSizeExceeded,
	NotAllOfSourceBufferWasUsed,
	NotAllOfDestBufferWasFilled,
}

BufferAccessError :: union {
	EmptySourceBuffer,
	SourceBufferTooSmall,
	DestinationBufferTooSmall,
	AccessViolation,
}

EmptySourceBuffer :: struct {}
NoScratchSpaceProvided :: struct {}
InvalidBackReference :: struct {
	offset: int,
	length: int,
}
UnsupportedCompressionLevel :: struct {
	level: int,
}
DestinationBufferTooSmall :: struct {
	expected_len: int,
	actual_len:   int,
}
CompressedSizeTooSmall :: struct {
	compressed_size:     int,
	min_compressed_size: int,
}
SourceBufferTooSmall :: struct {
	compressed_size:    int,
	source_buffer_size: int,
}
InvalidUncompressedBuffer :: struct {
	expected_len: int,
	actual_len:   int,
}
ZeroControlByteEncountered :: struct {
	at: int,
}
ReferenceTooSmall :: struct {
	length:     int,
	min_length: int,
}
ReferenceTooLarge :: struct {
	length:     int,
	max_length: int,
}
ReferenceOffsetTooLarge :: struct {
	offset:     int,
	max_offset: int,
}
InvalidHashTableEntry :: struct {
	hash:     int,
	max_hash: int,
}
DecompressedSizeExceeded :: struct {
	cursor:            int,
	decompressed_size: int,
}
NotAllOfDestBufferWasFilled :: struct {
	filled:  int,
	desired: int,
}
NotAllOfSourceBufferWasUsed :: struct {
	used:   int,
	length: int,
}
AccessViolation :: struct {
	at: int,
}

Header :: struct {
	header_len:        int,
	compressed_size:   int,
	decompressed_size: int,
	flags:             u8,
	level:             u8,
}

read_header :: proc {
	read_header_from_start,
	read_header_with_cursor,
}

read_header_from_start :: proc(src: []u8) -> (Header, DecompressionError) {
	src_cursor: int
	return read_header_with_cursor(src, &src_cursor)
}

read_header_with_cursor :: proc(
	src: []u8,
	src_cursor: ^int,
) -> (
	result: Header,
	err: DecompressionError,
) {
	if len(src) == 0 {
		err = BufferAccessError(EmptySourceBuffer{})
		return
	}

	result.flags = cursor_read(u8, src, src_cursor) or_return
	result.level = (result.flags >> 2) & 0b11

	result.header_len = 3
	if result.flags & 2 == 2 {
		result.header_len = 9
	}

	if result.header_len == 3 {
		if src_cursor^ + 2 > len(src) {
			err = BufferAccessError(AccessViolation{at = src_cursor^ + 2})
			return
		}
		result.compressed_size = int(src[src_cursor^])
		result.decompressed_size = int(src[src_cursor^ + 1])
		src_cursor^ += 2
	} else {
		result.compressed_size = int(cursor_read(u32le, src, &src_cursor^) or_return)
		result.decompressed_size = int(cursor_read(u32le, src, &src_cursor^) or_return)
	}

	return
}

decompress :: proc {
	decompress_with_allocator,
	decompress_with_scratch,
}

decompress_with_allocator :: proc(
	dest: []u8,
	src: []u8,
	allocator := context.temp_allocator,
) -> (
	bytes_read: int,
	bytes_written: int,
	err: DecompressionError,
) {
	scratch, alloc_err := new(DecompressionScratchSpace, allocator)
	if alloc_err != nil {
		err = FailedToAllocateScratchSpace {
			error = alloc_err,
		}
		return
	}
	return decompress_with_scratch(dest, src, scratch)
}

decompress_with_scratch :: proc(
	dest: []u8,
	src: []u8,
	hash_table: ^DecompressionScratchSpace,
) -> (
	bytes_read: int,
	bytes_written: int,
	err: DecompressionError,
) #no_bounds_check {
	src_cursor := &bytes_read
	header := read_header(src, src_cursor) or_return

	if header.level != 1 && header.level != 3 {
		err = UnsupportedCompressionLevel {
			level = int(header.level),
		}
		return
	} else if header.level == 1 {
		if hash_table == nil {
			err = NoScratchSpaceProvided{}
			return
		}
		hash_table^ = {}
	}

	if header.decompressed_size > len(dest) {
		err = BufferAccessError(
			DestinationBufferTooSmall {
				expected_len = header.decompressed_size,
				actual_len = len(dest),
			},
		)
		return
	}
	if header.compressed_size < header.header_len {
		err = CompressedSizeTooSmall {
			compressed_size     = header.compressed_size,
			min_compressed_size = header.header_len,
		}
		return
	} else if header.compressed_size > len(src) {
		err = BufferAccessError(
			SourceBufferTooSmall {
				compressed_size = header.compressed_size,
				source_buffer_size = len(src),
			},
		)
		return
	}

	if header.flags & 1 != 1 {
		if header.compressed_size - header.header_len != header.decompressed_size {
			err = InvalidUncompressedBuffer {
				expected_len = header.decompressed_size,
				actual_len   = header.compressed_size - header.header_len,
			}
			return
		}

		uncompressed_buf := src[src_cursor^:]
		intrinsics.mem_copy_non_overlapping(&dest[0], &uncompressed_buf[0], len(uncompressed_buf))
		src_cursor^ = len(src)
		bytes_written = len(uncompressed_buf)
		return
	}


	dest_cursor := &bytes_written
	next_hashed: int
	control: u32 = 1
	defer {
		_, err_too_small := err.(BufferAccessError)
		if (err_too_small || err == nil) && dest_cursor^ > header.decompressed_size {
			err = DecompressedSizeExceeded {
				cursor            = dest_cursor^,
				decompressed_size = header.decompressed_size,
			}
		}
	}
	for {
		if control == 1 {
			control = u32(cursor_read(u32le, src, src_cursor) or_return)
			if control == 0 {
				err = ZeroControlByteEncountered {
					at = src_cursor^ - size_of(u32le),
				}
				return
			}
		}
		if control & 1 == 1 {
			// Reference found
			control >>= 1
			next := u32(cursor_read(u8, src, src_cursor) or_return)

			switch header.level {
			case 1:
				matchlen := u8(next & 0xf)
				hash := int((next >> 4) | (u32(cursor_read(u8, src, src_cursor) or_return) << 4))
				if matchlen != 0 {
					matchlen += 2
				} else {
					matchlen = cursor_read(u8, src, src_cursor) or_return
				}
				if matchlen < 3 {
					err = ReferenceTooSmall {
						length     = int(matchlen),
						min_length = 3,
					}
					return
				}
				if hash >= len(hash_table) {
					err = InvalidHashTableEntry {
						hash     = hash,
						max_hash = len(hash_table) - 1,
					}
					return
				}
				offset := int(hash_table[hash])

				if _, overflow := intrinsics.overflow_add(u32(dest_cursor^), u32(matchlen));
				   overflow {
					err = ReferenceTooLarge {
						length     = int(matchlen),
						max_length = UINT32_MAX - dest_cursor^,
					}
					return
				}
				copy_slice_to_end(dest, dest_cursor, offset, int(matchlen)) or_return
				end := dest_cursor^ + 1 - int(matchlen)
				update_hash_table(hash_table, dest, next_hashed, end)
				next_hashed = dest_cursor^
			case 3:
				offset: int
				matchlen: int

				magnitude := next & 0b11
				read: int
				if magnitude == 0 {
					matchlen = 3
					offset = int(next >> 2)
				} else if magnitude == 1 {
					matchlen = 3
					offset = int(
						(next >> 2) | (u32(cursor_read(u8, src, src_cursor) or_return) << 6),
					)
					read = 1
				} else if magnitude == 2 {
					matchlen = 3 + int((next >> 2) & 0xf)
					offset = int(
						(next >> 6) | (u32(cursor_read(u8, src, src_cursor) or_return) << 2),
					)
					read = 1
				} else if next & 0x7f == 3 {
					src_cursor^ -= 1
					nexts := cursor_read(u32, src, src_cursor) or_return
					read = 3
					matchlen = 3 + int((nexts >> 7) & 0xff)
					offset = int(nexts >> 15)
				} else {
					src_cursor^ -= 1
					nexts := cursor_read_u24(src, src_cursor) or_return
					read = 2

					matchlen = int(2 + ((nexts >> 2) & 0x1f))
					offset = int(nexts >> 7)
				}

				if dest_cursor^ < offset {
					err = ReferenceOffsetTooLarge {
						offset     = offset,
						max_offset = dest_cursor^ - 1,
					}
					return
				}
				start := dest_cursor^ - offset

				if _, overflow := intrinsics.overflow_add(u32(dest_cursor^), u32(matchlen));
				   overflow {
					err = ReferenceTooLarge {
						length     = dest_cursor^,
						max_length = UINT32_MAX - dest_cursor^,
					}
					return
				}

				copy_slice_to_end(dest, dest_cursor, start, matchlen) or_return
			case:
				unreachable()
			}
		} else if dest_cursor^ >= max(header.decompressed_size, 10) - 10 {
			for dest_cursor^ < header.decompressed_size {
				if control == 1 {
					cursor_read(u32, src, src_cursor) or_return
				}
				control >>= 1
				cursor_copy(u8, dest, dest_cursor, src, src_cursor) or_return
				if dest_cursor^ > header.decompressed_size {
					err = DecompressedSizeExceeded {
						decompressed_size = header.decompressed_size,
						cursor            = dest_cursor^,
					}
				}
			}
			break
		} else {
			cursor_copy(u8, dest, dest_cursor, src, src_cursor) or_return
			if dest_cursor^ > header.decompressed_size {
				err = DecompressedSizeExceeded {
					decompressed_size = header.decompressed_size,
					cursor            = dest_cursor^,
				}
			}
			control >>= 1
			if header.level == 1 {
				end := intrinsics.saturating_sub(dest_cursor^, 2)
				update_hash_table(hash_table, dest, next_hashed, end)
				next_hashed = max(next_hashed, end)
			}
		}
	}

	if src_cursor^ < len(src) {
		err = NotAllOfSourceBufferWasUsed {
			used   = src_cursor^,
			length = len(src),
		}
	}
	if dest_cursor^ < len(dest) {
		err = NotAllOfDestBufferWasFilled {
			filled  = dest_cursor^,
			desired = len(dest),
		}
	}

	return
}


@(private = "file")
cursor_read :: #force_inline proc(
	$T: typeid,
	src: []u8,
	cursor: ^int,
) -> (
	result: T,
	err: DecompressionError,
) #no_bounds_check {
	if cursor^ + size_of(T) > len(src) {
		err = BufferAccessError(AccessViolation{at = cursor^ + size_of(T)})
		return
	}
	result = intrinsics.unaligned_load((^T)(&src[cursor^]))
	cursor^ += size_of(T)
	return
}


@(private = "file")
copy_slice_to_end :: proc "contextless" (
	buf: []u8,
	dest_idx: ^int,
	src_idx: int,
	src_size: int,
) -> DecompressionError #no_bounds_check {
	if src_idx >= dest_idx^ {
		return InvalidBackReference{offset = dest_idx^ - src_idx, length = src_size}
	}
	if (dest_idx^ + src_size >= len(buf)) {
		return BufferAccessError(
			DestinationBufferTooSmall{expected_len = dest_idx^ + src_size, actual_len = len(buf)},
		)
	}

	src_idx := src_idx
	src_size := src_size
	for src_size > 0 {
		copy_size := min(intrinsics.saturating_sub(dest_idx^, src_idx), src_size)
		intrinsics.mem_copy(&buf[dest_idx^], &buf[src_idx], copy_size)
		dest_idx^ += copy_size
		src_idx += copy_size
		src_size -= copy_size
	}

	assert_contextless(src_size == 0)
	return nil
}


@(private = "file")
update_hash_table :: #force_inline proc "contextless" (
	hash_table: ^HashTable,
	dest: []u8,
	start: int,
	end: int,
) -> DecompressionError #no_bounds_check {
	if (end + 2 >= len(dest)) {
		return BufferAccessError(AccessViolation{at = end + 2})
	}
	for i in start ..< end {
		hash_table[int(hash(read_u24(dest[i:])))] = u32(i)
	}
	return nil
}
