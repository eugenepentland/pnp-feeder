const std = @import("std");

pub const Header = packed struct {
    message_id: u8,
    hardware_address: u8,

    pub fn serialize() []const u8 {
        return encode_bytes(Header);
    }

    pub fn deserialize(buffer: []const u8) Header {
        return decode_bytes(Header, buffer);
    }
};
pub const rotate_servo = struct {
    header: Header,
    angle: u16,

    pub fn init(
        hardware_address: u8,
        angle: u16,
    ) rotate_servo {
        return rotate_servo{
            .header = Header{
                .message_id = 0,
                .hardware_address = hardware_address,
            },
            .angle = angle,
        };
    }

    pub inline fn serialize(self: @This()) []const u8 {
        return encode_bytes(self)[0..];
    }

    pub inline fn deserialize(buffer: []const u8) rotate_servo {
        return decode_bytes(rotate_servo, buffer);
    }
};
pub const set_led_in_array = struct {
    header: Header,
    led_index: u8,
    green: u8,
    red: u8,
    blue: u8,

    pub fn init(
        hardware_address: u8,
        led_index: u8,
        green: u8,
        red: u8,
        blue: u8,
    ) set_led_in_array {
        return set_led_in_array{
            .header = Header{
                .message_id = 1,
                .hardware_address = hardware_address,
            },
            .led_index = led_index,
            .green = green,
            .red = red,
            .blue = blue,
        };
    }

    pub inline fn serialize(self: @This()) []const u8 {
        return encode_bytes(self)[0..];
    }

    pub inline fn deserialize(buffer: []const u8) set_led_in_array {
        return decode_bytes(set_led_in_array, buffer);
    }
};
pub const reset_usb_boot = struct {
    header: Header,

    pub fn init(
        hardware_address: u8,
    ) reset_usb_boot {
        return reset_usb_boot{
            .header = Header{
                .message_id = 125,
                .hardware_address = hardware_address,
            },
        };
    }

    pub inline fn serialize(self: @This()) []const u8 {
        return encode_bytes(self)[0..];
    }

    pub inline fn deserialize(buffer: []const u8) reset_usb_boot {
        return decode_bytes(reset_usb_boot, buffer);
    }
};

pub const Message = union(enum) {
    rotate_servo: rotate_servo,
    set_led_in_array: set_led_in_array,
    reset_usb_boot: reset_usb_boot,

    pub fn typeFromMessageId(id: u8, buffer: []const u8) !Message {
        switch (id) {
            0 => {
                return Message{ .rotate_servo = rotate_servo.deserialize(buffer) };
            },
            1 => {
                return Message{ .set_led_in_array = set_led_in_array.deserialize(buffer) };
            },
            125 => {
                return Message{ .reset_usb_boot = reset_usb_boot.deserialize(buffer) };
            },
            else => {
                return error.MessageNotFound;
            },
        }
    }
};

pub inline fn decode_bytes(comptime T: type, buffer: []const u8) T {
    const byte_count = @sizeOf(T);

    if (buffer.len < byte_count) {
        var buff_copy: [byte_count]u8 = [_]u8{0} ** byte_count;
        std.mem.copyForwards(u8, buff_copy[0..], buffer);
        return std.mem.bytesToValue(T, &buff_copy);
    }
    return std.mem.bytesToValue(T, buffer[0..byte_count]);
}

pub inline fn encode_bytes(T: anytype) [@sizeOf(@TypeOf(T))]u8 {
    return std.mem.toBytes(T);
}
