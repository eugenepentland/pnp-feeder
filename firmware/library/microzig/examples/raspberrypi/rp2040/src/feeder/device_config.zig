const std = @import("std");
const microzig = @import("microzig");
const feeder = @import("./feeder.zig");

pub const rp2040 = microzig.hal;
pub const flash = rp2040.flash;
pub const time = rp2040.time;
pub const gpio = rp2040.gpio;
pub const usb = rp2040.usb;

pub const flash_target_offset: u32 = 256 * 1024;
pub const flash_i_ptr = @as(*const u32, @ptrFromInt(rp2040.flash.XIP_BASE + flash_target_offset));

pub const usb_config_len = usb.templates.config_descriptor_len + usb.templates.cdc_descriptor_len;
pub const usb_config_descriptor =
    usb.templates.config_descriptor(1, 2, 0, usb_config_len, 0xc0, 100) ++
    usb.templates.cdc_descriptor(0, 4, usb.Endpoint.to_address(1, .In), 8, usb.Endpoint.to_address(2, .Out), usb.Endpoint.to_address(2, .In), 64);

pub var driver_cdc = usb.cdc.CdcClassDriver{};
pub var drivers = [_]usb.types.UsbClassDriver{driver_cdc.driver()};

// This is our device configuration
pub var DEVICE_CONFIGURATION: usb.DeviceConfiguration = .{
    .device_descriptor = &.{
        .descriptor_type = usb.DescType.Device,
        .bcd_usb = 0x0200,
        .device_class = 0xEF,
        .device_subclass = 2,
        .device_protocol = 1,
        .max_packet_size0 = 64,
        .vendor = 0x2E8A,
        .product = 0x000a,
        .bcd_device = 0x0100,
        .manufacturer_s = 1,
        .product_s = 2,
        .serial_s = 0,
        .num_configurations = 1,
    },
    .config_descriptor = &usb_config_descriptor,
    .lang_descriptor = "\x04\x03\x09\x04", // length || string descriptor (0x03) || Engl (0x0409)
    .descriptor_strings = &.{
        &usb.utils.utf8ToUtf16Le("Raspberry Pi"),
        &usb.utils.utf8ToUtf16Le("Pico Test Device"),
        &usb.utils.utf8ToUtf16Le("someserial"),
        &usb.utils.utf8ToUtf16Le("Board CDC"),
    },
    .drivers = &drivers,
};

// Pin definitions
pub const led = gpio.num(25);
pub const uart = rp2040.uart.instance.num(0);
pub const baud_rate = 115200;
pub const uart_tx_pin = gpio.num(0);
pub const uart_rx_pin = gpio.num(1);
const pin_config = rp2040.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
};

pub const LED = struct {
    pin: type,

    pub fn init() !LED {
        //const pins = pin_config.apply();
        return LED{
            .pin = void,
        };
    }

    pub fn toggle(self: *LED) void {
        self.pin.toggle();
    }
};

pub const Feeder = struct {
    device: type,
    //servo: type,
    time: type,
    feed_count: u32,
    servo_angle: f32 = 0,

    pub fn poll_usb(self: *Feeder) !void {
        self.usb.Usb.task(false) catch unreachable;
    }

    pub fn toggle_led(self: *Feeder) void {
        self.led.toggle();
    }

    pub fn save_feed_count(self: *Feeder) void {
        // Clear the block before writing the data
        flash.range_erase(flash_target_offset, flash.SECTOR_SIZE);

        // Prepare data to program (must be a whole number of pages)
        var data: [flash.PAGE_SIZE]u8 = [_]u8{0xFF} ** flash.PAGE_SIZE;

        // Convert the u32 to a u8 array
        data[3] = @truncate((self.feed_count >> 24) & 0xff);
        data[2] = @truncate((self.feed_count >> 16) & 0xff);
        data[1] = @truncate((self.feed_count >> 8) & 0xff);
        data[0] = @truncate((self.feed_count) & 0xff);

        // Write the data
        flash.range_program(flash_target_offset, data[0..flash.PAGE_SIZE]);
    }

    pub fn rotate_servo(self: *Feeder, angle: f32, speed: u16) void {
        const level: f32 = (5.4 * angle) + 250;
        self.servo.set_level(@intFromFloat(level));
        self.servo_angle = angle;
        const sleep_time: u16 = @intFromFloat(@abs(angle - self.servo_angle) * 1.8);
        time.sleep_ms(100 * sleep_time / speed);
    }

    pub fn get_feed_count() *const u32 {
        // Defer this to runtime
        return @as(*const u32, @ptrFromInt(rp2040.flash.XIP_BASE + flash_target_offset));
    }

    pub fn init() Feeder {
        //const pin_config = rp2040.pins.GlobalConfiguration{ .GPIO22 = .{ .name = "servo", .function = .PWM3_A } };
        // Initalize the PWM signal with a 500khz period
        //const pins = pin_config.apply();
        //const slice = pins.servo.slice();
        //slice.set_clk_div(250, 0);
        //slice.set_wrap(10000);
        //slice.enable();

        // Init the LED
        led.set_function(.sio);
        led.set_direction(.out);
        led.put(1);

        // Setup UART
        rp2040.uart.apply(.{
            .baud_rate = rp2040.baud_rate,
            .clock_config = rp2040.rp2040.clock_config,
        });
        rp2040.rp2040.uart.init_logger(rp2040.uart);

        // Init USB
        //device.rp2040.usb.Usb.init_clk();
        //device.rp2040.usb.Usb.init_device(&device.DEVICE_CONFIGURATION) catch unreachable;

        // Get the feed_count
        const feed_count = get_feed_count();

        return Feeder{
            .device = rp2040,
            //.servo = pins.servo,
            .feed_count = feed_count,
            .time = rp2040.time,
        };
    }
};
