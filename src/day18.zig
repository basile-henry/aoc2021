const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day18.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    const nums = try parse(allocator, data);
    defer {
        for (nums.items) |n| {
            n.deinit();
        }

        nums.deinit();
    }

    print("Part 1: {d}\n", .{try part1(allocator, nums.items)});
    print("Part 2: {d}\n", .{try part2(allocator, nums.items)});
}

fn parse(allocator: *Allocator, input: []const u8) !std.ArrayList(SnailFish) {
    var out = std.ArrayList(SnailFish).init(allocator);
    errdefer {
        for (out.items) |n| {
            n.deinit();
        }

        out.deinit();
    }

    var lines = std.mem.tokenize(input, "\n");

    while (lines.next()) |line| {
        try out.append(try SnailFish.parse(allocator, line));
    }

    return out;
}

const ExplodeValue = struct {
    left: ?u8,
    right: ?u8,
};

const Node = union(enum) {
    const Self = @This();

    single: u8,
    pair: Pair,

    fn parse(allocator: *Allocator, input: []const u8) !Self {
        if (input[0] == '[') return Self{ .pair = try Pair.parse(allocator, input) };

        return Self{ .single = try std.fmt.parseInt(u8, input, 10) };
    }

    fn magnitude(self: Self) usize {
        switch (self) {
            .single => |x| return x,
            .pair => |p| return p.magnitude(),
        }
    }

    fn clone(self: Self, allocator: *Allocator) !Self {
        switch (self) {
            .single => |s| return Self{ .single = s },
            .pair => |p| return Self{ .pair = try p.clone(allocator) },
        }
    }

    fn explode(self: *Self, current_depth: usize) ?ExplodeValue {
        if (self.* == Self.pair) {
            if (current_depth < 4) {
                return self.pair.explode(current_depth + 1);
            } else {
                // Check it's not too deep
                std.debug.assert(self.pair.left.* == Self.single);
                std.debug.assert(self.pair.right.* == Self.single);

                const ret = ExplodeValue{
                    .left = self.pair.left.single,
                    .right = self.pair.right.single,
                };

                self.* = Self{ .single = 0 };

                return ret;
            }
        } else return null;
    }

    fn add_left(self: *Self, value: u8) void {
        switch (self.*) {
            .single => |*s| s.* += value,
            .pair => |*p| p.left.add_left(value),
        }
    }

    fn add_right(self: *Self, value: u8) void {
        switch (self.*) {
            .single => |*s| s.* += value,
            .pair => |*p| p.right.add_right(value),
        }
    }

    fn split(self: *Self, allocator: *Allocator) !bool {
        switch (self.*) {
            .single => |s| {
                if (s >= 10) {
                    const half = s / 2;

                    const new = try Pair.init_undefined(allocator);
                    new.left.* = Self{ .single = half };
                    new.right.* = Self{ .single = s - half };

                    self.* = Self{ .pair = new };

                    return true;
                } else {
                    return false;
                }
            },
            .pair => |*p| return try p.split(allocator),
        }
    }

    fn print(self: Self) void {
        switch (self) {
            .single => |s| std.debug.print("{d}", .{s}),
            .pair => |p| p.print(),
        }
    }
};

const Pair = struct {
    const Self = @This();

    left: *Node,
    right: *Node,

    fn deinit(self: Self, allocator: *Allocator) void {
        allocator.destroy(self.left);
        allocator.destroy(self.right);
    }

    fn init_undefined(allocator: *Allocator) !Self {
        var left = try allocator.create(Node);
        errdefer allocator.destroy(left);

        var right = try allocator.create(Node);
        errdefer allocator.destroy(left);

        return Self{
            .left = left,
            .right = right,
        };
    }

    fn parse(allocator: *Allocator, input: []const u8) anyerror!Self {
        if (input[0] != '[' or input[input.len - 1] != ']') return error.InvalidPair;

        const inner = input[1 .. input.len - 1];

        var split_idx: usize = 0;
        var count: usize = 0;
        for (inner) |c, i| {
            switch (c) {
                '[' => {
                    count += 1;
                },
                ']' => {
                    if (count == 0) return error.InvalidNode;

                    count -= 1;
                },
                ',' => {
                    if (count == 0) {
                        split_idx = i;
                        break;
                    }
                },
                else => {},
            }
        }

        var new = try Self.init_undefined(allocator);
        new.left.* = try Node.parse(allocator, inner[0..split_idx]);
        new.right.* = try Node.parse(allocator, inner[split_idx + 1 ..]);

        return new;
    }

    fn magnitude(self: Self) usize {
        return 3 * self.left.magnitude() + 2 * self.right.magnitude();
    }

    fn clone(self: Self, allocator: *Allocator) anyerror!Self {
        var new = try Self.init_undefined(allocator);
        errdefer new.deinit(allocator);

        new.left.* = try self.left.clone(allocator);
        new.right.* = try self.right.clone(allocator);

        return new;
    }

    fn explode(self: *Self, current_depth: usize) ?ExplodeValue {
        var ret = ExplodeValue{
            .left = null,
            .right = null,
        };

        var left_value = self.left.explode(current_depth);
        if (left_value) |l_value| {
            ret.left = l_value.left;
            if (l_value.right) |v| self.right.add_left(v);
        }

        var right_value = self.right.explode(current_depth);
        if (right_value) |r_value| {
            if (r_value.left) |v| self.left.add_right(v);
            ret.right = r_value.right;
        }

        if (ret.left == null and ret.right == null) return null;

        return ret;
    }

    fn split(self: *Self, allocator: *Allocator) anyerror!bool {
        if (try self.left.split(allocator)) return true;
        return try self.right.split(allocator);
    }

    fn print(self: Self) void {
        std.debug.print("[", .{});
        self.left.print();
        std.debug.print(",", .{});
        self.right.print();
        std.debug.print("]", .{});
    }
};

