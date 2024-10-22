const std = @import("std");
const zig_serial = @import("serial");
const modbus = @import("modbus.zig");

pub fn main() !void {
    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM1" else "/dev/ttyACM0";

    // Open the serial port and exit early if the device can't be found
    var serial = std.fs.cwd().openFile(port_name, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.info("Error opening serial port {s}. Skipping Flashing.", .{port_name});
            return;
        },
        else => {
            std.log.info("Some other error! {any}", .{err});
            return;
        },
    };
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });
    const address = 0;
    const function_id = 103;
    const data = 105;
    var cmd = [_]u8{ address, function_id, data, 222, 155 };
    const slice = cmd[0..];

    //try modbus.update_crc_in_place(slice);
    std.log.info("Running command, {any}", .{slice});

    _ = try serial.writer().writeAll(slice);

    //var buff: [4]u8 = undefined;
    //const slic2e = buff[0..];

    //while (true) {
    //    _ = try serial.read(slic2e);
    //    std.log.info("Byte: {s}", .{buff});
    //}
}
