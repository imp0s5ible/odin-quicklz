package quicklz

import "core:slice"
import "core:testing"

@(thread_local)
STATIC_HASH_TABLE: QuickLZHashTable

//odinfmt: disable
@(test)
continuous10 :: proc(_: ^testing.T) {
    src := [?]u8 {
        0x47, 0x17,	0x00, 0x00,	0x00, 0x0a, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x01, 0x02,
        0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
    }

    orig: [10]u8
    for &orig, i in orig {
        orig = u8(i)
    }

    dest := make([]u8, len(orig))
    defer delete(dest)

	bytes_read, bytes_written, error := decompress(dest, src[:], STATIC_HASH_TABLE[:])
	testing.expect_value(nil, bytes_read, len(src))
    testing.expect_value(nil, bytes_written, len(orig))
    testing.expect_value(nil, error, nil)

    testing.expect(nil, slice.equal(dest[:len(orig)], orig[:]))
}
//odinfmt: enable

@(test)
continuous128 :: proc(_: ^testing.T) {
    //odinfmt: disable
    src := [?]u8 {
        0x47, 0x9d, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x80, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13,
        0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e,
        0x00, 0x00, 0x00, 0x80, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25,
        0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30,
        0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b,
        0x3c, 0x3d, 0x00, 0x00, 0x00, 0x80, 0x3e, 0x3f, 0x40, 0x41, 0x42,
        0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d,
        0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
        0x59, 0x5a, 0x5b, 0x5c, 0x00, 0x00, 0x00, 0x80, 0x5d, 0x5e, 0x5f,
        0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a,
        0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75,
        0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x00, 0x00, 0x00, 0x80, 0x7c,
        0x7d, 0x7e, 0x7f
    }
    //odinfmt: enable

	orig: [0x80]u8
	for &orig, i in orig {
		orig = u8(i)
	}

	dest := make([]u8, len(orig))
	defer delete(dest)

	bytes_read, bytes_written, error := decompress(dest, src[:], STATIC_HASH_TABLE[:])
	testing.expect_value(nil, bytes_read, len(src))
	testing.expect_value(nil, bytes_written, len(orig))
	testing.expect_value(nil, error, nil)

	testing.expect(nil, slice.equal(dest[:len(orig)], orig[:]))
}

continuous4x10 :: proc(_: ^testing.T) {
    //odinfmt: disable
    src := [?]u8 {
        0x47, 0x1e, 0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0x00,
        0x04, 0x00, 0x80, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
        0x07, 0x08, 0x09, 0x00, 0x12, 0x1a, 0x06, 0x07, 0x08, 0x09,
    }
    //odinfmt: enable

	orig: [40]u8
	for &orig, i in orig {
		orig = u8(i % 10)
	}

	dest := make([]u8, len(orig))
	defer delete(dest)

	bytes_read, bytes_written, error := decompress(dest, src[:], STATIC_HASH_TABLE[:])
	testing.expect_value(nil, bytes_read, len(src))
	testing.expect_value(nil, bytes_written, len(orig))
	testing.expect_value(nil, error, nil)

	testing.expect(nil, slice.equal(dest[:len(orig)], orig[:]))
}

