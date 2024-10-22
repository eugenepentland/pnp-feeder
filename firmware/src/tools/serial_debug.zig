const std = @import("std");
const zig_serial = @import("serial");

pub fn main() !u8 {
    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM7" else "/dev/ttyUSB0";

    var serial = std.fs.cwd().openFile(port_name, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{port_name});
            return 1;
        },
        else => return err,
    };
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    std.log.info("starting loop", .{});
    var buffer: [128]u8 = undefined;
    var line: [128]u8 = undefined;
    var index: usize = 0;

    while (true) {
        // Read one byte at a time
        _ = try serial.reader().read(buffer[0..1]);
        const byte = buffer[0];
        
        // Check if it's a newline character (LF or CR)
        if (byte == '\n' or byte == '\r') {
            if (index > 0) {
                // End of line detected, print the accumulated line
                const line_slice = line[0..index];
                std.log.info("Received: {s}", .{line_slice});
                index = 0; // Reset index for the next line
            }
        } else {
            // Accumulate the bytes into the line buffer
            if (index < line.len) {
                line[index] = byte;
                index += 1;
            } else {
                std.debug.print("Line too long, discarding\n", .{});
                index = 0; // Reset index if the line is too long
            }
        }
    }

    return 0;
}
