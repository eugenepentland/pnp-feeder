const std = @import("std");
const MicroZig = @import("microzig/build");
const rp2040 = @import("microzig/port/raspberrypi/rp2xxx");

const available_examples = [_]Example{
    .{ .target = rp2040.boards.raspberrypi.pico, .name = "main", .file = "src/main.zig" },
};

pub fn build(b: *std.Build) void {
    const mz = MicroZig.init(b, .{});
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    for (available_examples) |example| {
        build_firmware(b, mz, example, optimize);
        build_flash_firmware(b, optimize, target);
        build_debug_app(b, optimize, target);
        build_echo_app(b, optimize, target);
    }
}

fn build_firmware(b: *std.Build, mz: *MicroZig, example: Example, optimize: std.builtin.OptimizeMode) void {
    const firmware = mz.add_firmware(b, .{
        .name = example.name,
        .target = example.target,
        .optimize = optimize,
        .root_source_file = b.path(example.file),
    });

    mz.install_firmware(b, firmware, .{});
}

fn build_flash_firmware(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) void {
    const exe = b.addExecutable(.{
        .name = "FlashFirmware",
        .root_source_file = b.path("src/tools/flash.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const serial = b.dependency("serial", .{});
    exe.root_module.addImport("serial", serial.module("serial"));

    const run_step = b.step("flash", "Flash the firmware");
    run_step.dependOn(&run_cmd.step);
}

fn build_echo_app(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) void {
    const exe = b.addExecutable(.{
        .name = "Echo",
        .root_source_file = b.path("src/tools/echo.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const serial = b.dependency("serial", .{});
    exe.root_module.addImport("serial", serial.module("serial"));

    const run_step = b.step("echo", "Flash the firmware");
    run_step.dependOn(&run_cmd.step);
}

fn build_debug_app(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget) void {
    const exe2 = b.addExecutable(.{
        .name = "debug",
        .root_source_file = b.path("src/tools/serial_debug.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe2);

    const run_cmd2 = b.addRunArtifact(exe2);

    const run_step2 = b.step("debug", "Start serial debug");
    run_step2.dependOn(&run_cmd2.step);

    const serial = b.dependency("serial", .{});
    exe2.root_module.addImport("serial", serial.module("serial"));
}

const Example = struct {
    target: MicroZig.Target,
    name: []const u8,
    file: []const u8,
};
