const std = @import("std");
const print = std.debug.print;

var alloc_buffer: [10 * 1024 * 1024]u8 = undefined;

pub fn main() anyerror!void {
    var fixed_alloc = std.heap.FixedBufferAllocator.init(alloc_buffer[0..]);
    const allocator = &fixed_alloc.allocator;

    var timer = try std.time.Timer.start();
    var times = std.ArrayList(u64).init(allocator);

    const last_day = 12;

    comptime var day: u8 = 1;
    inline while (day <= last_day) : (day += 1) {
        comptime const day_str = [2]u8{
            (day / 10) + '0',
            (day % 10) + '0',
        };

        print("\nDay " ++ day_str ++ "\n", .{});
        try @import("./day" ++ day_str ++ ".zig").main();

        try times.append(timer.lap());
    }

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
