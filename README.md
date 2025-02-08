# Odin QuickLZ

Implementation of the latest (1.5.0) version the QuickLZ compression algorithm in Odin, mostly concerned with safety and useful, granular errors, intended for use in legacy applications for compressed data that may have been corrupted. As such, care is taken to make sure the process does not crash when dealing with corrupted input, while still being reasonably fast.

Supports both compression and decompression at levels 1 and 3.

Based on the Rust implementation [ReSpeak/quicklz](https://github.com/ReSpeak/quicklz) by Sebastian Neubauer
