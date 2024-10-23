const std = @import("std");

pub const Packet = struct {
    address: u8,
    function: u8,
    args: []const u8,
};

const MyError = error{
    InvalidInput,
    CorruptData,
    InvalidLength,
};

pub fn validate_data(data: []const u8) !Packet {
    if (data.len < 4) {
        return MyError.InvalidLength;
    }
    // Extract the last two bytes (the CRC)
    const len = data.len;
    const high: u16 = @intCast(data[len - 2]); // Second to last byte (high byte)
    const low: u16 = @intCast(data[len - 1]); // Last byte (low byte)

    // Combine the high and low bytes into a u16
    const crc: u16 = (high << 8) | low;

    const generated_crc = generate_crc16(data[0 .. len - 2]);

    if (crc != generated_crc) {
        return MyError.CorruptData;
    }

    if (data.len > 4) {
        return Packet{
            .address = data[0],
            .function = data[1],
            .args = data[2 .. len - 2],
        };
    } else {
        return Packet{
            .address = data[0],
            .function = data[1],
            .args = &[_]u8{},
        };
    }
}

pub fn generate_crc16(data: []const u8) u16 {
    var crc: u16 = 0xFFFF;

    for (data) |byte| {
        crc ^= byte;
        for (0..8) |_| {
            const lsb: bool = (crc & 0x0001) != 0;
            crc >>= 1;
            if (lsb) {
                crc ^= 0xA001;
            }
        }
    }
    return crc;
}

pub fn append_crc_to_data(data: []u8, crc: u16) void {
    const crc_low: u8 = @intCast(crc & 0xFF);
    const crc_high: u8 = @intCast((crc >> 8) & 0xFF);

    data[data.len - 1] = crc_low; // Update second-to-last byte with low byte of CRC
    data[data.len - 2] = crc_high; // Update last byte with high byte of CRC
}

test "Update crc in place" {
    const expect: []const u8 = &[_]u8{ 0, 125, 0, 144, 80 };
    var data = [_]u8{ 0, 125, 0, 0, 0 };

    const crc = generate_crc16(data[0 .. data.len - 2]);
    append_crc_to_data(data[0..], crc);
    
    try std.testing.expect(std.mem.eql(u8, data[0..], expect));
}

test "validate data" {
    const tst = struct {
        expect: u16,
        data: []const u8,
    };
    const tests = [_]tst{
        tst{ .expect = 57729, .data = &[_]u8{ 0x01, 0x02, 0xE1, 0x81 } },
    };
    for (tests) |t| {
        const packet = try validate_data(t.data);
        try std.testing.expectEqual(t.data[0], packet.address);
        try std.testing.expectEqual(t.data[1], packet.function);
    }
}

test "generate CRC-16 for Modbus RTU" {
    const tst = struct {
        expect: u16,
        data: []const u8,
    };
    const tests = [_]tst{
        tst{ .expect = 45057, .data = &[_]u8{ 0x00, 0x00 } },
        tst{ .expect = 32894, .data = &[_]u8{0x01} },
    };
    for (tests) |t| {
        const result = generate_crc16(t.data);
        try std.testing.expectEqual(t.expect, result);
    }
}
