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

        // Create the run application
        const target = b.standardTargetOptions(.{});

        const exe = b.addExecutable(.{
            .name = "RunBootloader",
            .root_source_file = b.path("src/tools/serial.zig"),
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);

        // Run the run app
        const run_cmd = b.addRunArtifact(exe);

        const snek = b.dependency("serial", .{});
        exe.root_module.addImport("serial", snek.module("serial"));

        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("flash", "Flash the firmware");
        run_step.dependOn(&run_cmd.step);
    }
}

const Example = struct {
    target: MicroZig.Target,
    name: []const u8,
    file: []const u8,
};
