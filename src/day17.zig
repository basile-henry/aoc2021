const std = @import("std");
const print = std.debug.print;

const data = @embedFile("../inputs/day17.txt");

pub fn main() anyerror!void {
    const target_area = try parse(data);

    print("Part 1: {d}\n", .{part1(target_area)});
    print("Part 2: {d}\n", .{part2(target_area)});
}

const V = struct {
    x: isize,
    y: isize,
};

const Area = struct {
    start_x: isize,
    end_x: isize,
    start_y: isize,
    end_y: isize,
};

fn parse(input: []const u8) !Area {
    var str = std.mem.trimLeft(u8, input, "target area: x=");
    str = std.mem.trimRight(u8, str, "\n");
    var it = std.mem.split(u8, str, ", y=");

    var it_x = std.mem.split(u8, it.next().?, "..");
    const start_x = try std.fmt.parseInt(isize, it_x.next().?, 10);
    const end_x = try std.fmt.parseInt(isize, it_x.next().?, 10);

    var it_y = std.mem.split(u8, it.next().?, "..");
    const start_y = try std.fmt.parseInt(isize, it_y.next().?, 10);
    const end_y = try std.fmt.parseInt(isize, it_y.next().?, 10);

    return Area{
        .start_x = start_x,
        .end_x = end_x,
        .start_y = start_y,
        .end_y = end_y,
    };
}

inline fn inside(pos: V, target: Area) bool {
    const inside_x = target.start_x <= pos.x and pos.x <= target.end_x;
    const inside_y = target.start_y <= pos.y and pos.y <= target.end_y;
    return inside_x and inside_y;
}

const Probe = struct {
    const Self = @This();

    pos: V,
    vel: V,

    fn step(self: *Self) void {
        self.pos.x += self.vel.x;
        self.pos.y += self.vel.y;

        if (self.vel.x > 0) {
            self.vel.x -= 1;
        } else if (self.vel.x < 0) {
            self.vel.x += 1;
        }

        self.vel.y -= 1;
    }
};

fn part1(target: Area) usize {
    var highest_attempt: isize = 0;

    var vy: isize = 0;

    next_probe: while (true) : (vy += 1) {
        // we don't really care about x, assume there is a way to pick an x so
        // that the target can be reached with an x velocity of 0
        var probe = Probe{
            .pos = V{ .x = target.start_x, .y = 0 },
            .vel = V{ .x = 0, .y = vy },
        };

        var highest: isize = 0;
        var step_count: usize = 0;

        var step_at_zero_altitude: usize = 0;

        while (true) {
            if (inside(probe.pos, target)) {
                highest_attempt = std.math.max(highest_attempt, highest);
                break;
            } else if (probe.pos.y < target.start_y) {
                // too low y
                if (step_at_zero_altitude == step_count - 1) {
                    break :next_probe;
                }
                break;
            }

            highest = std.math.max(highest, probe.pos.y);

            if (probe.pos.y == 0 and probe.vel.y < 0) {
                step_at_zero_altitude = step_count;
            }

            probe.step();
            step_count += 1;
        }
    }

    return @intCast(usize, highest_attempt);
}

fn part2(target: Area) usize {
    var inside_count: usize = 0;

    var vx: isize = 0;
    while (vx <= target.end_x) : (vx += 1) {
        var vy: isize = target.start_y;

        next_probe: while (true) : (vy += 1) {
            var probe = Probe{
                .pos = V{ .x = 0, .y = 0 },
                .vel = V{ .x = vx, .y = vy },
            };

            var step_count: usize = 0;

            var step_at_zero_altitude: usize = 0;

            while (true) {
                if (inside(probe.pos, target)) {
                    inside_count += 1;
                    break;
                } else if (probe.pos.x > target.end_x) {
                    // too far x
                    break :next_probe;
                } else if (probe.pos.y < target.start_y) {
                    // too low y
                    if (step_at_zero_altitude == step_count - 1) {
                        break :next_probe;
                    }
                    break;
                }

                if (probe.pos.y == 0 and probe.vel.y < 0) {
                    step_at_zero_altitude = step_count;
                }

                probe.step();
                step_count += 1;
            }
        }
    }

    return inside_count;
}

test "probe shooting" {
    const input = "target area: x=20..30, y=-10..-5";

    const target_area = try parse(input);

    try std.testing.expectEqual(@as(usize, 45), part1(target_area));
    try std.testing.expectEqual(@as(usize, 112), part2(target_area));
}
