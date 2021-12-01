const std = @import("std");
const print = std.debug.print;

const data = @embedFile("../inputs/day01.txt");

pub fn main() anyerror!void {
    var prev: ?usize = null;
    var increased: usize = 0;

    var prev_window: [3]?usize = [3]?usize{ null, null, null };
    var prev_window_index: usize = 0;
    var increased_window: usize = 0;

    var lines = std.mem.tokenize(data, "\n");
    while (lines.next()) |line| {
        const depth = try std.fmt.parseInt(usize, line, 10);

        if (prev) |p| {
            if (depth > p) {
                increased += 1;
            }
        }

        prev = depth;

        var prev_sum = sum_opt(prev_window[0..]);
        prev_window[@mod(prev_window_index, 3)] = depth;
        var cur_sum = sum_opt(prev_window[0..]);

        if (prev_window_index >= 3 and cur_sum.? > prev_sum.?) {
            increased_window += 1;
        }

        prev_window_index += 1;
    }

    print("Part 1: {}\n", .{increased});
    print("Part 2: {}\n", .{increased_window});
}

fn sum_opt(xs: []?usize) ?usize {
    var out: usize = 0;

    for (xs) |ox| {
        if (ox) |x| {
            out += x;
        } else {
            return null;
        }
    }

    return out;
}
