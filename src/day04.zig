const std = @import("std");
const Allocator = std.mem.Allocator;
const BitSet = std.bit_set.IntegerBitSet;
const print = std.debug.print;

const data = @embedFile("../inputs/day04.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = &gpa_impl.allocator;

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    const bingo = try Bingo.parse(allocator, data[0..]);
    defer bingo.deinit();

    const res = try solve(allocator, bingo);

    print("Part 1: {d}\n", .{res.part1});
    print("Part 2: {d}\n", .{res.part2});
}

const Solve = struct { part1: usize, part2: usize };

fn solve(allocator: *Allocator, bingo: Bingo) !Solve {
    var winner_score: ?usize = null;
    var winning_number: ?usize = null;

    var last_winner_score: ?usize = null;
    var last_winning_number: ?usize = null;

    var has_won = try std.bit_set.DynamicBitSet.initEmpty(bingo.boards.len, allocator);
    defer has_won.deinit();

    for (bingo.numbers) |n| {
        for (bingo.boards) |*board, board_idx| {
            board.play(n);

            if (!has_won.isSet(board_idx) and board.win()) {
                has_won.set(board_idx);

                if (has_won.count() == 1) {
                    winner_score = board.score();
                    winning_number = @intCast(usize, n);
                } else if (has_won.count() == bingo.boards.len) {
                    last_winner_score = board.score();
                    last_winning_number = @intCast(usize, n);
                }
            }
        }
    }

    return Solve{
        .part1 = winner_score.? * winning_number.?,
        .part2 = last_winner_score.? * last_winning_number.?,
    };
}

const Board = struct {
    const Self = @This();

    grid: [5][5]u8,
    seen_rows: [5]BitSet(5),
    seen_cols: [5]BitSet(5),

    fn parse(lines: *std.mem.TokenIterator) !Self {
        var grid: [5][5]u8 = undefined;
        var initBitSet: [5]BitSet(5) = undefined;

        var row: usize = 0;
        while (row < 5) : (row += 1) {
            var numbers = std.mem.tokenize(lines.next().?, " ");
            initBitSet[row] = BitSet(5).initEmpty();

            var col: usize = 0;
            while (col < 5) : (col += 1) {
                const n: u8 = try std.fmt.parseInt(u8, numbers.next().?, 10);
                grid[row][col] = n;
            }
        }

        return Board{
            .grid = grid,
            .seen_rows = initBitSet,
            .seen_cols = initBitSet,
        };
    }

    fn play(self: *Self, x: u8) void {
        for (self.grid) |row, row_idx| {
            for (row) |cell, col_idx| {
                if (cell == x) {
                    self.seen_rows[row_idx].set(col_idx);
                    self.seen_cols[col_idx].set(row_idx);
                }
            }
        }
    }

    fn win(self: *Self) bool {
        for (self.grid) |_, idx| {
            if (self.seen_rows[idx].count() == 5 or self.seen_cols[idx].count() == 5) {
                return true;
            }
        }

        return false;
    }

    // Sum of all the unseen numbers
    fn score(self: *Self) usize {
        var out: usize = 0;

        for (self.grid) |row, row_idx| {
            for (row) |cell, col_idx| {
                if (!self.seen_rows[row_idx].isSet(col_idx)) {
                    out += cell;
                }
            }
        }

        return out;
    }
};

const Bingo = struct {
    const Self = @This();

    allocator: *Allocator,
    numbers: []u8,
    boards: []Board,

    fn deinit(self: Self) void {
        self.allocator.free(self.numbers);
        self.allocator.free(self.boards);
    }

    fn parse(allocator: *Allocator, input: []const u8) !Self {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        var lines = std.mem.tokenize(input, "\n");

        const numbers_line = lines.next().?;
        var numbers_str = std.mem.tokenize(numbers_line, ",");
        var numbers = std.ArrayList(u8).init(allocator);

        while (numbers_str.next()) |n_str| {
            const n = try std.fmt.parseInt(u8, n_str, 10);
            try numbers.append(n);
        }

        var boards = std.ArrayList(Board).init(allocator);

        while (lines.rest().len > 0) {
            const board = try Board.parse(&lines);
            try boards.append(board);
        }

        return Bingo{
            .allocator = allocator,
            .numbers = numbers.toOwnedSlice(),
            .boards = boards.toOwnedSlice(),
        };
    }
};

test "bingo" {
    const input =
        \\7,4,9,5,11,17,23,2,0,14,21,24,10,16,13,6,15,25,12,22,18,20,8,19,3,26,1
        \\
        \\22 13 17 11  0
        \\ 8  2 23  4 24
        \\21  9 14 16  7
        \\ 6 10  3 18  5
        \\ 1 12 20 15 19
        \\
        \\ 3 15  0  2 22
        \\ 9 18 13 17  5
        \\19  8  7 25 23
        \\20 11 10 24  4
        \\14 21 16 12  6
        \\
        \\14 21 17 24  4
        \\10 16 15  9 19
        \\18  8 23 26 20
        \\22 11 13  6  5
        \\ 2  0 12  3  7
    ;

    const allocator = std.testing.allocator;

    const bingo = try Bingo.parse(allocator, input[0..]);
    defer bingo.deinit();

    const res = try solve(allocator, bingo);

    try std.testing.expectEqual(@as(usize, 4512), res.part1);
    try std.testing.expectEqual(@as(usize, 1924), res.part2);
}
