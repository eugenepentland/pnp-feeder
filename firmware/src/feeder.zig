const std = @import("std");
const microzig = @import("microzig");
const SG90 = @import("devices/sg90.zig");
const LedStrip = @import("devices/ws2812_led.zig");

const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const Pwm = microzig.hal.pwm.Pwm;

pub var feeder: Feeder = undefined;

pub const Feeder = struct {
    servo: SG90,
    led_strip: LedStrip,
    ready_time: u64,
    response_sent: bool,

    pub fn init() !Feeder {
        const led_strip = try LedStrip.init(0, 0, 27);
        const servo = SG90.init(26, 5, .a);

        _ = servo.set_level(250);
        time.sleep_ms(1000);
        _ = servo.set_level(500);

        return Feeder{
            .servo = servo,
            .led_strip = led_strip,
            .ready_time = 0,
            .response_sent = false,
        };
    }

    pub fn rotate_servo(self: *Feeder, angle: u16) !void {
        // Turn on the PWM signal and return how long it will take to complete the movement
        const sleep_ms = self.servo.set_level(angle);
        std.log.info("Rotating servo to level: {d}", .{angle});

        // Set the time at which it can move again (time is in microseconds)
        const sleep_time_micro_second: u64 = @intCast(sleep_ms);

        const now: u64 = time.get_time_since_boot().to_us();

        // Update the time at which a new message can be recieved
        self.ready_time = now + (sleep_time_micro_second * 1000);
    }
};
