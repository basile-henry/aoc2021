const std = @import("std");
const Allocator = std.mem.Allocator;
const BitSet = std.bit_set.IntegerBitSet;
const print = std.debug.print;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = &gpa_impl.allocator;

const data = @embedFile("../inputs/day05.txt");

pub fn main() anyerror!void {
    const lines = try parse(gpa, data[0..]);
    defer lines.deinit();

    print("Part 1: {d}\n", .{try solve(gpa, false, lines.items)});
    print("Part 2: {d}\n", .{try solve(gpa, true, lines.items)});
}

const Point = struct {
    const Self = @This();

    x: isize,
    y: isize,

    fn parse(input: []const u8) !Self {
        var pos = std.mem.split(input, ",");

        const x = try std.fmt.parseInt(isize, pos.next().?, 10);
        const y = try std.fmt.parseInt(isize, pos.next().?, 10);

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
    direction: Direction,

    fn parse(input: []const u8) !Self {
        var point_str = std.mem.split(input, " -> ");
        const start = try Point.parse(point_str.next().?);
        const end = try Point.parse(point_str.next().?);
        const direction =
            if (start.x == end.x) Direction.Vertical else if (start.y == end.y) Direction.Horizontal else Direction.Diagonal;

        return Line{
            .start = start,
            .end = end,
            .direction = direction,
        };
    }

    fn points(self: *const Self, out: *std.ArrayList(Point)) !void {
        out.clearRetainingCapacity();

        switch (self.direction) {
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
                const delta_x = if (self.start.x < self.end.x) @as(isize, 1) else -1;
                const delta_y = if (self.start.y < self.end.y) @as(isize, 1) else -1;

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

fn solve(allocator: *Allocator, diagonals: bool, lines: []const Line) !usize {
    var points = std.AutoHashMap(Point, usize).init(allocator);
    defer points.deinit();

    var overlaps: usize = 0;

    var line_points = std.ArrayList(Point).init(allocator);
    defer line_points.deinit();

    for (lines) |line| {
        if (!diagonals and line.direction == Direction.Diagonal) {
            continue;
        }

        try line.points(&line_points);

        for (line_points.items) |p| {
            if (points.getPtr(p)) |x| {
                if (x.* == 1) {
                    overlaps += 1;
                }
                x.* += 1;
            } else {
                try points.put(p, 1);
            }
        }
    }

    return overlaps;
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

    const part1 = try solve(allocator, false, lines.items);

    const part2 = try solve(allocator, true, lines.items);

    try std.testing.expectEqual(@as(usize, 5), part1);
    try std.testing.expectEqual(@as(usize, 12), part2);
}
