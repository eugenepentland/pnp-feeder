const std = @import("std");
const microzig = @import("microzig");
const usb_config = @import("usb_config.zig");
const setup = @import("setup.zig");
const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const Pwm = microzig.hal.pwm.Pwm;

pub const servo_angle_args = packed struct {
    const id: u8 = 102;
    angle: u8,
    delay_ms: u16,

    pub fn decode(args: []const u8) !servo_angle_args {
        if (args.len < 3) {
            return error.InvalidArgs;
        }

        const delay_msb: u16 = @intCast(args[1]);
        const delay_lsb: u16 = @intCast(args[2]);

        return servo_angle_args{
            .angle = args[0],
            .delay_ms = (delay_msb << 8) | delay_lsb,
        };
    }
};

pub const Command = enum(u8) {
    //Echo = 100,
    Bootloader = 125,
    Led_Control = 101,
    Echo = 103,
    Servo_Control = servo_angle_args.id,
};

pub const Feeder = struct {
    led: Pwm(4, .b),
    servo: Pwm(3, .a),
    next_move_time: u64,
    is_ready: bool,
    speed: u16 = 20,
    servo_angle: u16 = 70,
    buf: [64]u8 = undefined,

    pub fn run_cmd(self: *Feeder, cmd: Command, args: []const u8) ![]const u8 {
        var response: []const u8 = undefined;
        // Exit early if there is already a cmd running
        if (!self.is_ready) {
            std.log.info("Trying to send a cmd before its ready again", .{});
            return response;
        }

        self.is_ready = false;
        switch (cmd) {
            .Bootloader => try self.cmd_bootloader(),
            .Led_Control => try self.cmd_set_led_level(args),
            .Servo_Control => try self.cmd_set_servo_angle(args),
            .Echo => response = try self.cmd_echo(args),
        }
        return response;
    }

    pub fn cmd_echo(_: *Feeder, args: []const u8) ![]const u8 {
        return args;
    }

    pub fn cmd_complete(self: *Feeder, response: []const u8) !void {
        setup.driver_cdc.write(response);
        std.log.info("Command complete {any}", .{response});
        self.is_ready = true;
    }

    fn cmd_set_servo_angle(self: *Feeder, args: []const u8) !void {
        const now = time.get_time_since_boot().to_us();
        const params = try servo_angle_args.decode(args);
        std.log.info("Params: {any} {any}", .{ params, self.servo_angle });
        try self.rotate_servo(@intCast(params.angle), self.servo_angle, now, @intCast(params.delay_ms));
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

    pub fn cmd_bootloader(_: *Feeder) !void {
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
        const self = Feeder{ .led = pins.led, .servo = pins.servo, .next_move_time = now, .is_ready = true };

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
        std.log.info("result: {any}", .{result});

        // Rotate the servo
        self.servo.set_level(result.level);
        self.servo_angle = angle;

        // Set the time at which it can move again (time is in microseconds)
        const sleep_time_micro_second: u64 = @intCast(result.sleep_ms);
        self.next_move_time = now + (sleep_time_micro_second * 1000) + delay_ms * 1000;

        // Also set the LED (Scaling the level to max of 100)
        self.led.set_level(result.level / 68);
    }
};

fn parse_servo_args(args: []const u8) !struct {
    angle: u16,
    delay_ms: u64,
} {
    if (args.len < 3) {
        return error.InvalidArgs;
    }

    const angle: u16 = @intCast(args[0]);
    const delay_msb: u64 = @intCast(args[1]);
    const delay_lsb: u64 = @intCast(args[2]);
    const delay_ms: u64 = (delay_msb << 8) | delay_lsb;

    return .{
        .angle = angle,
        .delay_ms = delay_ms,
    };
}

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

test "deserialize byte slice into packed struct" {
    // Example byte slice that we want to deserialize
    const bytes = [_]u8{ 0x03, 0x01, 0x00 }; // Represents { .a = 3, .b = 258 }

    const dataAsStruct = std.mem.bytesToValue(servo_angle_args, &bytes);

    try std.testing.expectEqual(3, dataAsStruct.angle);
    try std.testing.expectEqual(258, dataAsStruct.delay_ms);
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
