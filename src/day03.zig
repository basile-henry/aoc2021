const std = @import("std");
const print = std.debug.print;

const data = @embedFile("../inputs/day03.txt");

const BIT_COUNT = 12;

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    // Part 1
    var line_count: usize = 0;
    var ones_count: [BIT_COUNT]usize = undefined;

    std.mem.set(usize, ones_count[0..], 0);

    var inputs = std.ArrayList(usize).init(gpa);
    defer inputs.deinit();

    {
        var lines = std.mem.tokenize(data, "\n");
        while (lines.next()) |line| {
            var input: usize = 0;
            for (line) |c, i| {
                input <<= 1;
                if (c == '1') {
                    ones_count[i] += 1;
                    input += 1;
                }
            }

            try inputs.append(input);

            line_count += 1;
        }
    }

    var gamma: usize = 0;
    var epsilon: usize = 0;

    for (ones_count) |o| {
        gamma <<= 1;
        epsilon <<= 1;
        if (o >= line_count / 2) {
            gamma += 1;
        } else {
            epsilon += 1;
        }
    }

    print("Part 1: {}\n", .{gamma * epsilon});

    // Part 2
    var oxy_candidates = std.ArrayList(usize).init(gpa);
    defer oxy_candidates.deinit();

    try oxy_candidates.insertSlice(0, inputs.items);

    var co2_candidates = std.ArrayList(usize).init(gpa);
    defer co2_candidates.deinit();

    try co2_candidates.insertSlice(0, inputs.items);

    var buffer = std.ArrayList(usize).init(gpa);
    defer buffer.deinit();

    var bit: usize = 0;
    while (bit < ones_count.len) : (bit += 1) {
        if (oxy_candidates.items.len > 1) {
            try rating(true, oxy_candidates.items, BIT_COUNT, bit, &buffer);
            std.mem.swap(std.ArrayList(usize), &oxy_candidates, &buffer);
        }

        if (co2_candidates.items.len > 1) {
            try rating(false, co2_candidates.items, BIT_COUNT, bit, &buffer);
            std.mem.swap(std.ArrayList(usize), &co2_candidates, &buffer);
        }
    }

    const oxy: ?usize = oxy_candidates.popOrNull();
    const co2: ?usize = co2_candidates.popOrNull();

    print("Part 2: {}\n", .{oxy.? * co2.?});
}

fn rating(most: bool, inputs: []usize, bit_count: usize, bit: usize, out: *std.ArrayList(usize)) !void {
    out.clearRetainingCapacity();

    const bi = @intCast(u6, bit_count - bit - 1);
    const bit_mask = @as(usize, 1) << bi;

    var ones_count: usize = 0;
    for (inputs) |n| {
        if (n & bit_mask > 0) {
            ones_count += 1;
        }
    }

    var one = @intToFloat(f32, ones_count) >= @intToFloat(f32, inputs.len) / 2;
    if (!most) {
        one = !one;
    }

    for (inputs) |n| {
        const one_set = n & bit_mask > 0;

        if (one == one_set) {
            try out.append(n);
        }
    }

    if (out.items.len == 0) {
        try out.append(inputs[inputs.len - 1]);
    }
}
