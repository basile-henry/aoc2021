const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const data = @embedFile("../inputs/day16.txt");

pub fn main() anyerror!void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    return main_with_allocator(gpa);
}

pub fn main_with_allocator(allocator: Allocator) anyerror!void {
    const packet = try Packet.parse_str(allocator, std.mem.trimRight(u8, data, "\n"));
    defer packet.deinit();

    print("Part 1: {d}\n", .{packet.version_sum()});
    print("Part 2: {d}\n", .{packet.value()});
}

const BitReader = std.io.BitReader(.Big, std.io.FixedBufferStream([]u8).Reader);

fn bit_offset(bit_reader: BitReader) usize {
    const byte_offset = bit_reader.forward_reader.context.pos;
    const extra_bits = 8 - @as(usize, bit_reader.bit_count);
    return byte_offset * 8 + extra_bits;
}

const Payload = union {
    literal_value: u64,
    operator: []Packet,
};

const PacketType = enum(u3) {
    sum = 0,
    product = 1,
    minimum = 2,
    maximum = 3,
    literal = 4,
    greater_than = 5,
    less_than = 6,
    equal_to = 7,
};

const Packet = struct {
    const Self = @This();

    allocator: Allocator,
    version: u3,
    id: PacketType,
    payload: Payload,

    fn deinit(self: Self) void {
        switch (self.id) {
            .literal => {},
            else => {
                for (self.payload.operator) |packet| {
                    packet.deinit();
                }

                self.allocator.free(self.payload.operator);
            },
        }
    }

    fn parse_str(allocator: Allocator, hex_input: []const u8) !Self {
        var input = try dehex(allocator, hex_input);
        defer allocator.free(input);

        var fixed_buf_reader = std.io.fixedBufferStream(input);
        var bit_reader: BitReader = std.io.bitReader(.Big, fixed_buf_reader.reader());

        return try Self.parse(allocator, &bit_reader);
    }

    fn parse(allocator: Allocator, bit_reader: *BitReader) anyerror!Self {
        const version = try bit_reader.readBitsNoEof(u3, 3);
        const id = @intToEnum(PacketType, try bit_reader.readBitsNoEof(u3, 3));

        var payload: Payload = undefined;

        switch (id) {
            .literal => {
                var literal_value: u64 = 0;
                var more = true;

                while (more) {
                    const nibble = try bit_reader.readBitsNoEof(u5, 5);
                    literal_value = (literal_value << 4) | (nibble & 0xF);
                    more = (nibble >> 4) == 1;
                }

                payload = Payload{ .literal_value = literal_value };
            },
            else => {
                const length_type = try bit_reader.readBitsNoEof(u1, 1);

                var packets = std.ArrayList(Packet).init(allocator);

                switch (length_type) {
                    0 => {
                        const length_bits = try bit_reader.readBitsNoEof(u15, 15);
                        const start_offset = bit_offset(bit_reader.*);

                        while (bit_offset(bit_reader.*) < start_offset + length_bits) {
                            try packets.append(try Packet.parse(allocator, bit_reader));
                        }
                    },
                    1 => {
                        var length_count = try bit_reader.readBitsNoEof(u11, 11);

                        while (length_count > 0) : (length_count -= 1) {
                            try packets.append(try Packet.parse(allocator, bit_reader));
                        }
                    },
                }

                payload = Payload{ .operator = packets.toOwnedSlice() };
            },
        }

        return Self{
            .allocator = allocator,
            .version = version,
            .id = id,
            .payload = payload,
        };
    }

    fn version_sum(self: Self) usize {
        var sum = @as(usize, self.version);

        switch (self.id) {
            .literal => {},
            else => for (self.payload.operator) |packet| {
                sum += packet.version_sum();
            },
        }

        return sum;
    }

    fn value(self: Self) u64 {
        switch (self.id) {
            .sum => {
                var sum: u64 = 0;

                for (self.payload.operator) |packet| {
                    sum += packet.value();
                }

                return sum;
            },
            .product => {
                var product: u64 = 1;

                for (self.payload.operator) |packet| {
                    product *= packet.value();
                }

                return product;
            },
            .minimum => {
                var minimum: u64 = std.math.maxInt(u64);

                for (self.payload.operator) |packet| {
                    minimum = std.math.min(minimum, packet.value());
                }

                return minimum;
            },
            .maximum => {
                var maximum: u64 = 0;

                for (self.payload.operator) |packet| {
                    maximum = std.math.max(maximum, packet.value());
                }

                return maximum;
            },
            .literal => {
                return self.payload.literal_value;
            },
            .greater_than => {
                const a = self.payload.operator[0].value();
                const b = self.payload.operator[1].value();
                return if (a > b) 1 else 0;
            },
            .less_than => {
                const a = self.payload.operator[0].value();
                const b = self.payload.operator[1].value();
                return if (a < b) 1 else 0;
            },
            .equal_to => {
                const a = self.payload.operator[0].value();
                const b = self.payload.operator[1].value();
                return if (a == b) 1 else 0;
            },
        }
    }
};

