const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const SG90 = @This();

pin: rp2040.gpio.Pin,
pwm: rp2040.pwm.Pwm,
level: u16 = 2000,

pub fn init(gpio_pin_num: u5, slice: u32, channel: rp2040.pwm.Channel) SG90 {
    const pin = rp2040.gpio.num(gpio_pin_num);
    // Make sure its set to PWM
    pin.set_function(.pwm);

    const servo = SG90{
        .pwm = rp2040.pwm.Pwm{
            .slice_number = slice,
            .channel = channel,
        },
        .pin = pin,
    };
    // Assumes 125 Mhz clock speed
    servo.pwm.slice().set_clk_div(250, 0);
    servo.pwm.slice().set_wrap(10000);
    return servo;
}

pub fn set_level(self: @This(), level: u16) u16 {
    // Set the level
    self.pwm.set_level(level);

    // Enable the PWM output
    self.pwm.slice().enable();

    return 200;
    //return self.get_sleep_time_ms(level);
}

fn get_sleep_time_ms(self: @This(), level: u16) u16 {
    //const level: u16 = (54 * angle) / 10 + 250;
    var sleep_ms: u16 = 0;
    // Larger the multiplier, the slower it runs
    const multiplier: u16 = 30;

    if (level >= self.level) {
        sleep_ms = (level - self.level) * multiplier / 10;
    } else {
        sleep_ms = (self.level - level) * multiplier / 10;
    }

    return sleep_ms;
}
