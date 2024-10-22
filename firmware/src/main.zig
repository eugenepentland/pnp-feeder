const std = @import("std");
const microzig = @import("microzig");
const modbus = @import("modbus.zig");
const setup = @import("setup.zig");
const Feeder = @import("feeder.zig");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    setup.rp2040.rom.reset_usb_boot(0, 0);
}

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

    var data_buffer: [64]u8 = undefined;
    var response: []const u8 = &[_]u8{};

    while (true) {
        if (response.len != 0) {
            try feeder.cmd_complete(response);
            response = &[_]u8{};
        }

        // Get the current time
        now = setup.time.get_time_since_boot().to_us();

        // You can now poll for USB events
        var bytes_recieved: usize = 0;
        bytes_recieved = setup.rp2040.usb.Usb.task(false, &data_buffer) catch unreachable;

        if (bytes_recieved > 0) {
            std.log.info("recieved some data", .{});
            const data = data_buffer[0..bytes_recieved];

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
