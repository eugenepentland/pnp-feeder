const std = @import("std");
const microzig = @import("microzig");
const SG90 = @import("devices/sg90.zig");
const LedStrip = @import("devices/ws2812_led.zig");

const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const Pwm = microzig.hal.pwm.Pwm;

pub var feeder: Feeder = undefined;

// --- Constants ---
const ACTIVE_LED_COLOR: LedStrip.Color = .{ .r = 1, .g = 1, .b = 1 };
const INACTIVE_LED_COLOR: LedStrip.Color = .{ .r = 0, .g = 0, .b = 0 };
const CHANNEL_READ_DELAY_MS: u32 = 2; // Delay for MUX settling

pub const SwitchState = enum(u3) {
    INSERTED_CH2 = 0,
    PWM_CH2 = 1,
    BTN_CH2 = 2,
    WC_CH2 = 3,
    WC_CH1 = 4,
    BTN_CH1 = 5,
    INSERTED_CH1 = 6,
    PWM_CH1 = 7,
};

// Enum to differentiate the logic type for the helper function
const SensorType = enum {
    button, // Active state is 0 (pressed)
    feeder, // Active state is 1 (inserted)
};

pub const Feeder = struct {
    servo: SG90,
    led_strip: LedStrip,
    ready_time: u64,
    response_sent: bool,
    switch_state: u3, // Note: This field seems unused after init? set_switch_state doesn't update it.
    sw_address_pin: [3]rp2040.gpio.Pin,
    gpio_pin: [8]rp2040.gpio.Pin,
    inserted_state: u16,
    button_state: u16,

    pub fn init() !Feeder {
        const led_strip = try LedStrip.init(0, 0, 23);
        const servo = SG90.init(26, 5, .a);

        const sw_address_pin = [3]rp2040.gpio.Pin{
            rp2040.gpio.num(3),
            rp2040.gpio.num(2),
            rp2040.gpio.num(1),
        };

        const gpio_pin = [8]rp2040.gpio.Pin{
            rp2040.gpio.num(0),
            rp2040.gpio.num(4),
            rp2040.gpio.num(5),
            rp2040.gpio.num(6),
            rp2040.gpio.num(7),
            rp2040.gpio.num(10),
            rp2040.gpio.num(11),
            rp2040.gpio.num(14),
        };

        // Initialize servo position
        _ = servo.set_level(250);
        time.sleep_ms(500); // Reduced sleep from 1000ms? Or adjust as needed.
        _ = servo.set_level(500);
        time.sleep_ms(500); // Allow settling time

        // Configure switch address pins as outputs
        for (sw_address_pin) |pin| {
            pin.set_function(.sio);
            pin.set_direction(.out);
        }

        // Configure GPIO pins as inputs (initial state)
        // Setting direction here simplifies the detection loops slightly
        for (gpio_pin) |pin| {
            pin.set_function(.sio);
            pin.set_direction(.in);
            // Optionally enable pull-ups/downs if needed, e.g.:
            // pin.pull_up_en(true); // If buttons connect to GND when pressed
        }

        return Feeder{
            .servo = servo,
            .led_strip = led_strip,
            .ready_time = 0,
            .response_sent = false,
            .switch_state = 0, // Initial state doesn't matter much if always set before read
            .sw_address_pin = sw_address_pin,
            .gpio_pin = gpio_pin,
            .inserted_state = 0, // Assume nothing inserted initially
            .button_state = 0xFFFF, // Assume all buttons released initially (state 1)
        };
    }

    /// Processes a single input channel (button or feeder sensor).
    /// Reads the pin state after setting the multiplexer, compares it to the
    /// current internal state, and updates the internal state and LED if changed.
    fn process_channel(
        self: *Feeder,
        pin: rp2040.gpio.Pin,
        switch_state_enum: SwitchState,
        state_variable_ptr: *u16, // Pointer to either button_state or inserted_state
        channel_index: usize, // The bit index (0-15)
        sensor_type: SensorType,
    ) void {
        // Set the multiplexer to the desired channel
        self.set_switch_state(switch_state_enum);
        // Wait for MUX and input signal to settle
        time.sleep_ms(CHANNEL_READ_DELAY_MS);

        // Read the current physical state of the pin
        const new_pin_state: u1 = pin.read();

        // Get the currently stored internal state for this channel
        const current_internal_bit = getBit(state_variable_ptr.*, channel_index);

        // Determine the target internal state bit based on the sensor type and pin reading.
        // Button: internal state 0 means pressed (pin read 0), 1 means released (pin read 1)
        // Feeder: internal state 1 means inserted (pin read 1), 0 means removed (pin read 0)
        // In both cases here, the target internal state matches the pin state.
        const target_internal_bit = new_pin_state;

        // Check if the state has actually changed
        if (target_internal_bit != current_internal_bit) {
            // Update the internal state variable
            state_variable_ptr.* = setBit(state_variable_ptr.*, channel_index, target_internal_bit);

            // Determine the "active" internal state bit for LED purposes
            const active_internal_bit = switch (sensor_type) {
                .button => @as(u1, 0), // Button LED is on when pressed (internal state 0)
                .feeder => @as(u1, 1), // Feeder LED is on when inserted (internal state 1)
            };

            // Set LED color based on whether the *new* internal state is the "active" state
            const color = if (target_internal_bit == active_internal_bit)
                ACTIVE_LED_COLOR
            else
                INACTIVE_LED_COLOR;

            self.led_strip.setLed(@intCast(channel_index), color);

            // Optional: Add logging for debugging state changes
            // std.log.debug("Channel {d} ({s}) changed: pin={d}, internal={d}, color={x}", .{
            //     channel_index, @tagName(sensor_type), new_pin_state, target_internal_bit, color
            // });
        }
    }

    pub fn detect_button(self: *Feeder) void {
        for (0.., self.gpio_pin) |i, pin| {
            // Process Channel 1 (index i*2)
            self.process_channel(
                pin,
                .BTN_CH1,
                &self.button_state,
                i * 2,
                .button,
            );

            // Process Channel 2 (index i*2 + 1)
            self.process_channel(
                pin,
                .BTN_CH2,
                &self.button_state,
                (i * 2) + 1,
                .button,
            );
        }
        // After processing all channels, update the physical LED strip
        // Assuming LedStrip needs an explicit update call. If not, remove this.
        // self.led_strip.show() catch |err| { std.log.err("Failed to update button LEDs: {}", .{err}); };
    }

    pub fn detect_feeder(self: *Feeder) void {
        for (0.., self.gpio_pin) |i, pin| {
            // Process Channel 1 (index i*2)
            self.process_channel(
                pin,
                .INSERTED_CH1,
                &self.inserted_state,
                i * 2,
                .feeder,
            );

            // Process Channel 2 (index i*2 + 1)
            self.process_channel(
                pin,
                .INSERTED_CH2,
                &self.inserted_state,
                (i * 2) + 1,
                .feeder,
            );
        }
        // After processing all channels, update the physical LED strip
        // Assuming LedStrip needs an explicit update call. If not, remove this.
        // self.led_strip.show() catch |err| { std.log.err("Failed to update feeder LEDs: {}", .{err}); };
    }

    /// Sets the multiplexer address pins based on the desired SwitchState.
    pub fn set_switch_state(self: *Feeder, state: SwitchState) void {
        // Note: Using u2 for index assumes sw_address_pin.len is at most 4.
        // Using @intFromEnum directly assumes the enum values match the desired pin states.
        const state_value = @intFromEnum(state);
        if (state_value == self.switch_state) return;

        for (0..self.sw_address_pin.len, self.sw_address_pin) |i, pin| {
            // Extract the i-th bit from the state enum's integer value
            const bit_value: u1 = @intCast((state_value >> @as(u2, @intCast(i))) & 1);
            pin.put(bit_value);
        }
        // Consider updating self.switch_state here if it's meant to track the current MUX setting
        self.switch_state = state_value;
    }

    pub fn rotate_servo(self: *Feeder, angle: u16) !void {
        // Turn on the PWM signal and return how long it will take to complete the movement
        const sleep_ms = self.servo.set_level(angle);
        std.log.info("Rotating servo to level: {d} (estimated duration: {d}ms)", .{ angle, sleep_ms });

        // Set the time at which it can move again (time is in microseconds)
        const sleep_us: u64 = @as(u64, sleep_ms) * 1000;
        const now_us: u64 = time.get_time_since_boot().to_us();

        // Update the time at which a new message can be recieved
        self.ready_time = now_us + sleep_us;
    }
};

// --- Bit Manipulation Helpers --- (Keep these as they are generally useful)

/// Gets the bit value at a specific index within an integer.
pub fn getBit(value: anytype, index: anytype) u1 {
    const ValueType = @TypeOf(value);
    const ShiftAmountType = std.math.Log2Int(ValueType); // Type for shift amount
    const shift_amount = @as(ShiftAmountType, @intCast(index));
    const shifted_value = value >> shift_amount;
    return @truncate(shifted_value & 1); // Use @truncate for explicit u1 conversion
}

/// Sets the bit value at a specific index within an integer and returns the new value.
pub fn setBit(value: anytype, index: anytype, new_bit_value: u1) @TypeOf(value) {
    const ValueType = @TypeOf(value);
    const ShiftAmountType = std.math.Log2Int(ValueType);
    const shift_amount = @as(ShiftAmountType, @intCast(index));
    const mask = (@as(ValueType, 1) << shift_amount);

    return if (new_bit_value == 1) (value | mask) else (value & ~mask);
}
