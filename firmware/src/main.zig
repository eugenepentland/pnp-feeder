const std = @import("std");
const microzig = @import("microzig");
const modbus = @import("modbus.zig");
const setup = @import("setup.zig");
const Feeder = @import("feeder.zig");

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = setup.rp2040.uart.logFn,
};

pub fn main() !void {
    var now: u64 = 0;
    var feeder = try Feeder.Feeder.init(now);

    inline for (&.{ setup.uart_tx_pin, setup.uart_rx_pin }) |pin| {
        pin.set_function(.uart);
    }

    setup.uart.apply(.{
        .baud_rate = setup.baud_rate,
        .clock_config = setup.rp2040.clock_config,
    });

    setup.rp2040.uart.init_logger(setup.uart);

    // First we initialize the USB clock
    setup.rp2040.usb.Usb.init_clk();
    setup.rp2040.usb.Usb.init_device(&setup.DEVICE_CONFIGURATION) catch unreachable;

    var response: []const u8 = &[_]u8{};
    var buf: [64]u8 = undefined;
    var i: u32 = 0;
    var before: u64 = 0;
    var rx_array: [64]u8 = undefined;
    const rx_buffer = rx_array[0..];

    std.log.info("Starting the loop", .{});
    while (true) {
        now = setup.time.get_time_since_boot().to_us();

        // You can now poll for USB events
        const bytes_received = setup.rp2040.usb.Usb.task(true, rx_buffer) catch unreachable;
        if (response.len != 0) {
            try feeder.cmd_complete(response);
            response = &[_]u8{};
        }

        if (now - before > 5000000000) {
            before = now;
            i += 1;
            //    // uart log
            std.log.info("cdc test: {}\r\n", .{i});
            // usb log (at this moment 63 bytes is max limit per single call)
            const text = std.fmt.bufPrint(&buf, "cdc test: {}\r\n", .{i}) catch &.{};
            setup.driver_cdc.write(text);
        }

        if (bytes_received > 0) {
            const data = rx_buffer[0..bytes_received];

            // Validate the data and get the address/function id
            const packet = modbus.validate_data(data) catch |err| {
                std.log.err("error getting the packet, {any}", .{err});
                continue;
            };

            // Run the command
            const cmdEnum: Feeder.Command = @enumFromInt(packet.function);
            response = feeder.run_cmd(cmdEnum, packet.args) catch |err| {
                std.log.err("Error running {any} {any}", .{ cmdEnum, err });
                continue;
            };
        }
    }
}
