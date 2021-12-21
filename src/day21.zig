const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day21.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    print("Part 1: {d}\n", .{try part1(data)});
    print("Part 2: {d}\n", .{try part2(allocator, data)});
}

const State = struct {
    const Self = @This();

    current_player: u1,

    p1: u4, // [0..9]
    p1_score: usize,

    p2: u4, // [0..9]
    p2_score: usize,

    fn parse(input: []const u8) !Self {
        var it = std.mem.tokenize(u8, input, "\n");

        const p1_str = std.mem.trimLeft(u8, it.next().?, "Player 1 starting position: ");
        const p1 = try std.fmt.parseInt(u4, p1_str, 10);

        const p2_str = std.mem.trimLeft(u8, it.next().?, "Player 2 starting position: ");
        const p2 = try std.fmt.parseInt(u4, p2_str, 10);

        return Self{
            .current_player = 0,
            .p1 = p1 - 1,
            .p1_score = 0,
            .p2 = p2 - 1,
            .p2_score = 0,
        };
    }

    fn step_deterministic(self: Self, rolls: [3]usize) Self {
        var out = self;

        const movement = rolls[0] + rolls[1] + rolls[2];

        switch (self.current_player) {
            0 => {
                out.p1 = @intCast(u4, (@as(usize, self.p1) + movement) % 10);
                out.p1_score += out.p1 + 1;
            },
            1 => {
                out.p2 = @intCast(u4, (@as(usize, self.p2) + movement) % 10);
                out.p2_score += out.p2 + 1;
            },
        }

        out.current_player = ~self.current_player;

        return out;
    }

    fn step(self: *Self, die: *Die) void {
        self.* = step_deterministic(self.*, [3]usize{ die.roll(), die.roll(), die.roll() });
    }

    fn check_win(self: Self, score: usize) ?u1 {
        const last_player = ~self.current_player;

        switch (last_player) {
            0 => if (self.p1_score >= score) return last_player,
            1 => if (self.p2_score >= score) return last_player,
        }

        return null;
    }

    fn until_win(self: *Self, die: *Die, score: usize) u1 {
        while (true) {
            self.step(die);

            if (self.check_win(score)) |winner| return winner;
        }
    }
};

const Die = struct {
    const Self = @This();

    up_to: u7,
    state: u7,
    count: usize,

    fn init(up_to: u7) Self {
        return Self{
            .up_to = up_to,
            .state = up_to,
            .count = 0,
        };
    }

    fn roll(self: *Self) usize {
        self.count += 1;
        self.state += 1;
        if (self.state > self.up_to) self.state = 1;

        return @as(usize, self.state);
    }
};

fn part1(input: []const u8) !usize {
    var state = try State.parse(input);
    var die = Die.init(100);

    const winner = state.until_win(&die, 1000);

    switch (~winner) {
        0 => return state.p1_score * die.count,
        1 => return state.p2_score * die.count,
    }
}

const Map = std.AutoHashMap(State, u64);

fn put_or_add(hm: *Map, key: State, val: u64) !void {
    if (hm.getPtr(key)) |p| {
        p.* += val;
    } else {
        try hm.put(key, val);
    }
}

fn part2(allocator: Allocator, input: []const u8) !u64 {
    const state = try State.parse(input);

    var states = Map.init(allocator);
    defer states.deinit();

    try states.put(state, 1);

    var temp = Map.init(allocator);
    defer temp.deinit();

    var p1_win: u64 = 0;
    var p2_win: u64 = 0;

    while (states.count() > 0) {
        temp.clearRetainingCapacity();

        var it = states.iterator();
        while (it.next()) |e| {
            const current = e.key_ptr.*;

            var step_universe: usize = 0;
            while (step_universe < 3 * 3 * 3) : (step_universe += 1) {
                const roll = [3]usize{
                    step_universe % 3 + 1,
                    (step_universe / 3) % 3 + 1,
                    (step_universe / 3 / 3) % 3 + 1,
                };

                const next = current.step_deterministic(roll);

                if (next.check_win(21)) |winner| {
                    switch (winner) {
                        0 => p1_win += e.value_ptr.*,
                        1 => p2_win += e.value_ptr.*,
                    }
                } else {
                    try put_or_add(&temp, next, e.value_ptr.*);
                }
            }
        }

        std.mem.swap(Map, &states, &temp);
    }

    return std.math.max(p1_win, p2_win);
}

test "dice" {
    const input =
        \\Player 1 starting position: 4
        \\Player 2 starting position: 8
    ;

    const allocator = std.testing.allocator;

    try std.testing.expectEqual(@as(usize, 739785), try part1(input));
    try std.testing.expectEqual(@as(u64, 444356092776315), try part2(allocator, input));
}