@(test)
string_decompress_lvl1 :: proc(_: ^testing.T) {
    //odinfmt: disable
    src := [?]u8 {
        0x47, 0x4c, 0x2, 0, 0, 0xf9, 0x3, 0, 0, 0, 0, 0x4, 0x84, 0x69,
        0x6e, 0x69, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x20, 0x76,
        0x69, 0x72, 0x74, 0x75, 0x61, 0x6c, 0x54, 0x25, 0x5f, 0x6e, 0x61,
        0x6d, 0x65, 0x3d, 0x53, 0x23, 0x50, 0x5c, 0x73, 0x64, 0x65, 0,
        0x20, 0, 0x80, 0x72, 0x5c, 0x73, 0x56, 0x65, 0x72, 0x70, 0x6c,
        0x61, 0x6e, 0x74, 0x65, 0x6e, 0x7d, 0xb, 0x77, 0x65, 0x6c, 0x63,
        0x6f, 0x6d, 0x65, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x3d,
        0x54, 0x68, 0x50, 0x82, 0x1, 0xb0, 0x69, 0x73, 0x5c, 0x73, 0xe2,
        0x6a, 0x53, 0x61, 0xa6, 0x6d, 0x79, 0x61, 0xb4, 0x57, 0x6f, 0x72,
        0x6c, 0x64, 0x7d, 0xb, 0x61, 0xa6, 0x74, 0x66, 0x6f, 0x72, 0x6d,
        0x3d, 0x4c, 0x69, 0x6e, 0x75, 0x78, 0x7d, 0xb, 0x1, 0x25, 0x73, 0,
        0, 0, 0x80, 0x69, 0x6f, 0x6e, 0x3d, 0x33, 0x2e, 0x30, 0x2e, 0x31,
        0x33, 0x2e, 0x38, 0x5c, 0x73, 0x5b, 0x42, 0x75, 0x69, 0x6c, 0x64,
        0x3a, 0x5c, 0x73, 0x31, 0x35, 0x30, 0x30, 0x34, 0x35, 0x32, 0x38,
        0x8, 0, 0x2, 0x88, 0x31, 0x31, 0x5d, 0x7d, 0xb, 0x6d, 0x61, 0x78,
        0x63, 0x6c, 0x69, 0x65, 0x6e, 0x74, 0x73, 0x3d, 0x33, 0x32, 0x7d,
        0xb, 0x63, 0x72, 0x65, 0x61, 0x74, 0x65, 0x64, 0x3d, 0x30, 0x7e,
        0xb, 0x6f, 0x64, 0x65, 0, 0x92, 0x10, 0x9c, 0x63, 0x5f, 0x65, 0x6e,
        0x63, 0x72, 0x79, 0x70, 0x74, 0xf1, 0x98, 0x5f, 0x6d, 0x91, 0x23,
        0x3d, 0x31, 0x7d, 0xb, 0x68, 0x6f, 0x73, 0x74, 0xb6, 0x25, 0x4c,
        0xc3, 0xa9, 0x5c, 0x73, 0x58, 0x27, 0xb1, 0x66, 0x61, 0xa6, 0x6d,
        0x79, 0x7, 0x8, 0x18, 0xe0, 0x70, 0xb, 0x1a, 0x94, 0xba, 0x2e,
        0x75, 0x64, 0x65, 0x66, 0x61, 0x75, 0x6c, 0x74, 0x5f, 0x55, 0x25,
        0x67, 0x72, 0x6f, 0x75, 0x70, 0x3d, 0x38, 0x7d, 0xb, 0x26, 0x30,
        0x63, 0x68, 0x61, 0x6e, 0x6e, 0x65, 0x6c, 0x5f, 0, 0x49, 0x16,
        0xe2, 0x85, 0x82, 0x11, 0x81, 0x80, 0x62, 0x72, 0x88, 0x72, 0x5f,
        0x75, 0x72, 0x6c, 0x7d, 0xb, 0xe9, 0x85, 0x67, 0x66, 0x78, 0x80,
        0x27, 0x22, 0x69, 0x6e, 0x74, 0x21, 0x50, 0x61, 0x6c, 0x3d, 0x32,
        0x30, 0x30, 0x2e, 0x75, 0x70, 0x72, 0x69, 0x6f, 0x72, 0x69, 0x74,
        0, 0x40, 0, 0xb0, 0x79, 0x5f, 0x73, 0x70, 0x65, 0x61, 0x6b, 0x65,
        0x72, 0x5f, 0x64, 0x69, 0x6d, 0x6d, 0x92, 0xba, 0x69, 0x66, 0x69,
        0x63, 0x61, 0x74, 0x6f, 0x72, 0x3d, 0x2d, 0x31, 0x38, 0x2e, 0x31,
        0x33, 0x2e, 0x75, 0x69, 0x2, 0, 0x3f, 0x80, 0x64, 0xe0, 0x33, 0x15,
        0x62, 0x75, 0x74, 0x74, 0x6f, 0x6e, 0x5f, 0x74, 0x6f, 0x6f, 0x6c,
        0x74, 0x69, 0x70, 0x70, 0xb, 0x14, 0x24, 0x33, 0x20, 0x4b, 0x17,
        0x24, 0x33, 0x10, 0x1e, 0x16, 0x82, 0x7b, 0x5f, 0x70, 0x68, 0x6f,
        0x6e, 0x65, 0x74, 0x69, 0x63, 0x90, 0x1, 0x88, 0xc1, 0x3d, 0x6d,
        0x6f, 0x62, 0x7d, 0xb, 0x69, 0x63, 0x91, 0xb9, 0xf1, 0x7b, 0x32,
        0x35, 0x36, 0x38, 0x35, 0x35, 0x35, 0x32, 0x31, 0x33, 0x7e, 0xb,
        0x70, 0x3d, 0x30, 0xd1, 0x2c, 0x21, 0xd3, 0x2c, 0x5c, 0x73, 0x3a,
        0x3a, 0x7d, 0xb, 0x50, 0, 0x1f, 0x80, 0x61, 0x73, 0x6b, 0x5f, 0x1,
        0x84, 0x5f, 0x71, 0x4e, 0x76, 0x69, 0x6c, 0x65, 0x67, 0x65, 0x6b,
        0x65, 0x79, 0xef, 0x23, 0xe9, 0x85, 0xb3, 0x92, 0x2e, 0x75, 0x56,
        0xe7, 0x74, 0x65, 0x6d, 0x70, 0x5f, 0x64, 0x65, 0x6c, 0x65, 0x74,
        0x32, 0, 0x28, 0x80, 0x65, 0x92, 0x20, 0x61, 0x79, 0x91, 0x20, 0x3,
        0x63, 0x3d, 0x31, 0x30, 0x20, 0x61, 0x63, 0x6e, 0x3d, 0x49, 0x74,
        0x73, 0x4d, 0x65, 0x61, 0x71, 0x6c, 0xf1, 0x7b, 0x31, 0x20, 0x70,
        0x76, 0x3d, 0x36, 0x20, 0x6c, 0x74, 0x8, 0xc0, 0x40, 0x80, 0x3d,
        0x30, 0x20, 0x54, 0xaf, 0x5f, 0x74, 0x61, 0x6c, 0x6b, 0x5f, 0x70,
        0x6f, 0x77, 0x65, 0x12, 0xfa, 0x66, 0x5e, 0x6e, 0x65, 0x65, 0x64,
        0x65, 0x64, 0x85, 0x50, 0x71, 0x75, 0x65, 0x72, 0x79, 0x5f, 0x76,
        0x69, 0, 0, 0, 0x80, 0x65, 0x77, 0x5f, 0x70, 0x6f, 0x77, 0x65,
        0x72, 0x3d, 0x37, 0x35,
    }
    //odinfmt: enable

	orig := "initserver virtualserver_name=Server\\sder\\sVerplanten virtualserver_welcomemessage=This\\sis\\sSplamys\\sWorld virtualserver_platform=Linux virtualserver_version=3.0.13.8\\s[Build:\\s1500452811] virtualserver_maxclients=32 virtualserver_created=0 virtualserver_codec_encryption_mode=1 virtualserver_hostmessage=L\xc3\xa9\\sServer\\sde\\sSplamy virtualserver_hostmessage_mode=0 virtualserver_default_server_group=8 virtualserver_default_channel_group=8 virtualserver_hostbanner_url virtualserver_hostbanner_gfx_url virtualserver_hostbanner_gfx_interval=2000 virtualserver_priority_speaker_dimm_modificator=-18.0000 virtualserver_id=1 virtualserver_hostbutton_tooltip virtualserver_hostbutton_url virtualserver_hostbutton_gfx_url virtualserver_name_phonetic=mob virtualserver_icon_id=2568555213 virtualserver_ip=0.0.0.0,\\s:: virtualserver_ask_for_privilegekey=0 virtualserver_hostbanner_mode=0 virtualserver_channel_temp_delete_delay_default=10 acn=ItsMe aclid=1 pv=6 lt=0 client_talk_power=-1 client_needed_serverquery_view_power=75"
	//          "initserver virtualserver_name=Server\\sder\\sVerplanten virtualserver_welcomemessage=This\\sis\\sSplamys\\sWorld virtualserver_platform=Linux virtualserver_version=3.0.13.8\\s[Build:\\s1500452811] virtualserver_maxclients=32 virtualserver_created=0 virtualserver_codec_encryption_mode=1 virtualserver_hostmessage=L├   ⌐   \\sServer\\sde\\sSplamy virtualserver_hostmessage_mode=0 virtualserver_default_server_group=8 virtualserver_default_channel_group=8 virtualserver_hostbanner_url virtualserver_hostbanner_gfx_url virtualserver_hostbanner_gfx_interval=2000 virtualserver_priority_speaker_dimm_modificator=-18.0000 virtualserver_id=1 virtualserver_hostbutton_tooltip virtualserver_hostbutton_url virtualserver_hostbutton_gfx_interval=2000 virtname_phonetic=mob virtname_phoneicon_id=2568555213 virtname_phoneip=0.0.0.0,\\s:: virtname_phoneask_for_privilegekey=0 virtualserver_hostbutton_modif0 virtualserver_channel_temp_delete_delay_default=10 acn=ItsMe aclid=1 pv=6 lt=0 clid=1_talk_power=-1 clid=1_needed_serverquery_view_power=75"
	dest := make([]u8, len(orig))
	defer delete(dest)

	bytes_read, bytes_written, error := decompress(dest, src[:], STATIC_HASH_TABLE[:])
	testing.expect_value(nil, bytes_read, len(src))
	testing.expect_value(nil, bytes_written, len(orig))
	testing.expect_value(nil, error, nil)

	testing.expect_value(nil, string(dest), orig)
}

