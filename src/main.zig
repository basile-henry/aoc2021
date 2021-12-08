const std = @import("std");
const print = std.debug.print;

var alloc_buffer: [10 * 1024 * 1024]u8 = undefined;

pub fn main() anyerror!void {
    var fixed_alloc = std.heap.FixedBufferAllocator.init(alloc_buffer[0..]);
    const allocator = &fixed_alloc.allocator;

    print("Day 01:\n", .{});
    try @import("./day01.zig").main();

    print("\nDay 02:\n", .{});
    try @import("./day02.zig").main();

    print("\nDay 03:\n", .{});
    try @import("./day03.zig").main_with_allocator(allocator);

    print("\nDay 04:\n", .{});
    try @import("./day04.zig").main_with_allocator(allocator);

    print("\nDay 05:\n", .{});
    try @import("./day05.zig").main_with_allocator(allocator);

    print("\nDay 06:\n", .{});
    try @import("./day06.zig").main();

    print("\nDay 07:\n", .{});
    try @import("./day07.zig").main_with_allocator(allocator);

    print("\nDay 08:\n", .{});
    try @import("./day08.zig").main_with_allocator(allocator);
}
