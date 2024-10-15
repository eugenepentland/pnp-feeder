pub fn save_step_count(step_count: u32, comptime flash: type, flash_target_offset: u32) void {
    // Clear the block before writing the data
    flash.range_erase(flash_target_offset, flash.SECTOR_SIZE);

    // Prepare data to program (must be a whole number of pages)
    var data: [flash.PAGE_SIZE]u8 = [_]u8{0xFF} ** flash.PAGE_SIZE;

    // Convert the u32 to a u8 array
    data[3] = @truncate((step_count >> 24) & 0xff);
    data[2] = @truncate((step_count >> 16) & 0xff);
    data[1] = @truncate((step_count >> 8) & 0xff);
    data[0] = @truncate((step_count) & 0xff);

    // Write the data
    flash.range_program(flash_target_offset, data[0..flash.PAGE_SIZE]);
}

pub fn load_step_count(flash_target_offset: u32, comptime flash: type) u32 {
    const i = @as(*const u32, @ptrFromInt(flash.XIP_BASE + flash_target_offset));
    return i.*;
}

pub fn rotate_servo(servo: anytype, time: anytype, previous_angle: f32, angle: f32, speed: u16) void {
    const level: f32 = (5.4 * angle) + 250;
    servo.set_level(@intFromFloat(level));
    const sleep_time: u16 = @intFromFloat(@abs(angle - previous_angle) * 1.8);
    time.sleep_ms(100 * sleep_time / speed);
}
