const std = @import("std");
const microzig = @import("microzig");
const feeder = @import("./device_config.zig");

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub fn main() !void {
    const led = try feeder.LED.init();
    led.pin.apply();
    led.toggle();

    var old: u64 = led.time.get_time_since_boot().to_us();
    var new: u64 = 0;

    while (true) {
        // You can now poll for USB events

        new = led.time.get_time_since_boot().to_us();
        if (led.time.get_time_since_boot().to_us() < 5000000) {
            continue;
        }

        if (new - old > 500000) {
            old = new;
            led.toggle();
        }
    }
}
