const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day19.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    const scanners = try parse(allocator, data);
    defer {
        for (scanners.items) |*scanner| scanner.deinit();
        scanners.deinit();
    }

    try solve(allocator, scanners.items);

    print("Part 1: {d}\n", .{try part1(allocator, scanners.items)});
    print("Part 2: {d}\n", .{part2(scanners.items)});
}

const Pos = struct {
    const Self = @This();

    x: isize,
    y: isize,
    z: isize,

    fn zero() Self {
        return Pos{ .x = 0, .y = 0, .z = 0 };
    }

    fn eql(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    fn sqr_distance(self: Self, other: Self) isize {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;

        return dx * dx + dy * dy + dz * dz;
    }

    fn manhattan_distance(self: Self, other: Self) usize {
        const dx = abs(self.x - other.x);
        const dy = abs(self.y - other.y);
        const dz = abs(self.z - other.z);

        return dx + dy + dz;
    }

    fn rotate_z(self: Self, index: u2) Self {
        switch (index) {
            // initial
            0 => return self,
            // anti-clockwise 90
            1 => return Self{
                .x = -self.y,
                .y = self.x,
                .z = self.z,
            },
            // 180
            2 => return Self{
                .x = -self.x,
                .y = -self.y,
                .z = self.z,
            },
            // clockwise 90
            3 => return Self{
                .x = self.y,
                .y = -self.x,
                .z = self.z,
            },
        }
    }

    fn facing(self: Self, index: u3) Self {
        std.debug.assert(index < 6);

        switch (index) {
            // z-up
            0 => return self,
            // z-down
            1 => return Self{
                .x = -self.x,
                .y = self.y,
                .z = -self.z,
            },
            // x-up
            2 => return Self{
                .x = -self.z,
                .y = self.y,
                .z = self.x,
            },
            // x-down
            3 => return Self{
                .x = self.z,
                .y = self.y,
                .z = -self.x,
            },
            // y-up
            4 => return Self{
                .x = self.x,
                .y = -self.z,
                .z = self.y,
            },
            // y-down
            5 => return Self{
                .x = self.x,
                .y = self.z,
                .z = -self.y,
            },
            else => unreachable,
        }
    }

    fn direction(self: Self, index: u5) Self {
        std.debug.assert(index < 24);

        const rotate_index = @intCast(u2, (index & 0b00011) >> 0);
        const facing_index = @intCast(u3, (index & 0b11100) >> 2);

        return self.facing(facing_index).rotate_z(rotate_index);
    }

    fn translate(self: Self, from: Pos, to: Pos) Self {
        return Self{
            .x = self.x + (to.x - from.x),
            .y = self.y + (to.y - from.y),
            .z = self.z + (to.z - from.z),
        };
    }
};

const Scanner = struct {
    const Self = @This();
    const SqrDistanceMap = std.AutoHashMap(isize, std.AutoHashMap(usize, void));

    beacons: std.ArrayList(Pos),

    pos: ?Pos = null,
    direction: ?u5 = null,
    beacons_sqr_dist: ?SqrDistanceMap = null,

    fn deinit(self: *Self) void {
        self.beacons.deinit();

        if (self.beacons_sqr_dist) |*map| {
            var it = map.valueIterator();
            while (it.next()) |*v| v.*.deinit();
            map.deinit();
        }
    }

    fn init(allocator: Allocator) Self {
        return Scanner{
            .beacons = std.ArrayList(Pos).init(allocator),
        };
    }

    fn beacon_abs_pos(self: Self, idx: usize) Pos {
        return self.beacons.items[idx].direction(self.direction.?).translate(Pos.zero(), self.pos.?);
    }

    fn build_beacons_sqr_dist(self: *Self, allocator: Allocator) !void {
        var map = SqrDistanceMap.init(allocator);

        for (self.beacons.items) |from, from_idx| {
            if (from_idx == self.beacons.items.len - 1) continue;

            for (self.beacons.items[from_idx + 1 ..]) |to, i| {
                const to_idx = i + from_idx + 1;
                const sqr_dist = from.sqr_distance(to);

                if (map.getPtr(sqr_dist)) |p| {
                    try p.put(from_idx, .{});
                    try p.put(to_idx, .{});
                } else {
                    var idx_map = std.AutoHashMap(usize, void).init(allocator);
                    try idx_map.put(from_idx, .{});
                    try idx_map.put(to_idx, .{});
                    try map.put(sqr_dist, idx_map);
                }
            }
        }

        self.beacons_sqr_dist = map;
    }

    fn solve(self: *Self, allocator: Allocator, reference: Scanner) !bool {
        // Reference must have a known position
        std.debug.assert(reference.pos != null);
        std.debug.assert(reference.direction != null);

        std.debug.assert(reference.beacons_sqr_dist != null);
        std.debug.assert(self.beacons_sqr_dist != null);

        // Points whose distances match the reference
        var dist_match = std.AutoHashMap(usize, std.AutoHashMap(usize, void)).init(allocator);
        defer dist_match.deinit(); // Don't deinit values

        {
            var it = reference.beacons_sqr_dist.?.iterator();
            while (it.next()) |ref| {
                const dist = ref.key_ptr.*;

                if (self.beacons_sqr_dist.?.get(dist)) |idx_map| {
                    var self_idx_it = idx_map.keyIterator();
                    while (self_idx_it.next()) |idx| {
                        try dist_match.put(idx.*, ref.value_ptr.*);
                    }
                }
            }
        }

        if (dist_match.count() < 12) return false;

        var direction: u5 = 0;
        while (direction < 24) : (direction += 1) {
            // Attempt
            self.direction = direction;
            self.pos = Pos.zero();

            var it = dist_match.iterator();
            const anchor = it.next().?;
            var anchor_pos = self.beacon_abs_pos(anchor.key_ptr.*);

            var it_candidates = anchor.value_ptr.*.keyIterator();
            while (it_candidates.next()) |candidate_idx| {
                var candidate = reference.beacon_abs_pos(candidate_idx.*);

                // Adjust self.pos to attach the anchor to the candidate
                self.pos = Pos.zero().translate(anchor_pos, candidate);

                std.debug.assert(self.beacon_abs_pos(anchor.key_ptr.*).eql(candidate));

                var all_match = true;

                match_loop: while (it.next()) |match| {
                    var pos = self.beacon_abs_pos(match.key_ptr.*);

                    var it_match_ref = match.value_ptr.keyIterator();
                    while (it_match_ref.next()) |ref_idx| {
                        var ref_pos = reference.beacon_abs_pos(ref_idx.*);

                        if (pos.eql(ref_pos)) continue :match_loop;
                    }

                    all_match = false;
                    break;
                }

                if (all_match) return true;
            }
        }

        return false;
    }
};

fn parse(allocator: Allocator, input: []const u8) !std.ArrayList(Scanner) {
    var scanners = std.ArrayList(Scanner).init(allocator);
    errdefer scanners.deinit();

    var scanner_lines_it = std.mem.split(u8, input, "\n\n");

    while (scanner_lines_it.next()) |scanner_lines| {
        var scanner = Scanner.init(allocator);
        errdefer scanner.deinit();

        var lines = std.mem.tokenize(u8, scanner_lines, "\n");

        // Remove header
        _ = lines.next();

        while (lines.next()) |beacon_str| {
            var it = std.mem.split(u8, beacon_str, ",");

            const x = try std.fmt.parseInt(isize, it.next().?, 10);
            const y = try std.fmt.parseInt(isize, it.next().?, 10);
            const z = try std.fmt.parseInt(isize, it.next().?, 10);

            try scanner.beacons.append(Pos{
                .x = x,
                .y = y,
                .z = z,
            });
        }

        try scanner.build_beacons_sqr_dist(allocator);

        try scanners.append(scanner);
    }

    return scanners;
}

fn solve(allocator: Allocator, scanners: []Scanner) !void {
    // Setup the reference
    scanners[0].pos = Pos.zero();
    scanners[0].direction = 0;

    var solved = try std.ArrayList(usize).initCapacity(allocator, scanners.len);
    defer solved.deinit();

    var todo = try std.ArrayList(usize).initCapacity(allocator, scanners.len);
    defer todo.deinit();

    for (scanners) |_, i| {
        if (i == 0) {
            try solved.append(0);
        } else {
            try todo.append(i);
        }
    }

    while (todo.popOrNull()) |scanner_idx| {
        const scanner = &scanners[scanner_idx];
        var done = false;

        for (solved.items) |reference_idx| {
            const reference = scanners[reference_idx];

            if (try scanner.solve(allocator, reference)) {
                done = true;
                break;
            }
        }

        if (done) {
            try solved.append(scanner_idx);
        } else {
            try todo.insert(0, scanner_idx);
        }
    }
}

const Beacons = std.AutoHashMap(Pos, void);

fn beacon_map(allocator: Allocator, scanners: []Scanner) !Beacons {
    var beacons = std.AutoHashMap(Pos, void).init(allocator);
    errdefer beacons.deinit();

    for (scanners) |scanner| {
        for (scanner.beacons.items) |beacon| {
            const absolute_beacon = beacon.direction(scanner.direction.?).translate(Pos.zero(), scanner.pos.?);
            try beacons.put(absolute_beacon, .{});
        }
    }

    return beacons;
}

fn part1(allocator: Allocator, scanners: []Scanner) !usize {
    var beacons = try beacon_map(allocator, scanners);
    defer beacons.deinit();

    return beacons.count();
}

fn part2(scanners: []Scanner) usize {
    var max_dist: usize = 0;

    for (scanners) |a, i| {
        if (i == scanners.len - 1) continue;

        for (scanners[i + 1 ..]) |b| {
            max_dist = std.math.max(max_dist, a.pos.?.manhattan_distance(b.pos.?));
        }
    }

    return max_dist;
}

fn abs(a: isize) usize {
    if (a < 0) return @intCast(usize, -a);
    return @intCast(usize, a);
}

test "beacons" {
    const input =
        \\--- scanner 0 ---
        \\404,-588,-901
        \\528,-643,409
        \\-838,591,734
        \\390,-675,-793
        \\-537,-823,-458
        \\-485,-357,347
        \\-345,-311,381
        \\-661,-816,-575
        \\-876,649,763
        \\-618,-824,-621
        \\553,345,-567
        \\474,580,667
        \\-447,-329,318
        \\-584,868,-557
        \\544,-627,-890
        \\564,392,-477
        \\455,729,728
        \\-892,524,684
        \\-689,845,-530
        \\423,-701,434
        \\7,-33,-71
        \\630,319,-379
        \\443,580,662
        \\-789,900,-551
        \\459,-707,401
        \\
        \\--- scanner 1 ---
        \\686,422,578
        \\605,423,415
        \\515,917,-361
        \\-336,658,858
        \\95,138,22
        \\-476,619,847
        \\-340,-569,-846
        \\567,-361,727
        \\-460,603,-452
        \\669,-402,600
        \\729,430,532
        \\-500,-761,534
        \\-322,571,750
        \\-466,-666,-811
        \\-429,-592,574
        \\-355,545,-477
        \\703,-491,-529
        \\-328,-685,520
        \\413,935,-424
        \\-391,539,-444
        \\586,-435,557
        \\-364,-763,-893
        \\807,-499,-711
        \\755,-354,-619
        \\553,889,-390
        \\
        \\--- scanner 2 ---
        \\649,640,665
        \\682,-795,504
        \\-784,533,-524
        \\-644,584,-595
        \\-588,-843,648
        \\-30,6,44
        \\-674,560,763
        \\500,723,-460
        \\609,671,-379
        \\-555,-800,653
        \\-675,-892,-343
        \\697,-426,-610
        \\578,704,681
        \\493,664,-388
        \\-671,-858,530
        \\-667,343,800
        \\571,-461,-707
        \\-138,-166,112
        \\-889,563,-600
        \\646,-828,498
        \\640,759,510
        \\-630,509,768
        \\-681,-892,-333
        \\673,-379,-804
        \\-742,-814,-386
        \\577,-820,562
        \\
        \\--- scanner 3 ---
        \\-589,542,597
        \\605,-692,669
        \\-500,565,-823
        \\-660,373,557
        \\-458,-679,-417
        \\-488,449,543
        \\-626,468,-788
        \\338,-750,-386
        \\528,-832,-391
        \\562,-778,733
        \\-938,-730,414
        \\543,643,-506
        \\-524,371,-870
        \\407,773,750
        \\-104,29,83
        \\378,-903,-323
        \\-778,-728,485
        \\426,699,580
        \\-438,-605,-362
        \\-469,-447,-387
        \\509,732,623
        \\647,635,-688
        \\-868,-804,481
        \\614,-800,639
        \\595,780,-596
        \\
        \\--- scanner 4 ---
        \\727,592,562
        \\-293,-554,779
        \\441,611,-461
        \\-714,465,-776
        \\-743,427,-804
        \\-660,-479,-426
        \\832,-632,460
        \\927,-485,-438
        \\408,393,-506
        \\466,436,-512
        \\110,16,151
        \\-258,-428,682
        \\-393,719,612
        \\-211,-452,876
        \\808,-476,-593
        \\-575,615,604
        \\-485,667,467
        \\-680,325,-822
        \\-627,-443,-432
        \\872,-547,-609
        \\833,512,582
        \\807,604,487
        \\839,-516,451
        \\891,-625,532
        \\-652,-548,-490
        \\30,-46,-14
    ;

    const allocator = std.testing.allocator;

    const scanners = try parse(allocator, input);
    defer {
        for (scanners.items) |*scanner| scanner.deinit();
        scanners.deinit();
    }

    try solve(allocator, scanners.items);

    try std.testing.expectEqual(@as(usize, 79), try part1(allocator, scanners.items));
    try std.testing.expectEqual(@as(usize, 3621), part2(scanners.items));
}
