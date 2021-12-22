const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day22.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    const steps = try parse(allocator, data);
    defer allocator.free(steps);

    const cuboids = try solve(allocator, steps);
    defer cuboids.deinit();

    print("Part 1: {d}\n", .{try part1(allocator, cuboids)});
    print("Part 2: {d}\n", .{part2(cuboids)});
}

const Pos = struct {
    x: isize,
    y: isize,
    z: isize,
};

const Cuboid = struct {
    const Self = @This();

    start: Pos,
    end: Pos,

    fn inside_x(self: Self, p: Pos) bool {
        return self.start.x <= p.x and p.x <= self.end.x;
    }

    fn inside_y(self: Self, p: Pos) bool {
        return self.start.y <= p.y and p.y <= self.end.y;
    }

    fn inside_z(self: Self, p: Pos) bool {
        return self.start.z <= p.z and p.z <= self.end.z;
    }

    fn intersect(self: Self, other: Self) ?Self {
        const start_x = std.math.max(self.start.x, other.start.x);
        const end_x = std.math.min(self.end.x, other.end.x);

        const start_y = std.math.max(self.start.y, other.start.y);
        const end_y = std.math.min(self.end.y, other.end.y);

        const start_z = std.math.max(self.start.z, other.start.z);
        const end_z = std.math.min(self.end.z, other.end.z);

        if (start_x > end_x) return null;
        if (start_y > end_y) return null;
        if (start_z > end_z) return null;

        return Self{
            .start = Pos{
                .x = start_x,
                .y = start_y,
                .z = start_z,
            },
            .end = Pos{
                .x = end_x,
                .y = end_y,
                .z = end_z,
            },
        };
    }

    fn subtract(self: Self, other: Self, out: *std.ArrayList(Cuboid)) !void {
        var overlap_x = other.inside_x(self.start) or other.inside_x(self.end) or self.inside_x(other.start) or self.inside_x(other.end);
        var overlap_y = other.inside_y(self.start) or other.inside_y(self.end) or self.inside_y(other.start) or self.inside_y(other.end);
        var overlap_z = other.inside_z(self.start) or other.inside_z(self.end) or self.inside_z(other.start) or self.inside_z(other.end);

        // fast path
        if (!(overlap_x and overlap_y and overlap_z)) {
            try out.append(self);
            return;
        }

        // Intersect on x
        var center_start_x = self.start.x;
        var center_end_x = self.end.x;

        if (self.inside_x(other.start)) {
            center_start_x = other.start.x;

            if (self.start.x != other.start.x) {
                try out.append(Cuboid{
                    .start = self.start,
                    .end = Pos{
                        .x = other.start.x - 1,
                        .y = self.end.y,
                        .z = self.end.z,
                    },
                });
            }
        }

        if (self.inside_x(other.end)) {
            center_end_x = other.end.x;

            if (self.end.x != other.end.x) {
                try out.append(Cuboid{
                    .start = Pos{
                        .x = other.end.x + 1,
                        .y = self.start.y,
                        .z = self.start.z,
                    },
                    .end = self.end,
                });
            }
        }

        // Intersect on y
        var center_start_y = self.start.y;
        var center_end_y = self.end.y;

        if (self.inside_y(other.start)) {
            center_start_y = other.start.y;

            if (self.start.y != other.start.y) {
                try out.append(Cuboid{
                    .start = Pos{
                        .x = center_start_x,
                        .y = self.start.y,
                        .z = self.start.z,
                    },
                    .end = Pos{
                        .x = center_end_x,
                        .y = other.start.y - 1,
                        .z = self.end.z,
                    },
                });
            }
        }

        if (self.inside_y(other.end)) {
            center_end_y = other.end.y;

            if (self.end.y != other.end.y) {
                try out.append(Cuboid{
                    .start = Pos{
                        .x = center_start_x,
                        .y = other.end.y + 1,
                        .z = self.start.z,
                    },
                    .end = Pos{
                        .x = center_end_x,
                        .y = self.end.y,
                        .z = self.end.z,
                    },
                });
            }
        }

        // Intersect on z
        var center_start_z = self.start.z;
        var center_end_z = self.end.z;

        if (self.inside_z(other.start)) {
            center_start_z = other.start.z;

            if (self.start.z != other.start.z) {
                try out.append(Cuboid{
                    .start = Pos{
                        .x = center_start_x,
                        .y = center_start_y,
                        .z = self.start.z,
                    },
                    .end = Pos{
                        .x = center_end_x,
                        .y = center_end_y,
                        .z = other.start.z - 1,
                    },
                });
            }
        }

        if (self.inside_z(other.end)) {
            center_end_z = other.end.z;

            if (self.end.z != other.end.z) {
                try out.append(Cuboid{
                    .start = Pos{
                        .x = center_start_x,
                        .y = center_start_y,
                        .z = other.end.z + 1,
                    },
                    .end = Pos{
                        .x = center_end_x,
                        .y = center_end_y,
                        .z = self.end.z,
                    },
                });
            }
        }
    }

    fn count(self: Self) usize {
        const dx = @intCast(usize, 1 + self.end.x - self.start.x);
        const dy = @intCast(usize, 1 + self.end.y - self.start.y);
        const dz = @intCast(usize, 1 + self.end.z - self.start.z);
        return dx * dy * dz;
    }
};

