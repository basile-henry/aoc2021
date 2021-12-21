const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day07.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    var positions = std.ArrayList(isize).init(allocator);
    defer positions.deinit();

    {
        var it = std.mem.split(u8, std.mem.trimRight(u8, data[0..], "\n"), ",");
        while (it.next()) |n| {
            const x = try std.fmt.parseInt(isize, n, 10);
            try positions.append(x);
        }
    }

    print("Part 1: {d}\n", .{try solve(positions.items, cost1)});
    print("Part 2: {d}\n", .{try solve(positions.items, cost2)});
}

fn solve(positions: []const isize, cost: fn ([]const isize, isize) anyerror!isize) anyerror!isize {
    var offset = averageInt(positions);
    const cur_cost = try cost(positions, offset);
    const next_cost = try cost(positions, offset + 1);

    var dir: isize = undefined;
    var best_cost: isize = undefined;

    if (next_cost < cur_cost) {
        dir = 1;
        best_cost = next_cost;
        offset = offset + 1;
    } else {
        dir = -1;
        best_cost = cur_cost;
    }

    var step_size: isize = 32;
    while (step_size > 1) {
        while (true) {
            const off = offset + step_size * dir;
            const new_cost = try cost(positions, off);

            if (new_cost >= best_cost) {
                break;
            }

            best_cost = new_cost;
            offset = off;
        }

        step_size >>= 1;
    }

    return best_cost;
}

fn cost1(positions: []const isize, offset: isize) anyerror!isize {
    var out: isize = 0;

    for (positions) |p| {
        out += try std.math.absInt(p - offset);
    }

    return out;
}

fn cost2(positions: []const isize, offset: isize) anyerror!isize {
    var out: isize = 0;

    for (positions) |p| {
        out += triangle(try std.math.absInt(p - offset));
    }

    return out;
}

fn triangle(x: isize) isize {
    return @divTrunc((1 + x) * x, 2);
}

fn sum(xs: []const isize) isize {
    var out: isize = 0;

    for (xs) |x| {
        out += x;
    }

    return out;
}

fn averageInt(xs: []const isize) isize {
    const s: isize = sum(xs[0..]);

    return @divTrunc(s, @intCast(isize, xs.len));
}

test "crabs" {
    const positions = [_]isize{ 16, 1, 2, 0, 4, 2, 7, 1, 2, 14 };

    const part1 = try solve(positions[0..], cost1);
    try std.testing.expectEqual(@as(isize, 37), part1);

    const part2 = try solve(positions[0..], cost2);
    try std.testing.expectEqual(@as(isize, 168), part2);
}
