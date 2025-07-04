const std = @import("std");
const VGA_MEMORY = @as(*volatile [25 * 80]u16, @ptrFromInt(0xB8000));

// Expanded color palette
const VGA_COLOR = struct {
    const BLACK = 0;
    const BLUE = 1;
    const GREEN = 2;
    const CYAN = 3;
    const RED = 4;
    const MAGENTA = 5;
    const BROWN = 6;
    const LIGHT_GRAY = 7;
    const DARK_GRAY = 8;
    const LIGHT_BLUE = 9;
    const LIGHT_GREEN = 10;
    const LIGHT_CYAN = 11;
    const LIGHT_RED = 12;
    const LIGHT_MAGENTA = 13;
    const YELLOW = 14;
    const WHITE = 15;
};

fn vga_entry_color(fg: u8, bg: u8) u8 {
    return fg | (bg << 4);
}

fn vga_entry(uc: u8, color: u8) u16 {
    return @as(u16, uc) | (@as(u16, color) << 8);
}

/// Clears the VGA screen with the specified color
pub fn clear_screen(fg: u8, bg: u8) void {
    const entry = vga_entry(' ', vga_entry_color(fg, bg));
    for (0..25 * 80) |i| {
        VGA_MEMORY[i] = entry;
    }
}

/// More precise delay function using CPU cycles
fn delay(cycles: usize) void {
    var i: usize = 0;
    while (i < cycles) : (i += 1) {
        @import("std").mem.doNotOptimizeAway(i);
    }
}

/// Draws a string at a specific position with color
fn draw_string(row: usize, col: usize, str: []const u8, fg: u8, bg: u8) void {
    const color = vga_entry_color(fg, bg);
    for (str, 0..) |char, i| {
        VGA_MEMORY[row * 80 + col + i] = vga_entry(char, color);
    }
}

pub fn play_boot_animation() void {
    const logo = [_][]const u8{
        "\x04\x0F\x04\x0F\x04  Z I R O N O S  \x0F\x04\x0F\x04\x0F",
    };
    const version = "ZironOS v0.2.0";
    const byline = "One of its kind, Zig based Operating System";

    clear_screen(VGA_COLOR.LIGHT_GRAY, VGA_COLOR.BLACK);

    const logo_row = (25 - logo.len) / 2;
    for (logo, 0..) |line, i| {
        const col = (80 - line.len) / 2;
        draw_string(logo_row + i, col, line, VGA_COLOR.LIGHT_CYAN, VGA_COLOR.BLACK);
    }

    // Version (centered, below logo)
    const version_row = logo_row + logo.len + 1;
    const version_col = (80 - version.len) / 2;
    draw_string(version_row, version_col, version, VGA_COLOR.LIGHT_GRAY, VGA_COLOR.BLACK);

    // Byline (centered, below version)
    const byline_row = version_row + 1;
    const byline_col = (80 - byline.len) / 2;
    draw_string(byline_row, byline_col, byline, VGA_COLOR.DARK_GRAY, VGA_COLOR.BLACK);

    delay(10_000_000); // Adjusted delay for smoother animation
}