const Step = struct {
    const Self = @This();

    turn_on: bool,
    cuboid: Cuboid,

    fn parse(input: []const u8) !Self {
        var it = std.mem.split(u8, input, " ");

        const turn_on_str = it.next().?;
        const turn_on =
            if (std.mem.eql(u8, turn_on_str, "on")) true else if (std.mem.eql(u8, turn_on_str, "off")) false else unreachable;

        const cuboid_str = it.next().?;
        var it_dim = std.mem.split(u8, cuboid_str, ",");
        var it_x = std.mem.split(u8, std.mem.trimLeft(u8, it_dim.next().?, "x="), "..");
        var it_y = std.mem.split(u8, std.mem.trimLeft(u8, it_dim.next().?, "y="), "..");
        var it_z = std.mem.split(u8, std.mem.trimLeft(u8, it_dim.next().?, "z="), "..");

        const start = Pos{
            .x = try std.fmt.parseInt(isize, it_x.next().?, 10),
            .y = try std.fmt.parseInt(isize, it_y.next().?, 10),
            .z = try std.fmt.parseInt(isize, it_z.next().?, 10),
        };
        const end = Pos{
            .x = try std.fmt.parseInt(isize, it_x.next().?, 10),
            .y = try std.fmt.parseInt(isize, it_y.next().?, 10),
            .z = try std.fmt.parseInt(isize, it_z.next().?, 10),
        };

        return Self{
            .turn_on = turn_on,
            .cuboid = Cuboid{
                .start = start,
                .end = end,
            },
        };
    }
};

const Cuboids = struct {
    const Self = @This();

    // invariant: No overlap in the cuboids
    cuboids: std.ArrayList(Cuboid),

    fn deinit(self: Self) void {
        self.cuboids.deinit();
    }

    fn init(allocator: Allocator) Self {
        return Self{
            .cuboids = std.ArrayList(Cuboid).init(allocator),
        };
    }

    fn apply_step(self: *Self, step: Step) !void {
        const allocator = self.cuboids.allocator;

        var new_cuboids = try std.ArrayList(Cuboid).initCapacity(allocator, self.cuboids.items.len);
        defer new_cuboids.deinit();

        for (self.cuboids.items) |*cuboid| {
            try cuboid.subtract(step.cuboid, &new_cuboids);
        }

        if (step.turn_on) {
            try new_cuboids.append(step.cuboid);
        }

        std.mem.swap(std.ArrayList(Cuboid), &self.cuboids, &new_cuboids);
    }

    fn count(self: Self) usize {
        var out: usize = 0;
        for (self.cuboids.items) |cuboid| {
            out += cuboid.count();
        }
        return out;
    }
};

fn parse(allocator: Allocator, input: []const u8) ![]Step {
    var steps = std.ArrayList(Step).init(allocator);
    var lines = std.mem.tokenize(u8, input, "\n");

    while (lines.next()) |line| {
        try steps.append(try Step.parse(line));
    }

    return steps.toOwnedSlice();
}

fn solve(allocator: Allocator, steps: []const Step) !Cuboids {
    var cuboids = Cuboids.init(allocator);
    errdefer cuboids.deinit();

    for (steps) |step| {
        try cuboids.apply_step(step);
    }

    return cuboids;
}

fn part1(allocator: Allocator, cuboids: Cuboids) !usize {
    const limit = Cuboid{
        .start = Pos{
            .x = -50,
            .y = -50,
            .z = -50,
        },
        .end = Pos{
            .x = 50,
            .y = 50,
            .z = 50,
        },
    };

    var limited = Cuboids.init(allocator);
    defer limited.deinit();

    for (cuboids.cuboids.items) |cuboid| {
        if (cuboid.intersect(limit)) |intersection| {
            try limited.cuboids.append(intersection);
        }
    }

    return limited.count();
}

fn part2(cuboids: Cuboids) usize {
    return cuboids.count();
}

