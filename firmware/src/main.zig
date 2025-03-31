const std = @import("std");
const microzig = @import("microzig");
const messages = @import("generated/commands.zig");
const f = @import("feeder.zig");

const rp2xxx = microzig.hal;
const flash = rp2xxx.flash;
const time = rp2xxx.time;
const gpio = rp2xxx.gpio;
const clocks = rp2xxx.clocks;
const usb = rp2xxx.usb;
const cpu = rp2xxx.compatibility.cpu;

const uart = rp2xxx.uart.instance.num(1);
const baud_rate = 115200;
const uart_tx_pin = gpio.num(4);
const uart_rx_pin = gpio.num(5);

const usb_dev = rp2xxx.usb.Usb(.{});

const usb_config_len = usb.templates.config_descriptor_len + usb.templates.cdc_descriptor_len;
const usb_config_descriptor =
    usb.templates.config_descriptor(1, 2, 0, usb_config_len, 0xc0, 100) ++
    usb.templates.cdc_descriptor(0, 4, usb.Endpoint.to_address(1, .In), 8, usb.Endpoint.to_address(2, .Out), usb.Endpoint.to_address(2, .In), 64);

var driver_cdc: usb.cdc.CdcClassDriver(usb_dev) = .{};
var drivers = [_]usb.types.UsbClassDriver{driver_cdc.driver()};

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

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    rp2xxx.rom.reset_usb_boot(0, 0);
    @breakpoint();
    while (true) {}
}

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = rp2xxx.uart.logFn,
};

fn boot_sequence() void {
    // Flash through the LED's on boot up
    const led_count = f.feeder.led_strip.led_states.len;
    for (0..led_count) |i| {

        // Half power on the LED colors
        const color: u32 = (32 << 16) | (32 << 8) | (32);

        f.feeder.led_strip.setLed(i, color);

        // Set the previous LED to be off
        if (i > 0) {
            f.feeder.led_strip.setLed(i - 1, 0);
        }

        // Set the LED state
        f.feeder.led_strip.updateLeds();
        time.sleep_ms(100);
    }
    // Turn off all of the LEDs
    f.feeder.led_strip.setLed(led_count - 1, 0);
    f.feeder.led_strip.updateLeds();
}

pub var response: []const u8 = undefined;
var usb_tx_buff: [64]u8 = undefined;
var usb_rx_buff: [64]u8 = undefined;

pub fn main() !void {
    inline for (&.{ uart_tx_pin, uart_rx_pin }) |pin| {
        pin.set_function(.uart);
    }

    uart.apply(.{
        .baud_rate = baud_rate,
        .clock_config = rp2xxx.clock_config,
    });

    rp2xxx.uart.init_logger(uart);
    std.log.info("Logging Started", .{});
    var completed_boot_seq: bool = false;

    // First we initialize the USB clock
    usb_dev.init_clk();
    // Then initialize the USB device using the configuration defined above
    usb_dev.init_device(&DEVICE_CONFIGURATION) catch unreachable;

    f.feeder = try f.Feeder.init();
    var now: u64 = 0;

    while (true) {
        now = time.get_time_since_boot().to_us();

        // Poll for USB events
        usb_dev.task(false) catch unreachable;

        // read and print host command if present
        const rx_data = usb_cdc_read();

        if (!completed_boot_seq) {
            boot_sequence();
            completed_boot_seq = true;
        }

        f.feeder.detect_feeder();
        f.feeder.detect_button();

        if (rx_data.len > 0) {
            // Ignore message if not ready yet
            if (f.feeder.ready_time >= now) {
                std.log.info("Trying to send a cmd before its ready again", .{});
                continue;
            }

            // Parse the header
            const header = messages.Header.deserialize(rx_data[0..]);

            // Get the message
            const message = try messages.Message.typeFromMessageId(header.message_id, rx_data[0..]);

            // Give each event  50ms to run
            f.feeder.ready_time = now + 350;
            f.feeder.response_sent = false;

            handleMessage(message);
        }

        // Send a response saying the command is completed
        if (f.feeder.ready_time <= now and f.feeder.response_sent == false) {
            usb_cdc_write();
        }
    }
}

inline fn handleMessage(message: messages.Message) void {
    switch (message) {
        .rotate_servo => |payload| {
            f.feeder.rotate_servo(payload.angle) catch |err| {
                std.log.err("Couldn't rotate the servo: {any}", .{err});
            };
            copyToTxBuffer(payload);
        },
        .reset_usb_boot => {
            rp2xxx.rom.reset_usb_boot(0, 0);
        },
        .set_led_in_array => |payload| {
            const color: u32 = (@as(u32, payload.green) << 16) |
                (@as(u32, payload.red) << 8) |
                (@as(u32, payload.blue));

            f.feeder.led_strip.setLed(payload.led_index, color);
            f.feeder.led_strip.updateLeds();
            copyToTxBuffer(payload);
        },
        //else => {},
    }
}

pub fn usb_cdc_write() void {
    var write_buff = response;
    while (write_buff.len > 0) {
        write_buff = driver_cdc.write(write_buff);
    }
    _ = driver_cdc.write_flush();
    f.feeder.response_sent = true;
}

pub fn usb_cdc_read() []const u8 {
    var total_read: usize = 0;
    var read_buff: []u8 = usb_rx_buff[0..];

    while (true) {
        const len = driver_cdc.read(read_buff);
        read_buff = read_buff[len..];
        total_read += len;
        if (len == 0) break;
    }

    return usb_rx_buff[0..total_read];
}

fn copyToTxBuffer(T: anytype) void {
    // convert to an array of bytes
    const bytes = messages.encode_bytes(T);
    std.mem.copyForwards(u8, usb_tx_buff[0..], bytes[0..]);
    response = usb_tx_buff[0..bytes.len];
}