@(test)
corrupt_string :: proc(_: ^testing.T) {
    //odinfmt: disable
    src := [?]u8 {
        0x47, 0x56, 0x02, 0x00, 0x00, 0xf9, 0x03, 0x00, 0x00, 0x00, 0x00,
        0x04, 0x84, 0x69, 0x6e, 0x69, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65,
        0x72, 0x20, 0x76, 0x69, 0x72, 0x74, 0x75, 0x61, 0x6c, 0x54, 0x25,
        0x5f, 0x6e, 0x61, 0x6d, 0x65, 0x3d, 0x53, 0x23, 0x50, 0x5c, 0x73,
        0x64, 0x65, 0x00, 0x20, 0x00, 0x80, 0x72, 0x5c, 0x73, 0x56, 0x65,
        0x72, 0x70, 0x6c, 0x61, 0x6e, 0x74, 0x65, 0x6e, 0x7d, 0x0b, 0x77,
        0x65, 0x6c, 0x63, 0x6f, 0x6d, 0x65, 0x6d, 0x65, 0x73, 0x73, 0x61,
        0x67, 0x65, 0x3d, 0x54, 0x68, 0x50, 0x82, 0x01, 0xb0, 0x69, 0x73,
        0x5c, 0x73, 0xe2, 0x6a, 0x53, 0x61, 0xa6, 0x6d, 0x79, 0x61, 0xb4,
        0x57, 0x6f, 0x72, 0x6c, 0x64, 0x7d, 0x0b, 0x61, 0xa6, 0x74, 0x66,
        0x6f, 0x72, 0x6d, 0x3d, 0x4c, 0x69, 0x6e, 0x75, 0x78, 0x7d, 0x0b,
        0x01, 0x25, 0x73, 0x00, 0x00, 0x00, 0x80, 0x69, 0x6f, 0x6e, 0x3d,
        0x33, 0x2e, 0x30, 0x2e, 0x31, 0x33, 0x2e, 0x38, 0x5c, 0x73, 0x5b,
        0x42, 0x75, 0x69, 0x6c, 0x64, 0x3a, 0x5c, 0x73, 0x31, 0x35, 0x30,
        0x30, 0x34, 0x35, 0x32, 0x38, 0x08, 0x00, 0x02, 0x88, 0x31, 0x31,
        0x5d, 0x7d, 0x0b, 0x6d, 0x61, 0x78, 0x63, 0x6c, 0x69, 0x65, 0x6e,
        0x74, 0x73, 0x3d, 0x33, 0x32, 0x7d, 0x0b, 0x63, 0x72, 0x65, 0x61,
        0x74, 0x65, 0x64, 0x3d, 0x30, 0x7d, 0x0b, 0x6e, 0x6f, 0x64, 0x00,
        0x24, 0x21, 0xb8, 0x65, 0x63, 0x5f, 0x65, 0x6e, 0x63, 0x72, 0x79,
        0x70, 0x74, 0xf1, 0x98, 0x5f, 0x6d, 0x91, 0x23, 0x3d, 0x31, 0x7d,
        0x0b, 0x68, 0x6f, 0x73, 0x74, 0xb6, 0x25, 0x4c, 0xc3, 0xa9, 0x5c,
        0x73, 0x58, 0x27, 0xb1, 0x66, 0x61, 0xa6, 0x6d, 0x1e, 0x20, 0xc0,
        0x80, 0x79, 0x7d, 0x0b, 0x89, 0x7b, 0x94, 0xba, 0x2e, 0x75, 0x64,
        0x65, 0x66, 0x61, 0x75, 0x6c, 0x74, 0x5f, 0x54, 0x25, 0x20, 0x67,
        0x72, 0x6f, 0x75, 0x70, 0x3d, 0x38, 0x7d, 0x0b, 0x26, 0x30, 0x63,
        0x68, 0x61, 0x6e, 0x6e, 0x65, 0x6c, 0x16, 0x1c, 0x11, 0x88, 0x5f,
        0x00, 0x49, 0x16, 0xe2, 0x85, 0x62, 0x72, 0x88, 0x72, 0x5f, 0x75,
        0x72, 0x6c, 0x7d, 0x0b, 0xe2, 0x85, 0xb5, 0x25, 0x67, 0x66, 0x78,
        0x80, 0x27, 0x22, 0x69, 0x6e, 0x74, 0x21, 0x50, 0x61, 0x6c, 0x3d,
        0x32, 0x30, 0x30, 0x2e, 0x75, 0x70, 0x72, 0x69, 0x00, 0x00, 0x04,
        0x80, 0x6f, 0x72, 0x69, 0x74, 0x79, 0x5f, 0x73, 0x70, 0x65, 0x61,
        0x6b, 0x65, 0x72, 0x5f, 0x64, 0x69, 0x6d, 0x6d, 0x92, 0xba, 0x69,
        0x66, 0x69, 0x63, 0x61, 0x74, 0x6f, 0x72, 0x3d, 0x2d, 0x31, 0x38,
        0x26, 0x00, 0xf0, 0x87, 0x2e, 0x31, 0x33, 0x2e, 0x75, 0x69, 0x64,
        0xe0, 0x33, 0x15, 0x62, 0x75, 0x74, 0x74, 0x6f, 0x6e, 0x5f, 0x74,
        0x6f, 0x6f, 0x6c, 0x74, 0x69, 0x70, 0x7d, 0x0b, 0x83, 0x7b, 0x24,
        0x33, 0x20, 0x4b, 0x17, 0x24, 0x33, 0x10, 0x1e, 0x16, 0x82, 0x7b,
        0x5f, 0x70, 0x68, 0x6f, 0x00, 0x32, 0x00, 0xe1, 0x6e, 0x65, 0x74,
        0x69, 0x63, 0x3d, 0x6d, 0x6f, 0x62, 0x7d, 0x0b, 0x69, 0x63, 0x91,
        0xb9, 0xf1, 0x7b, 0x32, 0x35, 0x36, 0x38, 0x35, 0x35, 0x35, 0x32,
        0x31, 0x33, 0x7d, 0x0b, 0x6e, 0x70, 0x3d, 0x30, 0xd1, 0x2c, 0x21,
        0xd3, 0x20, 0x14, 0xc0, 0x87, 0x2c, 0x5c, 0x73, 0x3a, 0x3a, 0x7d,
        0x0b, 0x61, 0x73, 0x6b, 0x5f, 0x01, 0x84, 0x5f, 0x71, 0x4e, 0x76,
        0x69, 0x6c, 0x65, 0x67, 0x65, 0x6b, 0x65, 0x79, 0xef, 0x23, 0xe9,
        0x85, 0xb3, 0x92, 0x2e, 0x75, 0x56, 0xe7, 0x74, 0x65, 0x6d, 0x70,
        0x80, 0x0c, 0x00, 0x8a, 0x5f, 0x64, 0x65, 0x6c, 0x65, 0x74, 0x65,
        0x92, 0x20, 0x61, 0x79, 0x91, 0x20, 0x03, 0x63, 0x3d, 0x31, 0x30,
        0x20, 0x61, 0x63, 0x6e, 0x3d, 0x49, 0x74, 0x73, 0x4d, 0x65, 0x61,
        0x71, 0x6c, 0xf1, 0x7b, 0x31, 0x20, 0x70, 0x00, 0x02, 0x80, 0x81,
        0x76, 0x3d, 0x36, 0x20, 0x6c, 0x74, 0x3d, 0x30, 0x20, 0x51, 0xaf,
        0x64, 0x3d, 0x31, 0x5f, 0x74, 0x61, 0x6c, 0x6b, 0x5f, 0x70, 0x6f,
        0x77, 0x65, 0x12, 0xfa, 0x66, 0x5e, 0x6e, 0x65, 0x65, 0x64, 0x65,
        0x64, 0x01, 0x00, 0x00, 0x80, 0x85, 0x50, 0x71, 0x75, 0x65, 0x72,
        0x79, 0x5f, 0x76, 0x69, 0x65, 0x77, 0x5f, 0x70, 0x6f, 0x77, 0x65,
        0x72, 0x3d, 0x37, 0x35,
    }
    //odinfmt: enable

	orig := "initserver virtualserver_name=Server\\sder\\sVerplanten virtualserver_welcomemessage=This\\sis\\sSplamys\\sWorld virtualserver_platform=Linux virtualserver_version=3.0.13.8\\s[Build:\\s1500452811] virtualserver_maxclients=32 virtualserver_created=0 virtualserver_nodec_encryption_mode=1 virtualserver_hostmessage=L\xc3\xa9\\sServer\\sde\\sSplamy virtualserver_name=Server_mode=0 virtualserver_default_server group=8 virtualserver_default_channel_group=8 virtualserver_hostbanner_url virtualserver_hostmessagegfx_url virtualserver_hostmessagegfx_interval=2000 virtualserver_priority_speaker_dimm_modificator=-18.0000 virtualserver_id=1 virtualserver_hostbutton_tooltip virtualserver_name=utton_url virtualserver_hostmutton_gfx_url virtualserver_name_phonetic=mob virtualserver_icon_id=2568555213 virtualserver_np=0.0.0.0,\\s:: virtualserver_ask_for_privilegekey=0 virtualserver_hostmessagemode=0 virtualserver_channel_temp_delete_delay_default=10 acn=ItsMe aclid=1 pv=6 lt=0 clid=1_talk_power=-1 clid=1_needed_serverquery_view_power=75"

	dest := make([]u8, len(orig))
	defer delete(dest)

	bytes_read, bytes_written, error := decompress(dest, src[:], STATIC_HASH_TABLE[:])
	testing.expect_value(nil, bytes_read, len(src))
	testing.expect_value(nil, bytes_written, len(orig))
	testing.expect_value(nil, error, nil)

	testing.expect(nil, slice.equal(dest[:], transmute([]u8)orig))
}