const SnailFish = struct {
    const Self = @This();

    arena: std.heap.ArenaAllocator,
    root: Pair,

    fn deinit(self: Self) void {
        self.arena.deinit();
    }

    fn parse(allocator: *Allocator, input: []const u8) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const root = try Pair.parse(&arena.allocator, input);

        return Self{
            .arena = arena,
            .root = root,
        };
    }

    fn magnitude(self: Self) usize {
        return self.root.magnitude();
    }

    fn reduce(self: *Self) !void {
        _ = self.root.explode(1);

        while (try self.root.split(&self.arena.allocator)) {
            _ = self.root.explode(1);
        }
    }

    fn clone_into(self: Self, allocator: *Allocator) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const root = try self.root.clone(&arena.allocator);

        return Self{
            .arena = arena,
            .root = root,
        };
    }

    fn add(self: *Self, other: Self) !void {
        const allocator = &self.arena.allocator;

        var new_root = try Pair.init_undefined(allocator);
        errdefer new_root.deinit(allocator);

        new_root.left.* = Node{ .pair = self.root };
        new_root.right.* = Node{ .pair = try other.root.clone(allocator) };

        self.root = new_root;

        try self.reduce();
    }

    fn print(self: Self) void {
        self.root.print();
        std.debug.print("\n", .{});
    }
};

fn part1(allocator: *Allocator, nums: []SnailFish) !usize {
    var sum = try nums[0].clone_into(allocator);
    defer sum.deinit();

    for (nums[1..]) |n| {
        try sum.add(n);
    }

    return sum.magnitude();
}

fn part2(allocator: *Allocator, nums: []SnailFish) !usize {
    var max: usize = 0;

    for (nums[0..]) |x, i| {
        for (nums[i + 1 ..]) |y| {
            {
                var temp = try x.clone_into(allocator);
                defer temp.deinit();

                try temp.add(y);
                max = std.math.max(max, temp.magnitude());
            }
            {
                var temp = try y.clone_into(allocator);
                defer temp.deinit();

                try temp.add(x);
                max = std.math.max(max, temp.magnitude());
            }
        }
    }

    return max;
}

test "snailfish: parse & magnitude" {
    const allocator = std.testing.allocator;

    const n1 = try SnailFish.parse(allocator, "[[1,2],[[3,4],5]]");
    defer n1.deinit();

    try std.testing.expectEqual(@as(usize, 143), n1.magnitude());

    const n2 = try SnailFish.parse(allocator, "[[[[0,7],4],[[7,8],[6,0]]],[8,1]]");
    defer n2.deinit();

    try std.testing.expectEqual(@as(usize, 1384), n2.magnitude());

    const n3 = try SnailFish.parse(allocator, "[[[[1,1],[2,2]],[3,3]],[4,4]]");
    defer n3.deinit();

    try std.testing.expectEqual(@as(usize, 445), n3.magnitude());

    const n4 = try SnailFish.parse(allocator, "[[[[3,0],[5,3]],[4,4]],[5,5]]");
    defer n4.deinit();

    try std.testing.expectEqual(@as(usize, 791), n4.magnitude());

    const n5 = try SnailFish.parse(allocator, "[[[[5,0],[7,4]],[5,5]],[6,6]]");
    defer n5.deinit();

    try std.testing.expectEqual(@as(usize, 1137), n5.magnitude());

    const n6 = try SnailFish.parse(allocator, "[[[[8,7],[7,7]],[[8,6],[7,7]]],[[[0,7],[6,6]],[8,7]]]");
    defer n6.deinit();

    try std.testing.expectEqual(@as(usize, 3488), n6.magnitude());
}

test "snailfish: parse, sum and magnitude" {
    const input =
        \\[[[0,[5,8]],[[1,7],[9,6]]],[[4,[1,2]],[[1,4],2]]]
        \\[[[5,[2,8]],4],[5,[[9,9],0]]]
        \\[6,[[[6,2],[5,6]],[[7,6],[4,7]]]]
        \\[[[6,[0,7]],[0,9]],[4,[9,[9,0]]]]
        \\[[[7,[6,4]],[3,[1,3]]],[[[5,5],1],9]]
        \\[[6,[[7,3],[3,2]]],[[[3,8],[5,7]],4]]
        \\[[[[5,4],[7,7]],8],[[8,3],8]]
        \\[[9,3],[[9,9],[6,[4,9]]]]
        \\[[2,[[7,7],7]],[[5,8],[[9,3],[0,2]]]]
        \\[[[[5,2],5],[8,[3,7]]],[[5,[7,5]],[4,4]]]
    ;

    const allocator = std.testing.allocator;

    const nums = try parse(allocator, input);
    defer {
        for (nums.items) |n| {
            n.deinit();
        }

        nums.deinit();
    }

    try std.testing.expectEqual(@as(usize, 4140), try part1(allocator, nums.items));
    try std.testing.expectEqual(@as(usize, 3993), try part2(allocator, nums.items));
}
