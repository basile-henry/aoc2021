const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day08.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    const segments = try parse(allocator, data[0..]);
    defer segments.deinit();

    print("Part 1: {d}\n", .{part1(segments.items)});
    print("Part 2: {d}\n", .{part2(segments.items)});
}

const Segment = struct {
    unique_signals: [10][]const u8,
    output: [4][]const u8,
};

fn parse(allocator: *Allocator, input: []const u8) !std.ArrayList(Segment) {
    var out = std.ArrayList(Segment).init(allocator);

    var lines = std.mem.tokenize(input, "\n");

    while (lines.next()) |line| {
        var segment: Segment = undefined;
        var parts = std.mem.split(line, " | ");

        var unique_signals = std.mem.tokenize(parts.next().?, " ");

        for (segment.unique_signals) |*signal| {
            signal.* = unique_signals.next().?;
        }

        var output = std.mem.tokenize(parts.next().?, " ");

        for (segment.output) |*o| {
            o.* = output.next().?;
        }

        try out.append(segment);
    }

    return out;
}

fn part1(segments: []const Segment) usize {
    var count: usize = 0;

    for (segments) |segment| {
        for (segment.output) |output| {
            const l = output.len;
            const digit_1 = l == 2;
            const digit_4 = l == 4;
            const digit_7 = l == 3;
            const digit_8 = l == 7;

            if (digit_1 or digit_4 or digit_7 or digit_8) count += 1;
        }
    }

    return count;
}

fn part2(segments: []const Segment) usize {
    var sum: usize = 0;

    for (segments) |segment| {
        sum += solve(segment);
    }

    return sum;
}

const BitSet = std.bit_set.IntegerBitSet(7);

fn idx(c: u8) usize {
    return @as(usize, c - 'a');
}

fn digit(n: usize) BitSet {
    var out = BitSet.initEmpty();

    switch (n) {
        0 => {
            out.set(idx('a'));
            out.set(idx('b'));
            out.set(idx('c'));
            out.set(idx('e'));
            out.set(idx('f'));
            out.set(idx('g'));
        },
        1 => {
            out.set(idx('c'));
            out.set(idx('f'));
        },
        2 => {
            out.set(idx('a'));
            out.set(idx('c'));
            out.set(idx('d'));
            out.set(idx('e'));
            out.set(idx('g'));
        },
        3 => {
            out.set(idx('a'));
            out.set(idx('c'));
            out.set(idx('d'));
            out.set(idx('f'));
            out.set(idx('g'));
        },
        4 => {
            out.set(idx('b'));
            out.set(idx('c'));
            out.set(idx('d'));
            out.set(idx('f'));
        },
        5 => {
            out.set(idx('a'));
            out.set(idx('b'));
            out.set(idx('d'));
            out.set(idx('f'));
            out.set(idx('g'));
        },
        6 => {
            out.set(idx('a'));
            out.set(idx('b'));
            out.set(idx('d'));
            out.set(idx('e'));
            out.set(idx('f'));
            out.set(idx('g'));
        },
        7 => {
            out.set(idx('a'));
            out.set(idx('c'));
            out.set(idx('f'));
        },
        8 => {
            out.set(idx('a'));
            out.set(idx('b'));
            out.set(idx('c'));
            out.set(idx('d'));
            out.set(idx('e'));
            out.set(idx('f'));
            out.set(idx('g'));
        },
        9 => {
            out.set(idx('a'));
            out.set(idx('b'));
            out.set(idx('c'));
            out.set(idx('d'));
            out.set(idx('f'));
            out.set(idx('g'));
        },
        else => @panic("unreachable"),
    }

    return out;
}

fn get_possibilities(signal: []const u8) BitSet {
    var possibilities = BitSet.initEmpty();

    switch (signal.len) {
        2 => {
            possibilities.setUnion(digit(1));
        },
        3 => {
            possibilities.setUnion(digit(7));
        },
        4 => {
            possibilities.setUnion(digit(4));
        },
        5 => {
            possibilities.setUnion(digit(2));
            possibilities.setUnion(digit(3));
            possibilities.setUnion(digit(5));
        },
        6 => {
            possibilities.setUnion(digit(0));
            possibilities.setUnion(digit(6));
            possibilities.setUnion(digit(9));
        },
        7 => {
            possibilities.setUnion(digit(8));
        },
        else => @panic("Invalid input"),
    }

    return possibilities;
}

fn decode(input: []const u8, mapping: [7]usize) ?usize {
    var bit_set = BitSet.initEmpty();

    for (input) |c| {
        bit_set.set(mapping[idx(c)]);
    }

    var d: usize = 0;
    while (d < 10) : (d += 1) {
        if (bit_set.mask == digit(d).mask) return d;
    }

    return null;
}

fn search(mapping: [7]?usize, possibilities: [7]BitSet, segment: Segment) ?[7]usize {
    var out: [7]usize = undefined;
    var next: usize = 0;

    for (mapping) |mo, i| {
        if (mo) |m| {
            out[i] = m;
            next = i + 1;
        } else {
            break;
        }
    }

    // Done
    if (next == 7) return out;

    var it = possibilities[next].iterator(.{});
    while (it.next()) |n| {
        var already_used = false;
        for (out[0..next]) |x| {
            if (x == n) {
                already_used = true;
                break;
            }
        }

        if (!already_used) {
            var rec_mapping: [7]?usize = undefined;
            for (rec_mapping) |*r, i| {
                if (i < next) {
                    r.* = out[i];
                } else if (i == next) {
                    r.* = n;
                } else {
                    r.* = mapping[i];
                }
            }

            if (search(rec_mapping, possibilities, segment)) |result| {
                var all_valid = true;

                for (segment.unique_signals) |signal| {
                    if (decode(signal, result) == null) {
                        all_valid = false;
                        break;
                    }
                }

                for (segment.output) |output| {
                    if (decode(output, result) == null) {
                        all_valid = false;
                        break;
                    }
                }

                if (all_valid) return result;
            }
        }
    }

    return null;
}

fn solve(segment: Segment) usize {

    // For each wire, what locations are possible
    var possibilities = [_]BitSet{BitSet.initFull()} ** 7;

    for (segment.unique_signals) |signal| {
        const ps = get_possibilities(signal);
        for (signal) |c| {
            possibilities[idx(c)].setIntersection(ps);
        }
    }

    for (segment.output) |output| {
        const ps = get_possibilities(output);
        for (output) |c| {
            possibilities[idx(c)].setIntersection(ps);
        }
    }

    const mapping = search([_]?usize{null} ** 7, possibilities, segment).?;

    var out: usize = 0;

    for (segment.output) |o| {
        out *= 10;
        out += decode(o, mapping).?;
    }

    return out;
}

test "7-segments" {
    const input =
        \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
        \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
        \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
        \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
        \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
        \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
        \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
        \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
        \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
        \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce
    ;

    const allocator = std.testing.allocator;

    const segments = try parse(allocator, input[0..]);
    defer segments.deinit();

    try std.testing.expectEqual(@as(usize, 26), part1(segments.items));
    try std.testing.expectEqual(@as(usize, 61229), part2(segments.items));
}
