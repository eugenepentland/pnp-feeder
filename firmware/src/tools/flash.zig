const std = @import("std");
const zig_serial = @import("serial");
const modbus = @import("modbus");

pub fn set_usb_boot(port_name: []const u8) !void {
    var serial = try openDevice(port_name);
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    var buffer = [_]u8{ 0, 125, 0, 0, 0 };
    try modbus.append_crc_to_data(buffer[0..]);
    _ = try serial.writer().writeAll(buffer[0..]);
    std.log.info("Successfully put into boot mode", .{});
}

pub fn openDevice(port_name: []const u8) !std.fs.File {
    var retry_attempts: usize = 0;
    const max_total_delay_ms: usize = 2000; // Maximum wait time of 2 seconds
    const base_delay_ms: usize = 200; // Start with 100ms for the first retry
    var delay_ms: usize = base_delay_ms;

    while (retry_attempts < 10) {
        // Attempt to open the serial port to the device
        const device = std.fs.cwd().openFile(port_name, .{ .mode = .read_write }) catch {
            // Device not found, implement exponential backoff
            if (retry_attempts == 0) {
                std.debug.print("Device not found on port {s}, retrying.", .{port_name});
            } else {
                std.debug.print(".", .{});
            }

            // Sleep for the calculated delay
            std.time.sleep(std.time.ns_per_ms * 200);

            // Increase the delay exponentially for the next attempt
            delay_ms += 200;
            if (delay_ms > max_total_delay_ms) {
                delay_ms = max_total_delay_ms; // Cap the delay at 2 seconds
            }

            retry_attempts += 1;
            continue;
        };
        std.debug.print("\n", .{});
        // Return the device if successfully opened
        return device;
    }

    // Return an error if the device is not found after retries
    return error.NoDeviceFound;
}

pub fn write_firmware_to_device(port_name: []const u8, uf2_file_path: []const u8) !void {
    // Open the UF2 file
    const uf2_file = std.fs.cwd().openFile(uf2_file_path, .{}) catch {
        return error.NoFirmwareFound;
    };
    defer uf2_file.close();

    // Validate file size (UF2 file should be in 512 byte blocks)
    const uf2_stat = try uf2_file.stat();
    if ((uf2_stat.size % 512) != 0) {
        std.log.warn("{s} does not have a size multiple of 512. might be corrupt!", .{uf2_file_path});
    }

    const total_blocks = uf2_stat.size / 512;
    std.log.info("Total firmware size: {d} bytes", .{uf2_stat.size});

    // Open the serial port to the device
    var device = try openDevice(port_name);
    defer device.close();

    // Flash the firmware by writing UF2 file blocks to the device
    try uf2_file.seekTo(0); // Start at the beginning of the file
    var block_num: u64 = 0;
    var block: [512]u8 = undefined;

    std.debug.print("Flashing firmware to the device...", .{});
    while (true) {
        const rd_len = try uf2_file.read(&block);
        if (rd_len == 0) break; // End of file

        if (rd_len != block.len) {
            std.log.warn("Incomplete block read: Expected 512, got {d} bytes at block {d}", .{ rd_len, block_num });
            return error.IncompleteFile;
        }

        const wr_len = try device.write(&block);
        if (wr_len != block.len) {
            std.log.warn("Failed to write block {d}: Only {d} bytes written!", .{ block_num, wr_len });
            return error.WriteFailed;
        }
        block_num += 1;
        if ((total_blocks / 10) % block_num == 0) {
            std.debug.print(".", .{});
        }
    }
    std.debug.print("\n", .{});
    std.log.info("Successfully flashed {s}!", .{uf2_file_path});
}

pub fn main() !void {
    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM1" else "/dev/ttyACM1";
    const uf2_file_path = "zig-out/firmware/main.uf2";

    // Sets the device to switch to the USB bootloader
    set_usb_boot(port_name) catch |err| {
        std.log.err("Couldn't open bootloader: {any}", .{err});
    };

    // Flashes the new firmware to the device
    write_firmware_to_device("/dev/sda", uf2_file_path) catch |err| {
        std.log.err("Couldn't write the firmware: {any}", .{err});
    };
}
