const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day12.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    var map = try parse(allocator, data[0..]);
    defer deinit_map(&map);

    print("Part 1: {d}\n", .{try part1(allocator, map)});
    print("Part 2: {d}\n", .{try part2(allocator, map)});
}

const Map = std.StringHashMap(std.ArrayList([]const u8));

fn deinit_map(map: *Map) void {
    var it = map.valueIterator();
    while (it.next()) |v| {
        v.deinit();
    }

    map.deinit();
}

fn parse(allocator: Allocator, input: []const u8) !Map {
    var lines = std.mem.tokenize(u8, input, "\n");
    var out = Map.init(allocator);

    while (lines.next()) |line| {
        var points = std.mem.tokenize(u8, line, "-");
        const a = points.next().?;
        const b = points.next().?;

        try put_append(&out, a, b);
        try put_append(&out, b, a);
    }

    return out;
}

fn put_append(map: *Map, key: []const u8, val: []const u8) !void {
    if (map.getPtr(key)) |ptr| {
        try ptr.append(val);
    } else {
        var entries = std.ArrayList([]const u8).init(map.allocator);
        try entries.append(val);
        try map.put(key, entries);
    }
}

const Frame = struct {
    current: []const u8,
    next_idx: usize,
    max_small_cave: usize,
};

fn count_paths(allocator: Allocator, map: Map, max_small_cave: usize) !usize {
    var frames = std.ArrayList(Frame).init(allocator);
    defer frames.deinit();

    try frames.append(Frame{
        .current = "end",
        .next_idx = 0,
        .max_small_cave = max_small_cave,
    });

    var paths: usize = 0;

    while (frames.items.len > 0) {
        var frame = &frames.items[frames.items.len - 1];

        const current = frame.current;
        const nexts = map.get(current).?;

        // Check if we done visiting the current frame
        if (frame.next_idx == nexts.items.len) {
            _ = frames.pop();
            continue;
        }

        const next = nexts.items[frame.next_idx];
        frame.next_idx += 1;

        if (std.mem.eql(u8, next, "start")) {
            // no way forward
            paths += 1;
        } else if (std.mem.eql(u8, next, "end")) {
            // Reaching the end
        } else if (std.ascii.isUpper(next[0])) {
            // Big cave
            try frames.append(Frame{
                .current = next,
                .next_idx = 0,
                .max_small_cave = frame.max_small_cave,
            });
        } else {
            // Small cave
            const visited_count = count(next, frames.items);
            if (visited_count < frame.max_small_cave) {
                try frames.append(Frame{
                    .current = next,
                    .next_idx = 0,
                    .max_small_cave = if (visited_count > 0) 1 else frame.max_small_cave,
                });
            }
        }
    }

    return paths;
}

fn count(item: []const u8, frames: []Frame) usize {
    var out: usize = 0;

    for (frames) |frame| {
        if (std.mem.eql(u8, item, frame.current)) out += 1;
    }

    return out;
}

fn part1(allocator: Allocator, map: Map) !usize {
    return count_paths(allocator, map, 1);
}

fn part2(allocator: Allocator, map: Map) !usize {
    return count_paths(allocator, map, 2);
}

test "paths small" {
    const input =
        \\start-A
        \\start-b
        \\A-c
        \\A-b
        \\b-d
        \\A-end
        \\b-end
    ;

    const allocator = std.testing.allocator;

    var map = try parse(allocator, input[0..]);
    defer deinit_map(&map);

    try std.testing.expectEqual(@as(usize, 10), try part1(allocator, map));
    try std.testing.expectEqual(@as(usize, 36), try part2(allocator, map));
}

test "paths medium" {
    const input =
        \\dc-end
        \\HN-start
        \\start-kj
        \\dc-start
        \\dc-HN
        \\LN-dc
        \\HN-end
        \\kj-sa
        \\kj-HN
        \\kj-dc
    ;

    const allocator = std.testing.allocator;

    var map = try parse(allocator, input[0..]);
    defer deinit_map(&map);

    try std.testing.expectEqual(@as(usize, 19), try part1(allocator, map));
    try std.testing.expectEqual(@as(usize, 103), try part2(allocator, map));
}

test "paths large" {
    const input =
        \\fs-end
        \\he-DX
        \\fs-he
        \\start-DX
        \\pj-DX
        \\end-zg
        \\zg-sl
        \\zg-pj
        \\pj-he
        \\RW-he
        \\fs-DX
        \\pj-RW
        \\zg-RW
        \\start-pj
        \\he-WI
        \\zg-he
        \\pj-fs
        \\start-RW
    ;

    const allocator = std.testing.allocator;

    var map = try parse(allocator, input[0..]);
    defer deinit_map(&map);

    try std.testing.expectEqual(@as(usize, 226), try part1(allocator, map));
    try std.testing.expectEqual(@as(usize, 3509), try part2(allocator, map));
}