fn dehex(allocator: Allocator, hex_input: []const u8) ![]u8 {
    var input = try std.ArrayList(u8).initCapacity(allocator, (hex_input.len + 1) / 2);
    errdefer input.deinit();

    for (hex_input) |c, i| {
        const x = try std.fmt.charToDigit(c, 16);
        if (i % 2 == 0) {
            try input.append(x << 4);
        } else {
            input.items[input.items.len - 1] |= x;
        }
    }

    return input.toOwnedSlice();
}

test "bits example 1" {
    const input = "D2FE28";

    const allocator = std.testing.allocator;

    const packet = try Packet.parse_str(allocator, input);
    defer packet.deinit();

    try std.testing.expectEqual(@as(u3, 6), packet.version);
    try std.testing.expectEqual(@as(u3, 4), @enumToInt(packet.id));
    try std.testing.expectEqual(@as(u64, 2021), packet.payload.literal_value);
}

test "bits example 2" {
    const input = "38006F45291200";

    const allocator = std.testing.allocator;

    const packet = try Packet.parse_str(allocator, input);
    defer packet.deinit();

    try std.testing.expectEqual(@as(u3, 1), packet.version);
    try std.testing.expectEqual(@as(u3, 6), @enumToInt(packet.id));
    try std.testing.expectEqual(@as(u64, 10), packet.payload.operator[0].payload.literal_value);
    try std.testing.expectEqual(@as(u64, 20), packet.payload.operator[1].payload.literal_value);
}

test "bits example 3" {
    const input = "EE00D40C823060";

    const allocator = std.testing.allocator;

    const packet = try Packet.parse_str(allocator, input);
    defer packet.deinit();

    try std.testing.expectEqual(@as(u3, 7), packet.version);
    try std.testing.expectEqual(@as(u3, 3), @enumToInt(packet.id));
    try std.testing.expectEqual(@as(u64, 1), packet.payload.operator[0].payload.literal_value);
    try std.testing.expectEqual(@as(u64, 2), packet.payload.operator[1].payload.literal_value);
    try std.testing.expectEqual(@as(u64, 3), packet.payload.operator[2].payload.literal_value);
}

test "version sums" {
    const allocator = std.testing.allocator;

    const a = try Packet.parse_str(allocator, "8A004A801A8002F478");
    defer a.deinit();

    try std.testing.expectEqual(@as(usize, 16), a.version_sum());

    const b = try Packet.parse_str(allocator, "620080001611562C8802118E34");
    defer b.deinit();

    try std.testing.expectEqual(@as(usize, 12), b.version_sum());
}

test "values" {
    const allocator = std.testing.allocator;

    const a = try Packet.parse_str(allocator, "C200B40A82");
    defer a.deinit();

    try std.testing.expectEqual(@as(u64, 3), a.value());

    const b = try Packet.parse_str(allocator, "04005AC33890");
    defer b.deinit();

    try std.testing.expectEqual(@as(u64, 54), b.value());

    const c = try Packet.parse_str(allocator, "880086C3E88112");
    defer c.deinit();

    try std.testing.expectEqual(@as(u64, 7), c.value());

    const d = try Packet.parse_str(allocator, "CE00C43D881120");
    defer d.deinit();

    try std.testing.expectEqual(@as(u64, 9), d.value());

    const e = try Packet.parse_str(allocator, "D8005AC2A8F0");
    defer e.deinit();

    try std.testing.expectEqual(@as(u64, 1), e.value());

    const f = try Packet.parse_str(allocator, "F600BC2D8F");
    defer f.deinit();

    try std.testing.expectEqual(@as(u64, 0), f.value());

    const g = try Packet.parse_str(allocator, "9C005AC2F8F0");
    defer g.deinit();

    try std.testing.expectEqual(@as(u64, 0), g.value());

    const h = try Packet.parse_str(allocator, "9C0141080250320F1802104A08");
    defer h.deinit();

    try std.testing.expectEqual(@as(u64, 1), h.value());
}
