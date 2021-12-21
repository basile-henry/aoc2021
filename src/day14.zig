const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day14.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    var polymer = try Polymer.parse(allocator, data[0..]);
    defer polymer.deinit();

    print("Part 1: {d}\n", .{try part1(allocator, polymer)});
    print("Part 2: {d}\n", .{try part2(allocator, polymer)});
}

const Polymer = struct {
    const Self = @This();

    template: []const u8,
    insertion_rules: std.AutoHashMap([2]u8, u8),

    fn deinit(self: *Self) void {
        self.insertion_rules.deinit();
    }

    fn parse(allocator: Allocator, input: []const u8) !Self {
        var it = std.mem.split(u8, input, "\n\n");

        const template = it.next().?;
        var insertion_rules = std.AutoHashMap([2]u8, u8).init(allocator);

        var lines = std.mem.tokenize(u8, it.next().?, "\n");
        while (lines.next()) |line| {
            var rule = std.mem.split(u8, line, " -> ");
            const pair_str = rule.next().?;
            const insert_str = rule.next().?;

            const pair: [2]u8 = pair_str[0..2].*;
            const insert: u8 = insert_str[0];

            try insertion_rules.put(pair, insert);
        }

        return Self{
            .template = template,
            .insertion_rules = insertion_rules,
        };
    }
};

fn put_or_add(comptime K: type, comptime V: type, hm: *std.AutoHashMap(K, V), key: K, val: V) !void {
    if (hm.getPtr(key)) |p| {
        p.* += val;
    } else {
        try hm.put(key, val);
    }
}

fn count_min_max(allocator: Allocator, polymer: Polymer, max_step: usize) !usize {
    var pair_map = std.AutoHashMap([2]u8, usize).init(allocator);
    defer pair_map.deinit();
    var next_pair_map = std.AutoHashMap([2]u8, usize).init(allocator);
    defer next_pair_map.deinit();

    for (polymer.template) |c, i| {
        if (i == 0) continue;

        try put_or_add([2]u8, usize, &pair_map, [2]u8{ polymer.template[i - 1], c }, 1);
    }

    var step: usize = 0;
    while (step < max_step) : (step += 1) {
        next_pair_map.clearRetainingCapacity();

        var it = pair_map.iterator();
        while (it.next()) |e| {
            const pair = e.key_ptr.*;
            const count = e.value_ptr.*;
            const insert = polymer.insertion_rules.get(pair).?;

            const a = [2]u8{ pair[0], insert };
            const b = [2]u8{ insert, pair[1] };

            try put_or_add([2]u8, usize, &next_pair_map, a, count);
            try put_or_add([2]u8, usize, &next_pair_map, b, count);
        }

        std.mem.swap(std.AutoHashMap([2]u8, usize), &pair_map, &next_pair_map);
    }

    var element_count = std.AutoHashMap(u8, usize).init(allocator);
    defer element_count.deinit();

    // Count the first char separately
    try put_or_add(u8, usize, &element_count, polymer.template[0], 1);

    {
        var it = pair_map.iterator();
        while (it.next()) |e| {
            try put_or_add(u8, usize, &element_count, e.key_ptr.*[1], e.value_ptr.*);
        }
    }

    var max_count: usize = 0;
    var min_count: usize = std.math.maxInt(usize);

    {
        var it = element_count.valueIterator();
        while (it.next()) |v| {
            if (v.* > max_count) max_count = v.*;
            if (v.* < min_count) min_count = v.*;
        }
    }

    return max_count - min_count;
}

fn part1(allocator: Allocator, polymer: Polymer) !usize {
    return count_min_max(allocator, polymer, 10);
}

fn part2(allocator: Allocator, polymer: Polymer) !usize {
    return count_min_max(allocator, polymer, 40);
}

test "polymer" {
    const input =
        \\NNCB
        \\
        \\CH -> B
        \\HH -> N
        \\CB -> H
        \\NH -> C
        \\HB -> C
        \\HC -> B
        \\HN -> C
        \\NN -> C
        \\BH -> H
        \\NC -> B
        \\NB -> B
        \\BN -> B
        \\BB -> N
        \\BC -> B
        \\CC -> N
        \\CN -> C
    ;

    const allocator = std.testing.allocator;

    var polymer = try Polymer.parse(allocator, input[0..]);
    defer polymer.deinit();

    try std.testing.expectEqual(@as(usize, 1588), try part1(allocator, polymer));
    try std.testing.expectEqual(@as(usize, 2188189693529), try part2(allocator, polymer));
}
