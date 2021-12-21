const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day05.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    const lines = try parse(allocator, data[0..]);
    defer lines.deinit();

    const res = try solve(lines.items);

    print("Part 1: {d}\n", .{res.part1});
    print("Part 2: {d}\n", .{res.part2});
}

const Point = struct {
    const Self = @This();

    x: i16,
    y: i16,

    fn parse(input: []const u8) !Self {
        var pos = std.mem.split(u8, input, ",");

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

const PointIterator = struct {
    const Self = @This();

    line: Line,
    idx: i16,

    fn next(self: *Self) ?Point {
        switch (self.line.direction()) {
            .Horizontal => {
                const from = std.math.min(self.line.start.x, self.line.end.x);
                const to = std.math.max(self.line.start.x, self.line.end.x);

                const x = from + self.idx;
                if (x <= to) {
                    self.idx += 1;
                    return Point{
                        .x = x,
                        .y = self.line.start.y,
                    };
                }
            },
            .Vertical => {
                const from = std.math.min(self.line.start.y, self.line.end.y);
                const to = std.math.max(self.line.start.y, self.line.end.y);

                const y = from + self.idx;
                if (y <= to) {
                    self.idx += 1;
                    return Point{
                        .x = self.line.start.x,
                        .y = y,
                    };
                }
            },
            .Diagonal => {
                const assending_x = self.line.start.x < self.line.end.x;
                const delta_x = if (self.line.start.x < self.line.end.x) @as(i16, 1) else -1;
                const delta_y = if (self.line.start.y < self.line.end.y) @as(i16, 1) else -1;

                var x = self.line.start.x + self.idx * delta_x;
                var y = self.line.start.y + self.idx * delta_y;

                if ((assending_x and x <= self.line.end.x) or (!assending_x and x >= self.line.end.x)) {
                    self.idx += 1;
                    return Point{
                        .x = x,
                        .y = y,
                    };
                }
            },
        }

        return null;
    }
};

const Line = struct {
    const Self = @This();

    start: Point,
    end: Point,

    fn parse(input: []const u8) !Self {
        var point_str = std.mem.split(u8, input, " -> ");
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

    fn points_iterator(self: Self) PointIterator {
        return PointIterator{
            .line = self,
            .idx = 0,
        };
    }
};

fn parse(allocator: Allocator, input: []const u8) !std.ArrayList(Line) {
    var lines = std.mem.tokenize(u8, input, "\n");
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

var points: [1000][1000]Cell = undefined; // zero initialisation

fn solve(lines: []const Line) !Result {
    var overlaps: usize = 0;
    var overlaps_with_diagonal: usize = 0;

    for (lines) |line| {
        var it = line.points_iterator();

        while (it.next()) |lp| {
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

    const res = try solve(lines.items);

    try std.testing.expectEqual(@as(usize, 5), res.part1);
    try std.testing.expectEqual(@as(usize, 12), res.part2);
}