test "cuboid subtract (full)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = 3,
            .y = 3,
            .z = 3,
        },
        .end = Pos{
            .x = 6,
            .y = 6,
            .z = 6,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{
        Cuboid{
            .start = Pos{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 2,
                .y = 10,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 7,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 10,
                .y = 10,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 3,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 6,
                .y = 2,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 3,
                .y = 7,
                .z = 0,
            },
            .end = Pos{
                .x = 6,
                .y = 10,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 3,
                .y = 3,
                .z = 0,
            },
            .end = Pos{
                .x = 6,
                .y = 6,
                .z = 2,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 3,
                .y = 3,
                .z = 7,
            },
            .end = Pos{
                .x = 6,
                .y = 6,
                .z = 10,
            },
        },
    };

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid subtract (gone)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = -5,
            .y = -5,
            .z = -5,
        },
        .end = Pos{
            .x = 15,
            .y = 15,
            .z = 15,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{};

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid subtract (none)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = -5,
            .y = -5,
            .z = -5,
        },
        .end = Pos{
            .x = -2,
            .y = -2,
            .z = -2,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{
        Cuboid{
            .start = Pos{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 10,
                .y = 10,
                .z = 10,
            },
        },
    };

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid subtract (none / 1-dim overlap)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = 3,
            .y = -5,
            .z = -5,
        },
        .end = Pos{
            .x = 6,
            .y = -2,
            .z = -2,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{a};

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid subtract (partial 1-dim)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = -2,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 2,
            .y = 20,
            .z = 20,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{
        Cuboid{
            .start = Pos{
                .x = 3,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 10,
                .y = 10,
                .z = 10,
            },
        },
    };

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid subtract (partial 2-dim)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = 8,
            .y = 8,
            .z = 0,
        },
        .end = Pos{
            .x = 20,
            .y = 20,
            .z = 20,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{
        Cuboid{
            .start = Pos{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 7,
                .y = 10,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 8,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 10,
                .y = 7,
                .z = 10,
            },
        },
    };

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid subtract (partial 3-dim)" {
    const a = Cuboid{
        .start = Pos{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .end = Pos{
            .x = 10,
            .y = 10,
            .z = 10,
        },
    };

    const b = Cuboid{
        .start = Pos{
            .x = 8,
            .y = 8,
            .z = 8,
        },
        .end = Pos{
            .x = 20,
            .y = 20,
            .z = 20,
        },
    };

    const allocator = std.testing.allocator;

    var out = try a.subtract(b, allocator);
    defer allocator.free(out);

    const expected = [_]Cuboid{
        Cuboid{
            .start = Pos{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 7,
                .y = 10,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 8,
                .y = 0,
                .z = 0,
            },
            .end = Pos{
                .x = 10,
                .y = 7,
                .z = 10,
            },
        },
        Cuboid{
            .start = Pos{
                .x = 8,
                .y = 8,
                .z = 0,
            },
            .end = Pos{
                .x = 10,
                .y = 10,
                .z = 7,
            },
        },
    };

    try std.testing.expectEqualSlices(Cuboid, &expected, out);
}

test "cuboid simple" {
    const input =
        \\on x=10..12,y=10..12,z=10..12
        \\on x=11..13,y=11..13,z=11..13
        \\off x=9..11,y=9..11,z=9..11
        \\on x=10..10,y=10..10,z=10..10
    ;

    const allocator = std.testing.allocator;

    const steps = try parse(allocator, input);
    defer allocator.free(steps);

    try std.testing.expectEqual(@as(usize, 39), try part1(allocator, steps));
}

test "cuboid" {
    const input =
        \\on x=-20..26,y=-36..17,z=-47..7
        \\on x=-20..33,y=-21..23,z=-26..28
        \\on x=-22..28,y=-29..23,z=-38..16
        \\on x=-46..7,y=-6..46,z=-50..-1
        \\on x=-49..1,y=-3..46,z=-24..28
        \\on x=2..47,y=-22..22,z=-23..27
        \\on x=-27..23,y=-28..26,z=-21..29
        \\on x=-39..5,y=-6..47,z=-3..44
        \\on x=-30..21,y=-8..43,z=-13..34
        \\on x=-22..26,y=-27..20,z=-29..19
        \\off x=-48..-32,y=26..41,z=-47..-37
        \\on x=-12..35,y=6..50,z=-50..-2
        \\off x=-48..-32,y=-32..-16,z=-15..-5
        \\on x=-18..26,y=-33..15,z=-7..46
        \\off x=-40..-22,y=-38..-28,z=23..41
        \\on x=-16..35,y=-41..10,z=-47..6
        \\off x=-32..-23,y=11..30,z=-14..3
        \\on x=-49..-5,y=-3..45,z=-29..18
        \\off x=18..30,y=-20..-8,z=-3..13
        \\on x=-41..9,y=-7..43,z=-33..15
        \\on x=-54112..-39298,y=-85059..-49293,z=-27449..7877
        \\on x=967..23432,y=45373..81175,z=27513..53682
    ;

    const allocator = std.testing.allocator;

    const steps = try parse(allocator, input);
    defer allocator.free(steps);

    try std.testing.expectEqual(@as(usize, 590784), try part1(allocator, steps));
}
