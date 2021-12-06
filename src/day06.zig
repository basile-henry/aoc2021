const std = @import("std");
const print = std.debug.print;

const data = @embedFile("../inputs/day06.txt");

pub fn main() anyerror!void {
    var lanternfish: [9]u64 = undefined;
    var temp: [9]u64 = undefined;

    std.mem.set(u64, lanternfish[0..], 0);

    {
        var it = std.mem.split(std.mem.trimRight(u8, data[0..], "\n"), ",");
        while (it.next()) |n| {
            const x = try std.fmt.parseInt(u8, n, 10);
            lanternfish[x] += 1;
        }
    }

    var day: usize = 0;
    while (day < 256) : (day += 1) {
        std.mem.set(u64, temp[0..], 0);

        for (lanternfish) |x, i| {
            if (i == 0) {
                temp[6] = x;
                temp[8] = x;
            } else {
                temp[i - 1] += x;
            }
        }

        std.mem.swap([9]u64, &lanternfish, &temp);

        if (day == 79) {
            print("Part 1: {d}\n", .{sum(u64, lanternfish)});
        }
    }

    print("Part 2: {d}\n", .{sum(u64, lanternfish)});
}

fn sum(comptime T: type, a: anytype) T {
    var out: T = 0;

    for (a) |x| {
        out += x;
    }

    return out;
}
