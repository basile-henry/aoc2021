const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day05.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    const lines = try parse(allocator, data[0..]);
    defer lines.deinit();

    const res = try solve(allocator, lines.items);

    print("Part 1: {d}\n", .{res.part1});
    print("Part 2: {d}\n", .{res.part2});
}

const Point = struct {
    const Self = @This();

    x: i16,
    y: i16,

    fn parse(input: []const u8) !Self {
        var pos = std.mem.split(input, ",");

        const x = try std.fmt.parseInt(i16, pos.next().?, 10);
        const y = try std.fmt.parseInt(i16, pos.next().?, 10);

        return Point{
            .x = x,
            .y = y,
        };
    }

    fn eql(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const Direction = enum {
    Horizontal,
    Vertical,
    Diagonal,
};

const Line = struct {
    const Self = @This();

    start: Point,
    end: Point,

    fn parse(input: []const u8) !Self {
        var point_str = std.mem.split(input, " -> ");
        const start = try Point.parse(point_str.next().?);
        const end = try Point.parse(point_str.next().?);

        return Line{
            .start = start,
            .end = end,
        };
    }

    fn direction(self: Self) Direction {
        if (self.start.x == self.end.x) return Direction.Vertical;
        if (self.start.y == self.end.y) return Direction.Horizontal;
        return Direction.Diagonal;
    }

    fn points(self: *const Self, out: *std.ArrayList(Point)) !void {
        out.clearRetainingCapacity();

        switch (self.direction()) {
            .Horizontal => {
                const from = std.math.min(self.start.x, self.end.x);
                const to = std.math.max(self.start.x, self.end.x);

                var i = from;
                while (i <= to) : (i += 1) {
                    try out.append(Point{
                        .x = i,
                        .y = self.start.y,
                    });
                }
            },
            .Vertical => {
                const from = std.math.min(self.start.y, self.end.y);
                const to = std.math.max(self.start.y, self.end.y);

                var i = from;
                while (i <= to) : (i += 1) {
                    try out.append(Point{
                        .x = self.start.x,
                        .y = i,
                    });
                }
            },
            .Diagonal => {
                // Check diagonal is 45 degree
                const x_dist = try std.math.absInt(self.start.x - self.start.y);
                const y_dist = try std.math.absInt(self.start.x - self.start.y);
                std.debug.assert(x_dist == y_dist);

                const assending_x = self.start.x < self.end.x;
                const delta_x = if (self.start.x < self.end.x) @as(i16, 1) else -1;
                const delta_y = if (self.start.y < self.end.y) @as(i16, 1) else -1;

                var x = self.start.x;
                var y = self.start.y;

                while ((assending_x and x <= self.end.x) or (!assending_x and x >= self.end.x)) : ({
                    x += delta_x;
                    y += delta_y;
                }) {
                    try out.append(Point{
                        .x = x,
                        .y = y,
                    });
                }
            },
        }
    }
};

fn parse(allocator: *Allocator, input: []const u8) !std.ArrayList(Line) {
    var lines = std.mem.tokenize(input, "\n");
    var out = std.ArrayList(Line).init(allocator);
    errdefer out.deinit();

    while (lines.next()) |line| {
        const l = try Line.parse(line);
        try out.append(l);
    }

    return out;
}

const Result = struct {
    part1: usize,
    part2: usize,
};

const Cell = struct {
    no_diagonal_count: u2,
    with_diagonal_count: u2,
};

fn solve(allocator: *Allocator, lines: []const Line) !Result {
    var points = try allocator.create([1000][1000]Cell);
    defer allocator.free(points);

    for (points) |*row| {
        std.mem.set(Cell, row[0..], Cell{ .no_diagonal_count = 0, .with_diagonal_count = 0 });
    }

    var overlaps: usize = 0;
    var overlaps_with_diagonal: usize = 0;

    var line_points = std.ArrayList(Point).init(allocator);
    defer line_points.deinit();

    for (lines) |line| {
        try line.points(&line_points);

        for (line_points.items) |lp| {
            const x = @intCast(usize, lp.x);
            const y = @intCast(usize, lp.y);
            const p = &points[y][x];

            if (p.with_diagonal_count < 3) {
                p.with_diagonal_count += 1;
            }

            if (p.with_diagonal_count == 2) {
                overlaps_with_diagonal += 1;
            }

            if (line.direction() != Direction.Diagonal) {
                if (p.no_diagonal_count < 3) {
                    p.no_diagonal_count += 1;
                }

                if (p.no_diagonal_count == 2) {
                    overlaps += 1;
                }
            }
        }
    }

    return Result{
        .part1 = overlaps,
        .part2 = overlaps_with_diagonal,
    };
}

test "overlap" {
    const input =
        \\0,9 -> 5,9
        \\8,0 -> 0,8
        \\9,4 -> 3,4
        \\2,2 -> 2,1
        \\7,0 -> 7,4
        \\6,4 -> 2,0
        \\0,9 -> 2,9
        \\3,4 -> 1,4
        \\0,0 -> 8,8
        \\5,5 -> 8,2
    ;

    const allocator = std.testing.allocator;

    const lines = try parse(allocator, input[0..]);
    defer lines.deinit();

    const res = try solve(allocator, lines.items);

    try std.testing.expectEqual(@as(usize, 5), res.part1);
    try std.testing.expectEqual(@as(usize, 12), res.part2);
}
