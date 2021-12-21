const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day20.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    var prob = try parse(allocator, data);
    defer prob.img.deinit();

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        try prob.img.enhance(allocator, prob.algo);

        if (i == 1) print("Part 1: {d}\n", .{prob.img.count()});
    }

    print("Part 2: {d}\n", .{prob.img.count()});
}

const ImgEnhanceAlgo = [512]u1;

const Img = struct {
    const Self = @This();

    outside: u1,
    inside: std.ArrayList(std.ArrayList(u1)),

    fn deinit(self: Self) void {
        for (self.inside.items) |row| row.deinit();
        self.inside.deinit();
    }

    fn dump(self: Self) void {
        for (self.inside.items) |row| {
            for (row.items) |c| {
                if (c == 1) {
                    print("#", .{});
                } else {
                    print(".", .{});
                }
            }
            print("\n", .{});
        }
    }

    fn count(self: Self) usize {
        var out: usize = 0;

        for (self.inside.items) |row| {
            for (row.items) |c| {
                if (c == 1) out += 1;
            }
        }

        return out;
    }

    fn enhance(self: *Self, allocator: Allocator, algo: ImgEnhanceAlgo) !void {
        const row_size = self.inside.items[0].items.len + 2;
        const num_rows = self.inside.items.len + 2;

        // Add new rows and columns
        for (self.inside.items) |*row| {
            try row.insert(0, self.outside);
            try row.append(self.outside);
        }

        var first_row = std.ArrayList(u1).init(allocator);
        try first_row.appendNTimes(self.outside, row_size);

        var last_row = std.ArrayList(u1).init(allocator);
        try last_row.appendNTimes(self.outside, row_size);

        try self.inside.insert(0, first_row);
        try self.inside.append(last_row);

        var out_buffer = [2]std.ArrayList(u1){
            std.ArrayList(u1).init(allocator),
            std.ArrayList(u1).init(allocator),
        };
        defer {
            out_buffer[0].deinit();
            out_buffer[1].deinit();
        }

        try out_buffer[0].appendNTimes(undefined, row_size);
        try out_buffer[1].appendNTimes(undefined, row_size);

        for (self.inside.items) |row, i| {
            for (row.items) |_, j| {
                var idx: u9 = 0;

                var dy: isize = -1;
                while (dy <= 1) : (dy += 1) {
                    var dx: isize = -1;
                    while (dx <= 1) : (dx += 1) {
                        const y = @intCast(isize, i) + dy;
                        const x = @intCast(isize, j) + dx;

                        idx <<= 1;

                        if (y < 0 or y >= num_rows or x < 0 or x >= row_size) {
                            idx |= self.outside;
                        } else {
                            idx |= self.inside.items[@intCast(usize, y)].items[@intCast(usize, x)];
                        }
                    }
                }

                out_buffer[0].items[j] = algo[idx];
            }

            if (i > 0) std.mem.swap(std.ArrayList(u1), &out_buffer[1], &self.inside.items[i - 1]);
            std.mem.swap(std.ArrayList(u1), &out_buffer[0], &out_buffer[1]);
        }

        std.mem.swap(std.ArrayList(u1), &out_buffer[1], &self.inside.items[num_rows - 1]);

        self.outside = algo[if (self.outside == 1) 0b1_1111_1111 else 0];
    }
};

fn reset_as(row: *std.ArrayList(u1), from: std.ArrayList(u1)) void {
    row.clearRetainingCapacity();
    row.appendSliceAssumeCapacity(from.items);
}

const ParseResult = struct {
    algo: ImgEnhanceAlgo,
    img: Img,
};

fn char_to_pixel(c: u8) !u1 {
    return switch (c) {
        '#' => 1,
        '.' => 0,
        else => error.InvalidChar,
    };
}

fn parse(allocator: Allocator, input: []const u8) !ParseResult {
    var it = std.mem.split(u8, input, "\n\n");

    const raw_enhance = it.next().?;
    var algo: ImgEnhanceAlgo = undefined;

    std.debug.assert(raw_enhance.len == 512);
    for (raw_enhance) |c, i| {
        algo[i] = try char_to_pixel(c);
    }

    var img = std.ArrayList(std.ArrayList(u1)).init(allocator);

    var lines = std.mem.tokenize(u8, it.next().?, "\n");
    while (lines.next()) |line| {
        var row = try std.ArrayList(u1).initCapacity(allocator, line.len);
        for (line) |c| {
            try row.append(try char_to_pixel(c));
        }

        try img.append(row);
    }

    return ParseResult{
        .algo = algo,
        .img = Img{
            .outside = 0,
            .inside = img,
        },
    };
}

test "image enhancement" {
    const input =
        \\..#.#..#####.#.#.#.###.##.....###.##.#..###.####..#####..#....#..#..##..###..######.###...####..#..#####..##..#.#####...##.#.#..#.##..#.#......#.###.######.###.####...#.##.##..#..#..#####.....#.#....###..#.##......#.....#..#..#..##..#...##.######.####.####.#.#...#.......#..#.#.#...####.##.#......#..#...##.#.##..#...##.#.##..###.#......#.#.......#.#.#.####.###.##...#.....####.#..#..#.##.#....##..#.####....##...##..#...#......#.#.......#.......##..####..#...#.#.#...##..#.#..###..#####........#..####......#..#
        \\
        \\#..#.
        \\#....
        \\##..#
        \\..#..
        \\..###
    ;

    const allocator = std.testing.allocator;

    var prob = try parse(allocator, input);
    defer prob.img.deinit();

    try prob.img.enhance(allocator, prob.algo);
    try prob.img.enhance(allocator, prob.algo);

    try std.testing.expectEqual(@as(usize, 35), prob.img.count());
}
