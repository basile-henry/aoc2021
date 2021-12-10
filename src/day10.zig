const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day10.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    print("Part 1: {d}\n", .{try part1(allocator, data[0..])});
    print("Part 2: {d}\n", .{try part2(allocator, data[0..])});
}

fn part1(allocator: *Allocator, input: []const u8) !usize {
    var lines = std.mem.tokenize(input, "\n");

    var stack = std.ArrayList(u8).init(allocator);
    defer stack.deinit();

    var score: usize = 0;
    while (lines.next()) |line| {
        const result = try matching(line, &stack);

        switch (result) {
            .corrupted => |c| {
                switch (c) {
                    ')' => score += 3,
                    ']' => score += 57,
                    '}' => score += 1197,
                    '>' => score += 25137,
                    else => unreachable,
                }
            },
            else => {},
        }
    }

    return score;
}

fn part2(allocator: *Allocator, input: []const u8) !usize {
    var lines = std.mem.tokenize(input, "\n");

    var stack = std.ArrayList(u8).init(allocator);
    defer stack.deinit();

    var scores = std.ArrayList(usize).init(allocator);
    defer scores.deinit();

    while (lines.next()) |line| {
        const result = try matching(line, &stack);

        switch (result) {
            .incomplete => {
                var score: usize = 0;

                while (stack.popOrNull()) |c| {
                    score *= 5;
                    switch (c) {
                        ')' => score += 1,
                        ']' => score += 2,
                        '}' => score += 3,
                        '>' => score += 4,
                        else => unreachable,
                    }
                }

                try scores.append(score);
            },
            else => {},
        }
    }

    std.sort.sort(usize, scores.items, {}, comptime std.sort.asc(usize));

    return scores.items[scores.items.len / 2];
}

const Result = union(enum) {
    corrupted: u8,
    incomplete,
    success,
};

fn matching(line: []const u8, stack: *std.ArrayList(u8)) !Result {
    stack.clearRetainingCapacity();

    for (line) |c| {
        switch (c) {
            '(' => try stack.append(')'),
            '[' => try stack.append(']'),
            '{' => try stack.append('}'),
            '<' => try stack.append('>'),
            else => {
                const expected = stack.popOrNull();

                if (expected) |e| {
                    if (c != e) {
                        return Result{ .corrupted = c };
                    }
                } else {
                    return Result{ .corrupted = c };
                }
            },
        }
    }

    if (stack.items.len == 0) {
        return Result.success;
    } else {
        return Result.incomplete;
    }
}

test "matching" {
    const input =
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
    ;

    const allocator = std.testing.allocator;

    try std.testing.expectEqual(@as(usize, 26397), try part1(allocator, input[0..]));
    try std.testing.expectEqual(@as(usize, 288957), try part2(allocator, input[0..]));
}
