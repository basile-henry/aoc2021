const std = @import("std");
const print = std.debug.print;

pub fn main() anyerror!void {
    print("Day 01:\n", .{});
    try @import("./day01.zig").main();

    print("\nDay 02:\n", .{});
    try @import("./day02.zig").main();

    print("\nDay 03:\n", .{});
    try @import("./day03.zig").main();

    print("\nDay 04:\n", .{});
    try @import("./day04.zig").main();

    print("\nDay 05:\n", .{});
    try @import("./day05.zig").main();

    print("\nDay 06:\n", .{});
    try @import("./day06.zig").main();
}