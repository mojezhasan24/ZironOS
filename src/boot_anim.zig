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
    const lines = [_][]const u8{
        "        ______  _              ____   _____ ",
        "       |___  / | |            / __ \\ / ____|",
        "          / /__| |_   ___    | |  | | (___  ",
        "         / /_  | | | | \\ \\ /\\ / /| |\\___ \\ ",
        "        / /__| | |_| | |\\ V  V / |_| |____) |",
        "       /_____|_|\\__,_|_| \\_/\\_/\\___/|_____/ ",
    };

    // Clear screen with black background
    clear_screen(VGA_COLOR.LIGHT_GRAY, VGA_COLOR.BLACK);

    // Animation parameters
    const start_row = 5;
    const delay_between_lines = 50_000_000;
    const delay_between_chars = 1_000_000;
    const color_cycle = [_]u8{
        VGA_COLOR.LIGHT_BLUE,
        VGA_COLOR.LIGHT_CYAN,
        VGA_COLOR.LIGHT_GREEN,
        VGA_COLOR.LIGHT_MAGENTA,
        VGA_COLOR.YELLOW,
        VGA_COLOR.LIGHT_RED,
    };

    // Draw each line with animation
    for (lines, 0..) |line, line_idx| {
        const row = start_row + line_idx;
        const color = color_cycle[line_idx % color_cycle.len];

        // Character-by-character animation
        for (0..line.len) |col| {
            draw_string(row, col, line[col .. col + 1], color, VGA_COLOR.BLACK);
            delay(delay_between_chars);
        }

        delay(delay_between_lines);
    }

    // Final flourish - flash the logo
    for (0..3) |_| {
        for (lines, 0..) |line, line_idx| {
            const row = start_row + line_idx;
            draw_string(row, 0, line, VGA_COLOR.WHITE, VGA_COLOR.BLACK);
        }
        delay(delay_between_lines * 2);

        for (lines, 0..) |line, line_idx| {
            const row = start_row + line_idx;
            const color = color_cycle[line_idx % color_cycle.len];
            draw_string(row, 0, line, color, VGA_COLOR.BLACK);
        }
        delay(delay_between_lines * 2);
    }
}
