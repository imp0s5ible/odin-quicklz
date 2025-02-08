package quicklz

import "base:intrinsics"
import "base:runtime"

@(private = "package")
UINT32_MAX :: 4294967295

@(private = "package")
HASH_TABLE_SIZE :: 4096

@(private = "package")
HashTable :: distinct [HASH_TABLE_SIZE]u32

FailedToAllocateScratchSpace :: struct {
	error: runtime.Allocator_Error,
}

@(private = "package")
cursor_copy :: #force_inline proc "contextless" (
	$T: typeid,
	dest: []u8,
	dest_cursor: ^int,
	src: []u8,
	src_cursor: ^int,
) -> BufferAccessError #no_bounds_check {
	if dest_cursor^ + size_of(T) > len(dest) {
		return DestinationBufferTooSmall {
			expected_len = dest_cursor^ + size_of(T),
			actual_len = len(dest),
		}
	}
	if src_cursor^ + size_of(T) > len(src) {
		return AccessViolation{at = src_cursor^ + size_of(T)}
	}

	intrinsics.mem_copy(&dest[dest_cursor^], &src[src_cursor^], size_of(T))
	dest_cursor^ += size_of(T)
	src_cursor^ += size_of(T)

	return nil
}


@(private = "package")
cursor_read_u24 :: #force_inline proc "contextless" (
	buf: []u8,
	cursor: ^int,
) -> (
	result: u32,
	err: DecompressionError,
) #no_bounds_check {
	if cursor^ + 3 > len(buf) {
		err = BufferAccessError(AccessViolation{at = cursor^ + 3})
	} else {
		result = read_u24(buf[cursor^:])
		cursor^ += 3
	}
	return
}


@(private = "package")
read_u24 :: #force_inline proc "contextless" (buf: []u8) -> u32 #no_bounds_check {
	return u32(u32le(buf[0]) | (u32le(buf[1]) << 8) | (u32le(buf[2]) << 16))
}


@(private = "package")
hash :: #force_inline proc "contextless" (val: u32) -> u32 {
	return ((val >> 12) ~ val) & 0xfff
}
