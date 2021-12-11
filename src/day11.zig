const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day11.txt");

pub fn main_with_allocator(allocator: *Allocator) anyerror!void {
    _ = allocator;

    return main();
}

pub fn main() anyerror!void {
    const grid = parse(data[0..]).?;

    print("Part 1: {d}\n", .{part1(grid)});
    print("Part 2: {d}\n", .{part2(grid)});
}

const Size = 10;
const Octopus = struct {
    energy: u4,
    flash: bool,
};
const Grid = [Size][Size]Octopus;

fn parse(input: []const u8) ?Grid {
    var lines = std.mem.tokenize(input, "\n");
    var out: Grid = undefined;

    var row: usize = 0;
    while (lines.next()) |line| {
        if (line.len != Size) return null;

        for (line) |c, col| {
            out[row][col].energy = @intCast(u4, c - '0');
            out[row][col].flash = false;
        }

        row += 1;
    }

    if (row != Size) return null;

    return out;
}

fn propagate(x: usize, y: usize, grid: *Grid) void {
    const from_y: usize = if (y == 0) y else y - 1;
    const to_y: usize = if (y == grid.len - 1) y else y + 1;

    const from_x: usize = if (x == 0) x else x - 1;
    const to_x: usize = if (x == grid[0].len - 1) x else x + 1;

    var i = from_y;
    while (i <= to_y) : (i += 1) {
        var j = from_x;
        while (j <= to_x) : (j += 1) {
            if (grid[i][j].energy <= 9) {
               grid[i][j].energy += 1;

               if (grid[i][j].energy > 9) {
                   grid[i][j].flash = true;
                   propagate(j, i, grid);
               }
            }
        }
    }
}

fn run_step(grid: *Grid) usize {
    for (grid) |*row| {
        for (row.*) |*c| {
            c.energy += 1;
        }
    }

    for (grid) |row, y| {
        for (row) |c, x| {
            if (c.energy > 9 and c.flash == false) propagate(x, y, grid);
        }
    }

    var flashes: usize = 0;

    for (grid) |*row| {
        for (row.*) |*c| {
            if (c.energy > 9) {
                flashes += 1;
                c.energy = 0;
                c.flash = false;
            }
        }
    }

    return flashes;
}

fn dump(grid: Grid) void {
    for (grid) |row| {
        for (row) |c| {
            if (c.energy == 0) {
                print("\x1B[31m0\x1B[0m", .{});
            } else {
                print("{d}", .{c.energy});
            }
        }
        print("\n", .{});
    }
}

fn part1(const_grid: Grid) usize {
    var grid = const_grid;
    var flashes: usize = 0;

    var step: usize = 0;
    while (step < 100) : (step += 1) {
        flashes += run_step(&grid);
    }

    return flashes;
}

fn all_in_sync(grid: Grid) bool {
    for (grid) |row| {
        for (row) |c| {
            if (c.energy != 0) return false;
        }
    }
    return true;
}

fn part2(const_grid: Grid) usize {
    var grid = const_grid;

    var step: usize = 0;
    while (!all_in_sync(grid)) : (step += 1) {
        _ = run_step(&grid);
    }

    return step;
}

test "dumbo octopuses" {
    const input =
        \\5483143223
        \\2745854711
        \\5264556173
        \\6141336146
        \\6357385478
        \\4167524645
        \\2176841721
        \\6882881134
        \\4846848554
        \\5283751526
    ;

    const allocator = std.testing.allocator;

    const grid = parse(input[0..]).?;

    try std.testing.expectEqual(@as(usize, 1656), part1(grid));
    // try std.testing.expectEqual(@as(usize, 288957), try part2(allocator, input[0..]));
}
