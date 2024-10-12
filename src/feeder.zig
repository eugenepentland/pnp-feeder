const std = @import("std");
const microzig = @import("microzig");
const usb_config = @import("usb_config.zig");
const setup = @import("setup.zig");
const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const Pwm = microzig.hal.pwm.Pwm;

pub const Command = enum(u8) {
    //Echo = 100,
    Bootloader = 125,
    Led_Control = 101,
    Servo_Control = 102,
};

pub const Feeder = struct {
    led: Pwm(4, .b),
    servo: Pwm(3, .a),
    next_move_time: u64,
    speed: u16 = 100,
    servo_angle: u16 = 70,
    buf: [64]u8 = undefined,

    pub fn run_cmd(self: *Feeder, cmd: Command, args: []const u8) !void {
        switch (cmd) {
            .Bootloader => return self.cmd_bootloader(),
            .Led_Control => return self.cmd_set_led_level(args),
            .Servo_Control => return self.cmd_set_servo_angle(args),
        }
    }

    //fn cmd_echo_msg(self: @This(), args: []const u8) !void {
    //    std.log.info("Echoing the data {any}", .{args});
    //    const text = try std.fmt.bufPrint(&self.buf, "cdc test: {s}", .{args});
    //    setup.driver_cdc.write(text);
    //}

    fn cmd_set_servo_angle(self: *Feeder, args: []const u8) !void {
        const now = time.get_time_since_boot().to_us();
        const angle: u16 = @intCast(args[0]);
        const prev_angle = self.servo_angle;
        var delay_ms: u64 = 0;
        const delay_msb: u64 = @intCast(args[1]);
        const delay_lsb: u64 = @intCast(args[2]);
        delay_ms = delay_ms | delay_lsb;
        delay_ms = delay_ms | delay_msb << 8;
        return self.rotate_servo(angle, prev_angle, now, delay_ms);
    }

    fn cmd_set_led_level(self: *Feeder, args: []const u8) !void {
        if (args.len < 1) {
            return error.NoLevelValue;
        }
        // Use the first 8 bits to set the level
        const level: u16 = @intCast(args[0]);
        if (level > 100) {
            self.set_level(100);
        } else {
            self.set_level(level);
        }
    }

    pub fn cmd_bootloader(_: @This()) void {
        rp2040.rom.reset_usb_boot(0, 0);
    }

    pub fn init(now: u64) !Feeder {
        // Setup the pins
        const pin_config = rp2040.pins.GlobalConfiguration{
            .GPIO25 = .{ .name = "led", .function = .PWM4_B },
            .GPIO22 = .{ .name = "servo", .function = .PWM3_A },
        };
        const pins = pin_config.apply();

        // Setup the LED with PWM
        pins.led.slice().set_wrap(100);
        pins.led.slice().enable();

        // Setup the servo with PWM
        pins.servo.slice().set_clk_div(250, 0);
        pins.servo.slice().set_wrap(10000);
        pins.servo.slice().enable();

        // Assign to struct
        const self = Feeder{ .led = pins.led, .servo = pins.servo, .next_move_time = now };

        return self;
    }

    pub fn set_level(self: *Feeder, level: u16) void {
        self.led.set_level(level); // Set the PWM level to toggle behavior
    }

    pub fn rotate_servo(self: *Feeder, angle: u16, previous_angle: u16, now: u64, delay_ms: u64) !void {
        if (previous_angle != self.servo_angle or self.next_move_time > now) {
            return;
        }
        // Get the value to rotate the servo and sleep time
        const result = try get_level_and_sleep_time(self.servo_angle, angle, self.speed);

        // Rotate the servo
        self.servo.set_level(result.level);
        self.servo_angle = angle;
        const text = try std.fmt.bufPrint(&self.buf, "Angle: {}\n", .{self.servo_angle});
        usb_config.driver_cdc.write(text);

        // Set the time at which it can move again (time is in microseconds)
        const sleep_time_micro_second: u64 = @intCast(result.sleep_ms);
        self.next_move_time = now + (sleep_time_micro_second * 1000) + delay_ms * 1000;

        // Also set the LED (Scaling the level to max of 100)
        self.led.set_level(result.level / 68);
    }
};

fn get_level_and_sleep_time(previous_angle: u16, angle: u16, speed: u16) !struct { level: u16, sleep_ms: u16 } {
    // Validation
    if (angle > 180 or previous_angle > 180) {
        return error.InvalidAngle; // Define an error for invalid angles
    }

    const level: u16 = (54 * angle) / 10 + 250;
    var sleep_ms: u16 = 0;
    // Larger the multiplier, the slower it runs
    const multiplier: u16 = 25;

    if (angle >= previous_angle) {
        sleep_ms = (angle - previous_angle) * multiplier / 10;
    } else {
        sleep_ms = (previous_angle - angle) * multiplier / 10;
    }

    sleep_ms = (100 * sleep_ms) / speed;

    return .{
        .level = level,
        .sleep_ms = sleep_ms,
    };
}

test "serialize struct to bytes and print" {
    const MyStruct = packed struct {
        a: u8,
        b: u16,
    };

    var my_struct = MyStruct{
        .a = 128,
        .b = 512,
    };

    // Cast the struct's pointer to a byte pointer
    var bytes_ptr: [*]u8 = @ptrCast(&my_struct);

    // Create a byte slice over the struct's memory
    const bytes = bytes_ptr[0..@sizeOf(MyStruct)];

    // Print the bytes in hexadecimal format
    std.debug.print("Bytes: {any}", .{bytes_ptr});
    for (bytes) |byte| {
        std.debug.print("{x} ", .{byte});
    }
}

test "get level and sleep time" {
    const TestCase = struct {
        previous_angle: u16,
        angle: u16,
        expected_sleep_ms: u16,
        expected_level: u16,
        speed: u16,
    };

    const test_cases = [_]TestCase{
        TestCase{
            .previous_angle = 0,
            .angle = 100,
            .expected_sleep_ms = 250,
            .expected_level = 790,
            .speed = 100,
        },
        TestCase{
            .previous_angle = 100,
            .angle = 0,
            .expected_sleep_ms = 250,
            .expected_level = 250,
            .speed = 100,
        },
        TestCase{
            .previous_angle = 100,
            .angle = 0,
            .expected_sleep_ms = 2500,
            .expected_level = 250,
            .speed = 10,
        },
        TestCase{
            .previous_angle = 0,
            .angle = 80,
            .expected_sleep_ms = 200,
            .expected_level = 682,
            .speed = 100,
        },
    };

    for (test_cases) |test_case| {
        const result = try get_level_and_sleep_time(test_case.previous_angle, test_case.angle, test_case.speed);
        try std.testing.expectEqual(test_case.expected_sleep_ms, result.sleep_ms);
        try std.testing.expectEqual(test_case.expected_level, result.level);
    }
}
