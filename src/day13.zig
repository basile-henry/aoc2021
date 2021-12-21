const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day13.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    var instr = try Instr.parse(allocator, data[0..]);
    defer instr.deinit();

    print("Part 1: {d}\n", .{try part1(allocator, instr)});
    print("Part 2:\n", .{});
    try part2(allocator, instr);
}

const Point = struct {
    const Self = @This();

    x: isize,
    y: isize,

    fn parse(input: []const u8) !Self {
        var it = std.mem.tokenize(u8, input, ",");

        const x = try std.fmt.parseInt(isize, it.next().?, 10);
        const y = try std.fmt.parseInt(isize, it.next().?, 10);

        return Point{
            .x = x,
            .y = y,
        };
    }
};

const Fold = union(enum) {
    const Self = @This();

    x: isize,
    y: isize,

    fn parse(input: []const u8) !Self {
        const fold_str = std.mem.trimLeft(u8, input, "fold along ");

        switch (fold_str[0]) {
            'x' => {
                const x = try std.fmt.parseInt(isize, std.mem.trimLeft(u8, fold_str, "x="), 10);

                return Fold{ .x = x };
            },
            'y' => {
                const y = try std.fmt.parseInt(isize, std.mem.trimLeft(u8, fold_str, "y="), 10);

                return Fold{ .y = y };
            },
            else => return error.UnexpectedFoldDim,
        }
    }
};

const Instr = struct {
    const Self = @This();

    points: std.AutoHashMap(Point, void),
    folds: std.ArrayList(Fold),

    fn deinit(self: *Self) void {
        self.points.deinit();
        self.folds.deinit();
        self.* = undefined;
    }

    fn parse(allocator: Allocator, input: []const u8) !Self {
        var lines = std.mem.split(u8, input, "\n");

        var points = std.AutoHashMap(Point, void).init(allocator);
        var folds = std.ArrayList(Fold).init(allocator);

        var parsing_folds = false;

        while (lines.next()) |line| {
            if (line.len == 0) {
                parsing_folds = true;
                continue;
            }

            if (parsing_folds) {
                const fold = try Fold.parse(line);
                try folds.append(fold);
            } else {
                const point = try Point.parse(line);
                try points.put(point, .{});
            }
        }

        return Instr{
            .points = points,
            .folds = folds,
        };
    }
};

fn part1(allocator: Allocator, instr: Instr) !usize {
    var points = std.AutoHashMap(Point, void).init(allocator);
    defer points.deinit();

    const fold = instr.folds.items[0];
    var it = instr.points.keyIterator();

    while (it.next()) |point| {
        switch (fold) {
            .x => |x| {
                if (point.x > x) {
                    try points.put(Point{
                        .x = 2 * x - point.x,
                        .y = point.y,
                    }, .{});
                } else {
                    try points.put(point.*, .{});
                }
            },
            .y => |y| {
                if (point.y > y) {
                    try points.put(Point{
                        .x = point.x,
                        .y = 2 * y - point.y,
                    }, .{});
                } else {
                    try points.put(point.*, .{});
                }
            },
        }
    }

    return points.count();
}

fn part2(allocator: Allocator, instr: Instr) !void {
    var points = try instr.points.clone();
    defer points.deinit();

    var next_points = std.AutoHashMap(Point, void).init(allocator);
    defer next_points.deinit();

    var bound_x: isize = std.math.maxInt(isize);
    var bound_y: isize = std.math.maxInt(isize);

    for (instr.folds.items) |fold| {
        next_points.clearRetainingCapacity();

        var it = points.keyIterator();

        while (it.next()) |point| {
            switch (fold) {
                .x => |x| {
                    bound_x = std.math.min(bound_x, x);
                    if (point.x > x) {
                        try next_points.put(Point{
                            .x = 2 * x - point.x,
                            .y = point.y,
                        }, .{});
                    } else {
                        try next_points.put(point.*, .{});
                    }
                },
                .y => |y| {
                    bound_y = std.math.min(bound_y, y);
                    if (point.y > y) {
                        try next_points.put(Point{
                            .x = point.x,
                            .y = 2 * y - point.y,
                        }, .{});
                    } else {
                        try next_points.put(point.*, .{});
                    }
                },
            }
        }

        std.mem.swap(std.AutoHashMap(Point, void), &points, &next_points);
    }

    draw_points(bound_x, bound_y, points);
}

fn draw_points(bound_x: isize, bound_y: isize, points: std.AutoHashMap(Point, void)) void {
    var y: isize = 0;
    while (y <= bound_y) : (y += 1) {
        var x: isize = 0;
        while (x <= bound_x) : (x += 1) {
            if (points.contains(Point{ .x = x, .y = y })) {
                print("#", .{});
            } else {
                print(".", .{});
            }
        }
        print("\n", .{});
    }
}

test "folding paper" {
    const input =
        \\6,10
        \\0,14
        \\9,10
        \\0,3
        \\10,4
        \\4,11
        \\6,0
        \\6,12
        \\4,1
        \\0,13
        \\10,12
        \\3,4
        \\3,0
        \\8,4
        \\1,10
        \\2,14
        \\8,10
        \\9,0
        \\
        \\fold along y=7
        \\fold along x=5
    ;

    const allocator = std.testing.allocator;

    var instr = try Instr.parse(allocator, input[0..]);
    defer instr.deinit();

    try std.testing.expectEqual(@as(usize, 17), try part1(allocator, instr));
}
