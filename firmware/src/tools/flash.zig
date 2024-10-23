const std = @import("std");
const zig_serial = @import("serial");
const modbus = @import("modbus.zig");

pub fn set_usb_boot(port_name: []const u8) !void {
    var serial = try std.fs.cwd().openFile(port_name, .{ .mode = .read_write });
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    var buffer = [_]u8{ 0, 125, 0, 0, 0 };
    const crc = modbus.generate_crc16(buffer[0 .. buffer.len - 2]);
    modbus.append_crc_to_data(buffer[0..], crc);
    _ = try serial.writer().writeAll(buffer[0..]);
    std.log.info("Successfully put into boot mode", .{});
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
    std.log.info("Total blocks: {d}", .{total_blocks});

    // Open the serial port to the device
    var device = std.fs.cwd().openFile(port_name, .{ .mode = .write_only }) catch {
        return error.NoPicoInBootloader;
    };
    defer device.close();

    // Flash the firmware by writing UF2 file blocks to the device
    try uf2_file.seekTo(0); // Start at the beginning of the file
    var block_num: u64 = 0;
    var block: [512]u8 = undefined;

    std.log.info("Flashing firmware to the device...", .{});
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
    }

    std.log.info("Successfully flashed {s} to the device!", .{uf2_file_path});
}

pub fn main() !void {
    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM1" else "/dev/ttyACM1";
    const uf2_file_path = "zig-out/firmware/main.uf2";
    var sleep_time_s: u64 = 2;

    // Sets the device to switch to the USB bootloader
    set_usb_boot(port_name) catch |err| {
        std.log.err("Couldn't open bootloader: {any}", .{err});
        sleep_time_s = 0;
    };

    // Sleep if waiting for device to switch to bootloader mode
    std.time.sleep(std.time.ns_per_s * sleep_time_s);

    // Flashes the new firmware to the device
    write_firmware_to_device("/dev/sda", uf2_file_path) catch |err| {
        std.log.err("Couldn't write the firmware: {any}", .{err});
    };
}
