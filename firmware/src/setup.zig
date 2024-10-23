const microzig = @import("microzig");

pub const rp2040 = microzig.hal;
const flash = rp2040.flash;
pub const time = rp2040.time;
const gpio = rp2040.gpio;
const clocks = rp2040.clocks;
const usb = rp2040.usb;

pub const led = gpio.num(25);
pub const uart = rp2040.uart.instance.num(0);
pub const baud_rate = 115200;
pub const uart_tx_pin = gpio.num(0);
pub const uart_rx_pin = gpio.num(1);

const usb_config_len = usb.templates.config_descriptor_len + usb.templates.cdc_descriptor_len;
var usb_config_descriptor =
    usb.templates.config_descriptor(1, 2, 0, usb_config_len, 0xc0, 100) ++
    usb.templates.cdc_descriptor(
    0,
    4,
    usb.Endpoint.to_address(1, .In), // Notification Endpoint
    8,
    usb.Endpoint.to_address(2, .Out), // Data OUT Endpoint
    usb.Endpoint.to_address(2, .In), // Data IN Endpoint
    64,
) ++ usb.templates.vendor_descriptor(1, 5, usb.Endpoint.to_address(3, .Out), usb.Endpoint.to_address(3, .In), 64);

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
        &usb.utils.utf8ToUtf16Le("PNP-Feeder"),
    },
    .drivers = &drivers,
};
