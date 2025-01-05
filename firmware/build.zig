const std = @import("std");
const microzig = @import("microzig");

const MicroBuild = microzig.MicroBuild(.{
    .rp2xxx = true,
});

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });
    const target = b.standardTargetOptions(.{});

    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const available_examples = [_]Example{
        .{ .target = mb.ports.rp2xxx.boards.raspberrypi.pico, .name = "main", .file = "src/main.zig" },
    };

    for (available_examples) |example| {
        // Build the firmware
        const firmware = mb.add_firmware(.{
            .name = example.name,
            .target = example.target,
            .optimize = optimize,
            .root_source_file = b.path(example.file),
        });

        // Install the firmware
        mb.install_firmware(firmware, .{});
        mb.install_firmware(firmware, .{ .format = .elf });

        build_flash_firmware(b, optimize, target);
    }
}

fn build_flash_firmware(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) void {
    const exe = b.addExecutable(.{
        .name = "FlashFirmware",
        .root_source_file = b.path("src/flash.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const modbus = b.dependency("modbus", .{});
    exe.root_module.addImport("modbus", modbus.module("modbus"));

    const serial = b.dependency("serial", .{});
    exe.root_module.addImport("serial", serial.module("serial"));
    const name = "main.uf2";
    // Make the flash step depend on the specific firmware being built
    const run_step = b.step("flash", std.fmt.allocPrint(b.allocator, "Flash the {s} firmware", .{name}) catch unreachable);
    run_step.dependOn(&run_cmd.step);
}

const Example = struct {
    target: *const microzig.Target,
    name: []const u8,
    file: []const u8,
};
