const std = @import("std");
const zig_serial = @import("serial");

pub fn main() !void {
    std.log.info("Running the serial command!", .{});
    var serial = try std.fs.cwd().openFile("\\\\.\\COM9", .{ .mode = .read_write });
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 19200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    try serial.writer().writeAll("Hello, World!\r\n");

    const b = try serial.read().readByte();
    std.log.info("Byte: {any}", .{b});
}
