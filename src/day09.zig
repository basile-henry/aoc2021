const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day09.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    const basin = try parse(allocator, data[0..]);
    defer {
        for (basin.items) |row| {
            row.deinit();
        }
        basin.deinit();
    }

    print("Part 1: {d}\n", .{part1(basin)});
    print("Part 2: {d}\n", .{try part2(allocator, basin)});
}

const Basin = std.ArrayList(std.ArrayList(u4));

fn parse(allocator: Allocator, input: []const u8) !Basin {
    var basin = try Basin.initCapacity(allocator, 100);
    var lines = std.mem.tokenize(u8, input, "\n");

    while (lines.next()) |line| {
        if (line.len > 0) {
            var row = try std.ArrayList(u4).initCapacity(allocator, 100);

            for (line) |c| {
                try row.append(@intCast(u4, c - '0'));
            }

            try basin.append(row);
        }
    }

    return basin;
}

fn part1(basin: Basin) usize {
    var risk_level: usize = 0;

    for (basin.items) |row, y| {
        for (row.items) |height, x| {
            var lower = true;

            // up
            if (y > 0 and basin.items[y - 1].items[x] <= height) lower = false;
            // down
            if (y < basin.items.len - 1 and basin.items[y + 1].items[x] <= height) lower = false;
            // left
            if (x > 0 and row.items[x - 1] <= height) lower = false;
            // right
            if (x < row.items.len - 1 and row.items[x + 1] <= height) lower = false;

            if (lower) {
                risk_level += 1 + height;
            }
        }
    }

    return risk_level;
}
const Point = struct {
    x: isize,
    y: isize,
};

const PointSet = std.AutoHashMap(Point, void);

fn add_point(arena: *std.heap.ArenaAllocator, point: Point, basin: Basin, unique_basins: *std.ArrayList(*PointSet), basins_map: *std.AutoHashMap(Point, *PointSet)) anyerror!void {
    if (basins_map.contains(point)) return;

    const x = point.x;
    const y = point.y;
    if (y < 0 or y >= basin.items.len) return;
    const row = basin.items[@intCast(usize, y)];
    if (x < 0 or x >= row.items.len) return;
    const height = row.items[@intCast(usize, x)];

    if (height == 9) return;

    const adjacent = [4]Point{
        .{ .x = x - 1, .y = y },
        .{ .x = x + 1, .y = y },
        .{ .x = x, .y = y - 1 },
        .{ .x = x, .y = y + 1 },
    };

    var found_adjacent = false;

    for (adjacent) |p| {
        if (p.y < 0 or p.y >= basin.items.len or p.x < 0 or p.x >= row.items.len) continue;
        if (basin.items[@intCast(usize, p.y)].items[@intCast(usize, p.x)] == 9) continue;

        if (basins_map.get(p)) |ptr| {
            try ptr.put(point, .{});
            try basins_map.put(point, ptr);
            found_adjacent = true;
            break;
        }
    }

    if (!found_adjacent) {
        const ptr = try arena.allocator().create(PointSet);
        ptr.* = PointSet.init(arena.allocator());
        try ptr.*.put(point, .{});
        try basins_map.put(point, ptr);
        try unique_basins.append(ptr);
    }

    for (adjacent) |p| {
        try add_point(arena, p, basin, unique_basins, basins_map);
    }
}

fn part2(allocator: Allocator, basin: Basin) !usize {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var unique_basins = std.ArrayList(*PointSet).init(allocator);
    defer unique_basins.deinit();

    var basins_map = std.AutoHashMap(Point, *PointSet).init(allocator);
    defer basins_map.deinit();

    try basins_map.ensureTotalCapacity(100 * 100);

    for (basin.items) |row, y| {
        for (row.items) |_, x| {
            const point = Point{ .x = @intCast(isize, x), .y = @intCast(isize, y) };
            try add_point(&arena, point, basin, &unique_basins, &basins_map);
        }
    }

    var top_3 = [3]usize{ 0, 0, 0 };
    {
        for (unique_basins.items) |b| {
            var current: usize = b.*.count();
            for (top_3) |*t| {
                if (current > t.*) {
                    std.mem.swap(usize, &current, t);
                }
            }
        }
    }

    return top_3[0] * top_3[1] * top_3[2];
}

test "smoke basin" {
    const input =
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
    ;

    const allocator = std.testing.allocator;

    const basin = try parse(allocator, input[0..]);
    defer {
        for (basin.items) |row| {
            row.deinit();
        }
        basin.deinit();
    }

    try std.testing.expectEqual(@as(usize, 15), part1(basin));
    try std.testing.expectEqual(@as(usize, 1134), try part2(allocator, basin));
}