@(test)
corrupt_enterview :: proc(_: ^testing.T) {
    //odinfmt: disable
    src := [?]u8 {
        0x47, 0xf2, 0x1, 0, 0, 0xfe, 0x2, 0, 0, 0, 0x10, 0, 0x90, 0x6e,
        0x6f, 0x74, 0x69, 0x66, 0x79, 0x63, 0x6c, 0x69, 0x65, 0x6e, 0x74,
        0x32, 0x92, 0x72, 0x76, 0x69, 0x65, 0x77, 0x20, 0x63, 0x66, 0x69,
        0x64, 0x3d, 0x30, 0x20, 0x63, 0x74, 0xf1, 0x7b, 0x31, 0x20, 0x40,
        0x62, 0, 0x82, 0x72, 0x65, 0x61, 0x73, 0x6f, 0x6e, 0xf1, 0x7b,
        0x32, 0x20, 0x51, 0xaf, 0x64, 0x3d, 0x31, 0x62, 0x5e, 0x31, 0x92,
        0x5f, 0x75, 0x6e, 0x69, 0x71, 0x75, 0x65, 0x5f, 0x69, 0x64, 0x31,
        0x92, 0x69, 0x66, 0x69, 0x65, 0x72, 0, 0, 0, 0xa0, 0x3d, 0x6c,
        0x6b, 0x73, 0x37, 0x51, 0x4c, 0x35, 0x4f, 0x56, 0x4d, 0x4b, 0x6f,
        0x34, 0x70, 0x5a, 0x37, 0x39, 0x63, 0x45, 0x4f, 0x49, 0x35, 0x72,
        0x35, 0x6f, 0x45, 0x41, 0x3d, 0x66, 0x5e, 0x6e, 0, 0x8, 0xc0, 0x90,
        0x69, 0x63, 0x6b, 0x6e, 0x61, 0x6d, 0x65, 0x3d, 0x42, 0x6f, 0x74,
        0x66, 0x5e, 0x69, 0x6e, 0x70, 0x75, 0x74, 0x5f, 0x6d, 0x75, 0x74,
        0x65, 0x73, 0xe6, 0xa3, 0xf3, 0x5f, 0x6f, 0x75, 0x74, 0x70, 0x23,
        0x19, 0x6f, 0x6e, 0xc, 0x70, 0, 0x81, 0x6c, 0x79, 0x9e, 0xa0, 0xf4,
        0x96, 0x68, 0x61, 0x72, 0x64, 0x77, 0x61, 0x72, 0x65, 0xe2, 0x23,
        0xab, 0xf3, 0xe0, 0x64, 0x12, 0x6d, 0x65, 0x74, 0x61, 0x5f, 0x64,
        0x61, 0x74, 0x61, 0x67, 0x5e, 0x73, 0x5f, 0x72, 0x65, 0x63, 0x6f,
        0x60, 0x84, 0, 0xa0, 0x72, 0x64, 0x69, 0x6e, 0x67, 0xe8, 0x23,
        0x22, 0x62, 0x62, 0x61, 0x73, 0x2, 0x9f, 0x3d, 0x32, 0x33, 0x39,
        0x66, 0x5e, 0x63, 0x68, 0x61, 0x6e, 0x6e, 0x65, 0x6c, 0x5f, 0x67,
        0x72, 0x6f, 0x75, 0x70, 0x91, 0xf1, 0x3d, 0x2, 0x11, 0x6, 0x88,
        0x38, 0x66, 0x5e, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x3, 0x49,
        0x73, 0x3d, 0x37, 0x66, 0x5e, 0x61, 0x77, 0x61, 0x79, 0xe8, 0x23,
        0x62, 0x17, 0x5f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x66,
        0x5e, 0x74, 0x79, 0x70, 0x1, 0x5, 0xb4, 0xe4, 0x69, 0xe6, 0x66,
        0x6c, 0x61, 0x67, 0x5f, 0x61, 0x76, 0x61, 0x27, 0x72, 0x67, 0x5e,
        0x61, 0x6c, 0x6b, 0x5f, 0x70, 0x6f, 0x77, 0x21, 0x1b, 0x35, 0x21,
        0x60, 0xa4, 0xf3, 0x74, 0x72, 0xad, 0x72, 0x65, 0x61, 0x32, 0x73,
        0x74, 0xe8, 0x23, 0x2a, 0x7b, 0x10, 0, 0xf1, 0x80, 0x5f, 0x6d,
        0x73, 0x67, 0x66, 0x5e, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70,
        0x74, 0x69, 0x6f, 0x6e, 0x66, 0x5e, 0x69, 0x73, 0x5f, 0x22, 0x7b,
        0x21, 0x1b, 0x27, 0x60, 0xe1, 0x69, 0x70, 0x72, 0x69, 0x6f, 0x72,
        0x69, 0x74, 0x80, 0xd4, 0, 0x82, 0x79, 0x5f, 0x73, 0x70, 0x65,
        0x61, 0x6b, 0x2a, 0x1b, 0x75, 0x6e, 0x41, 0x36, 0x64, 0x96, 0xb0,
        0x73, 0xe8, 0x23, 0x86, 0xf5, 0x5f, 0x70, 0x68, 0x6f, 0x6e, 0x65,
        0x74, 0x69, 0x63, 0x66, 0x5e, 0x6e, 0x65, 0x65, 0x64, 0x65, 0xc,
        0x13, 0xe, 0x88, 0x64, 0x5f, 0x54, 0x25, 0x61, 0x32, 0x72, 0x79,
        0x5f, 0x76, 0xf1, 0x21, 0x85, 0x6a, 0x37, 0x35, 0x66, 0x5e, 0x69,
        0x63, 0x6f, 0x6e, 0x92, 0xf1, 0x2a, 0x60, 0x56, 0xe7, 0x63, 0x6f,
        0x6d, 0x6d, 0x61, 0x6e, 0x64, 0x2a, 0x1b, 0x63, 0x6f, 0x75, 0x70,
        0xf0, 0, 0x80, 0x6e, 0x74, 0x72, 0x79, 0x66, 0x5e, 0x56, 0xe7, 0x3,
        0x49, 0x5f, 0x69, 0x6e, 0x68, 0x65, 0x41, 0xe3, 0x31, 0x19, 0x56,
        0xe7, 0xf1, 0x7b, 0x31, 0x20, 0x63, 0x6c, 0x69, 0x65, 0x6e, 0x74,
        0x5f, 0x62, 0x61, 0x64, 0x67, 0x65, 0x73,
    }
    //odinfmt: enable

	orig := "notifycliententerview cfid=0 ctid=1 reasonid=2 clid=1 client_unique_identifier=lks7QL5OVMKo4pZ79cEOI5r5oEA= client_nickname=Bot client_input_muted=0 client_output_muted=0 client_outputonly_muted=0 client_input_hardware=0 client_output_hardware=0 client_meta_data client_is_recording=0 client_database_id=239 client_channel_group_id=8 client_servergroups=7 client_away=0 client_away_message client_type=0 client_flag_avatar client_talk_power=50 client_talk_request=0 client_talk_request_msg client_description client_is_talker=0 client_is_priority_speaker=0 client_unread_messages=0 client_nickname_phonetic client_needed_serverquery_view_power=75 client_icon_id=0 client_is_channel_commander=0 client_country client_channel_group_inherited_channel_id=1 client_badges"

	dest := make([]u8, len(orig))
	defer delete(dest)

	bytes_read, bytes_written, error := decompress(dest, src[:], STATIC_HASH_TABLE[:])
	testing.expect_value(nil, bytes_read, len(src))
	testing.expect_value(nil, bytes_written, len(orig))
	testing.expect_value(nil, error, nil)

	testing.expect(nil, slice.equal(dest[:], transmute([]u8)orig))
}
