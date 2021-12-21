const std = @import("std");
const print = std.debug.print;

const data = @embedFile("../inputs/day01.txt");

pub fn main() anyerror!void {
    // Part 1
    var prev: ?usize = null;
    var increased: usize = 0;

    // Part 2
    var prev_window: [3]usize = undefined;
    var prev_window_index: usize = 0;
    var increased_window: usize = 0;

    var lines = std.mem.tokenize(u8, data, "\n");
    while (lines.next()) |line| {
        const depth = try std.fmt.parseInt(usize, line, 10);

        // Part 1
        if (prev) |p| {
            if (depth > p) {
                increased += 1;
            }
        }

        prev = depth;

        // Part 2
        if (prev_window_index >= 3) {
            var prev_sum = sum(prev_window[0..]);
            prev_window[@mod(prev_window_index, 3)] = depth;
            var cur_sum = sum(prev_window[0..]);

            if (cur_sum > prev_sum) {
                increased_window += 1;
            }
        } else {
            prev_window[@mod(prev_window_index, 3)] = depth;
        }

        prev_window_index += 1;
    }

    print("Part 1: {}\n", .{increased});
    print("Part 2: {}\n", .{increased_window});
}

fn sum(xs: []usize) usize {
    var out: usize = 0;

    for (xs) |x| {
        out += x;
    }

    return out;
}
