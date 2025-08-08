const vga = @import("terminal.zig");
const std = @import("std");

pub const File = struct {
    name: []const u8,
    data: []const u8,
};

pub const files = [_]File{
    .{ .name = "hello.txt", .data = "Hello, from Ziron!\n" },
    .{ .name = "readme.txt", .data = "Welcome to Ziron OS!\n" },
    
};

pub fn list_files() void {
    for (files) |file| {
        vga.terminal_write(file.name);
        vga.terminal_write("\n");
    }
}

pub fn read_file(name: []const u8) ?[]const u8 {
    for (files) |file| {
        if (std.mem.eql(u8, file.name, name)) {
            return file.data;
        }
    }
    return null;
}
