const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "zironos",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add the assembly boot file
    kernel.addAssemblyFile(.{ .path = "src/boot.s" });

    // Use our custom linker script
    kernel.setLinkerScriptPath(.{ .path = "linker.ld" });
    kernel.addAssemblyFile(.{ .path = "src/isr.s" });
    // Disable strip for debugging
    kernel.strip = false;

    // Disable red zone for kernel mode
    kernel.red_zone = false;

    b.installArtifact(kernel);

    // ISO creation step
    const iso_step = b.step("iso", "Create bootable ISO image");

    const copy_kernel = b.addSystemCommand(&[_][]const u8{ "cp", b.getInstallPath(.bin, "zironos"), "iso_root/zironos" });
    copy_kernel.step.dependOn(b.getInstallStep());

    const make_iso = b.addSystemCommand(&[_][]const u8{ "grub-mkrescue", "-o", "zironos.iso", "iso_root" });
    make_iso.step.dependOn(&copy_kernel.step);

    iso_step.dependOn(&make_iso.step);
}
