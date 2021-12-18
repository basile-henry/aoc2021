const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day15.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    const grid = try parse(allocator, data);
    defer deinit_grid(u64, grid);

    print("Part 1: {d}\n", .{try part1(allocator, grid)});
    print("Part 2: {d}\n", .{try part2(allocator, grid)});
}

fn Grid(comptime T: type) type {
    return std.ArrayList(std.ArrayList(T));
}

fn deinit_grid(comptime T: type, grid: Grid(T)) void {
    for (grid.items) |row| {
        row.deinit();
    }

    grid.deinit();
}

fn parse(allocator: *Allocator, input: []const u8) !Grid(u64) {
    var grid = Grid(u64).init(allocator);

    var lines = std.mem.tokenize(input, "\n");
    while (lines.next()) |line| {
        var row = try std.ArrayList(u64).initCapacity(allocator, line.len);

        for (line) |c| {
            try row.append(c - '0');
        }

        try grid.append(row);
    }

    return grid;
}

fn part1(allocator: *Allocator, grid: Grid(u64)) !u64 {
    return solve(1, allocator, grid);
}

fn part2(allocator: *Allocator, grid: Grid(u64)) !u64 {
    return solve(5, allocator, grid);
}

const Point = struct {
    const Self = @This();

    x: usize,
    y: usize,
    width: usize,
    distances: *[]u64,

    fn distance(self: Self) u64 {
        return self.distances.*[self.y * self.width + self.x];
    }

    fn update_distance(self: *Self, dist: u64) bool {
        const current = self.distances.*[self.y * self.width + self.x];

        if (dist < current) {
            self.distances.*[self.y * self.width + self.x] = dist;
            return true;
        }

        return false;
    }
};

fn shorter_distance(a: Point, b: Point) std.math.Order {
    return std.math.order(a.distance(), b.distance());
}

fn solve(comptime repeat: usize, allocator: *Allocator, grid: Grid(u64)) !u64 {
    const yl = grid.items.len;
    const xl = grid.items[0].items.len;

    const height = yl * repeat;
    const width = xl * repeat;

    var distances = try allocator.alloc(u64, height * width);
    defer allocator.free(distances);

    std.mem.set(u64, distances, std.math.maxInt(u64));
    distances[0] = 0;

    var to_visit = std.PriorityQueue(Point).init(allocator, shorter_distance);
    defer to_visit.deinit();

    try to_visit.add(Point{
        .x = 0,
        .y = 0,
        .width = width,
        .distances = &distances,
    });

    while (to_visit.removeOrNull()) |current| {
        if (current.y == height - 1 and current.x == width - 1) return current.distance();

        const neighbours = [4][2]isize{
            [2]isize{ -1, 0 }, // left
            [2]isize{ 1, 0 }, // right
            [2]isize{ 0, 1 }, // down
            [2]isize{ 0, -1 }, // up
        };

        for (neighbours) |n| {
            const nx = @intCast(isize, current.x) + n[0];
            const ny = @intCast(isize, current.y) + n[1];

            if (nx < 0 or nx >= width or ny < 0 or ny >= height) continue;

            const unx = @intCast(usize, nx);
            const uny = @intCast(usize, ny);

            var neighbour_point = Point{
                .x = unx,
                .y = uny,
                .width = width,
                .distances = &distances,
            };

            var cost: u64 = grid.items[uny % yl].items[unx % xl] + (unx / xl) + (uny / yl);
            if (cost > 9) cost -= 9;

            if (neighbour_point.update_distance(current.distance() + cost)) {
                try to_visit.add(neighbour_point);
            }
        }
    } else unreachable;
}

test "chiton" {
    const input =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
    ;

    const allocator = std.testing.allocator;

    const grid = try parse(allocator, input);
    defer {
        for (grid.items) |row| {
            row.deinit();
        }

        grid.deinit();
    }

    try std.testing.expectEqual(@as(u64, 40), try part1(allocator, grid));
    try std.testing.expectEqual(@as(u64, 315), try part2(allocator, grid));
}
