const std = @import("std");
const zig_serial = @import("serial");
const modbus = @import("modbus.zig");
pub fn main() !void {
    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM1" else "/dev/ttyACM1";

    var serial = try std.fs.cwd().openFile(port_name, .{ .mode = .read_write });
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    var buf: [64]u8 = undefined;
    const data = [_]u8{ 0, 103, 101, 102, 103, 104, 0, 0 };
    const slice = buf[0..data.len];

    while (true) {
        // Generate the data to send
        std.mem.copyForwards(u8, slice, data[0..data.len]);
        try modbus.append_crc_to_data(slice);

        // Send the data
        _ = try serial.writer().writeAll(slice);

        // Read the response
        const bytes_read = try serial.reader().readAll(buf[0..4]);
        std.log.info("Response: {any}", .{buf[0..bytes_read]});
        std.time.sleep(std.time.ns_per_ms * 200);
    }
}
