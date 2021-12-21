const std = @import("std");
const print = std.debug.print;

var alloc_buffer: [6 * 1024 * 1024]u8 = undefined;

pub fn main() anyerror!void {
    var fixed_alloc = std.heap.FixedBufferAllocator.init(alloc_buffer[0..]);
    const allocator = fixed_alloc.allocator();

    var timer = try std.time.Timer.start();
    var times = std.ArrayList(u64).init(allocator);

    print("\nDay 01\n", .{});
    try @import("./day01.zig").main();
    try times.append(timer.lap());

    print("\nDay 02\n", .{});
    try @import("./day02.zig").main();
    try times.append(timer.lap());

    print("\nDay 03\n", .{});
    try @import("./day03.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 04\n", .{});
    try @import("./day04.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 05\n", .{});
    try @import("./day05.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 06\n", .{});
    try @import("./day06.zig").main();
    try times.append(timer.lap());

    print("\nDay 07\n", .{});
    try @import("./day07.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 08\n", .{});
    try @import("./day08.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 09\n", .{});
    try @import("./day09.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 10\n", .{});
    try @import("./day10.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 11\n", .{});
    try @import("./day11.zig").main();
    try times.append(timer.lap());

    print("\nDay 12\n", .{});
    try @import("./day12.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 13\n", .{});
    try @import("./day13.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 14\n", .{});
    try @import("./day14.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 15\n", .{});
    try @import("./day15.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 16\n", .{});
    try @import("./day16.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 17\n", .{});
    try @import("./day17.zig").main();
    try times.append(timer.lap());

    print("\nDay 18\n", .{});
    try @import("./day18.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    // print("\nDay 19\n", .{});
    // try @import("./day19.zig").main_with_allocator(allocator);
    // try times.append(timer.lap());

    print("\nDay 20\n", .{});
    try @import("./day20.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nDay 21\n", .{});
    try @import("./day21.zig").main_with_allocator(allocator);
    try times.append(timer.lap());

    print("\nTimes:\n", .{});
    var total_time: u64 = 0;
    for (times.items) |time, i| {
        total_time += time;
        const t: f64 = @intToFloat(f64, time) / 1_000_000; // nano to milli
        print("  day {d:0>2}: {d: >6.3}ms\n", .{ i + 1, t });
    }

    const total: f64 = @intToFloat(f64, total_time) / 1_000_000; // nano to milli
    print("  total:  {d: >6.3}ms\n", .{total});
}
