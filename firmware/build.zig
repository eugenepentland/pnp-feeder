const std = @import("std");
const MicroZig = @import("microzig/build");
const rp2040 = @import("microzig/bsp/raspberrypi/rp2040");

const available_examples = [_]Example{
    .{ .target = rp2040.boards.raspberrypi.pico, .name = "main", .file = "src/main.zig" },
};

pub fn build(b: *std.Build) void {
    const mz = MicroZig.init(b, .{});
    const optimize = b.standardOptimizeOption(.{});

    for (available_examples) |example| {
        const firmware = mz.add_firmware(b, .{
            .name = example.name,
            .target = example.target,
            .optimize = optimize,
            .root_source_file = b.path(example.file),
        });

        // Install the firmware
        mz.install_firmware(b, firmware, .{});

        // Add a custom build step to run the Python script after the firmware is installed
        const reboot_cmd = b.addSystemCommand(&[_][]const u8{
            "python",
            "src/reboot.py",
        });

        // Make the reboot command depend on the firmware's install step
        //reboot_cmd.step.dependOn(b.getInstallStep());

        // Ensure the default build step includes the reboot command
        b.default_step.dependOn(&reboot_cmd.step);
    }
}

const Example = struct {
    target: MicroZig.Target,
    name: []const u8,
    file: []const u8,
};
