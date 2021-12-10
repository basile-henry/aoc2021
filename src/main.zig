const std = @import("std");
const print = std.debug.print;

var alloc_buffer: [10 * 1024 * 1024]u8 = undefined;

pub fn main() anyerror!void {
    var fixed_alloc = std.heap.FixedBufferAllocator.init(alloc_buffer[0..]);
    const allocator = &fixed_alloc.allocator;

    const last_day = 10;

    comptime var day: u8 = 1;
    inline while (day <= last_day) : (day += 1) {
        comptime const day_str = [2]u8{
            (day / 10) + '0',
            (day % 10) + '0',
        };

        print("\nDay " ++ day_str ++ "\n", .{});
        try @import("./day" ++ day_str ++ ".zig").main();
    }
}
