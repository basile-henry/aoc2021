const std = @import("std");
const print = std.debug.print;

const data = @embedFile("../inputs/day02.txt");

pub fn main() anyerror!void {
    // Part 1
    var position: usize = 0;
    var depth: usize = 0;

    // Part 2
    var position2: usize = 0;
    var depth2: usize = 0;
    var aim: usize = 0;

    var lines = std.mem.tokenize(data, "\n");
    while (lines.next()) |line| {
        var word = std.mem.tokenize(line, " ");
        const command = word.next().?;
        const amount = try std.fmt.parseInt(usize, word.rest(), 10);

        if (std.mem.eql(u8, command, "forward")) {
            position += amount;
            position2 += amount;
            depth2 += amount * aim;
        } else if (std.mem.eql(u8, command, "down")) {
            depth += amount;
            aim += amount;
        } else if (std.mem.eql(u8, command, "up")) {
            depth -= amount;
            aim -= amount;
        } else {
            std.debug.panic("Unexpected command: {s}", .{command});
        }
    }

    print("Part 1: {}\n", .{depth * position});
    print("Part 2: {}\n", .{depth2 * position2});
}
