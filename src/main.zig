const std = @import("std");
const idt = @import("idt.zig");

// VGA text mode constants
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_MEMORY = @as(*volatile [VGA_HEIGHT * VGA_WIDTH]u16, @ptrFromInt(0xB8000));

// VGA colors
const VGA_COLOR_BLACK = 0;
const VGA_COLOR_BLUE = 1;
const VGA_COLOR_GREEN = 2;
const VGA_COLOR_CYAN = 3;
const VGA_COLOR_RED = 4;
const VGA_COLOR_MAGENTA = 5;
const VGA_COLOR_BROWN = 6;
const VGA_COLOR_LIGHT_GREY = 7;
const VGA_COLOR_DARK_GREY = 8;
const VGA_COLOR_LIGHT_BLUE = 9;
const VGA_COLOR_LIGHT_GREEN = 10;
const VGA_COLOR_LIGHT_CYAN = 11;
const VGA_COLOR_LIGHT_RED = 12;
const VGA_COLOR_LIGHT_MAGENTA = 13;
const VGA_COLOR_LIGHT_BROWN = 14;
const VGA_COLOR_WHITE = 15;

// Alias for yellow
const VGA_COLOR_YELLOW = VGA_COLOR_LIGHT_BROWN;

var terminal_row: u8 = 0;
var terminal_column: u8 = 0;
var terminal_color: u8 = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);

fn vga_entry_color(fg: u8, bg: u8) u8 {
    return fg | (bg << 4);
}

fn vga_entry(uc: u8, color: u8) u16 {
    return @as(u16, uc) | (@as(u16, color) << 8);
}

fn terminal_initialize() void {
    var y: u8 = 0;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: u8 = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            const index = @as(usize, y) * VGA_WIDTH + x;
            VGA_MEMORY[index] = vga_entry(' ', terminal_color);
        }
    }
    terminal_row = 0;
    terminal_column = 0;
}
extern fn isr0() callconv(.Naked) void;

pub fn initIDT() void {
    const CODE_SELECTOR: u16 = 0x08; // From GDT (we’ll fix GDT later)
    const isr_addr = @intFromPtr(@as([*]const u8, @ptrCast(&isr0)));
    idt.idt[0] = idt.IDTEntry.init(isr_addr, CODE_SELECTOR, 0x8E);
    // Present, Ring 0, Interrupt Gate
    idt.loadIDT();
}

fn terminal_putentryat(c: u8, color: u8, x: u8, y: u8) void {
    const index = @as(usize, y) * VGA_WIDTH + x;
    VGA_MEMORY[index] = vga_entry(c, color);
}

fn terminal_putchar(c: u8) void {
    if (c == '\n') {
        terminal_column = 0;
        if (terminal_row < VGA_HEIGHT - 1) {
            terminal_row += 1;
        }
        return;
    }

    terminal_putentryat(c, terminal_color, terminal_column, terminal_row);
    terminal_column += 1;
    if (terminal_column == VGA_WIDTH) {
        terminal_column = 0;
        if (terminal_row < VGA_HEIGHT - 1) {
            terminal_row += 1;
        }
    }
}

fn terminal_write(data: []const u8) void {
    for (data) |c| {
        terminal_putchar(c);
    }
}

// Inline assembly functions for keyboard input
fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

export fn main() noreturn {
    // Initialize VGA text mode
    terminal_initialize();
    initIDT(); // after terminal init

    // Print startup messages
    terminal_color = vga_entry_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK);
    terminal_write("ZironOS v0.1.0\n");

    terminal_color = vga_entry_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
    terminal_write("Kernel loaded successfully!\n");

    terminal_color = vga_entry_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    terminal_write("64-bit x86_64 kernel running\n");

    terminal_color = vga_entry_color(VGA_COLOR_YELLOW, VGA_COLOR_BLACK);
    terminal_write("Press keys (ESC to halt):\n");

    terminal_color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);

    // Simple keyboard input loop
    while (true) {
        // Check if keyboard data is available
        const status = inb(0x64);
        if ((status & 1) != 0) {
            const scancode = inb(0x60);

            // ESC key to exit
            if (scancode == 0x01) {
                terminal_write("\nHalting...\n");
                break;
            } else if (scancode < 0x80) { // Key press (not release)
                // Simple scancode to ASCII conversion
                var ascii_char: u8 = '?';
                switch (scancode) {
                    0x1E => ascii_char = 'a',
                    0x30 => ascii_char = 'b',
                    0x2E => ascii_char = 'c',
                    0x20 => ascii_char = 'd',
                    0x12 => ascii_char = 'e',
                    0x21 => ascii_char = 'f',
                    0x22 => ascii_char = 'g',
                    0x23 => ascii_char = 'h',
                    0x17 => ascii_char = 'i',
                    0x24 => ascii_char = 'j',
                    0x25 => ascii_char = 'k',
                    0x26 => ascii_char = 'l',
                    0x32 => ascii_char = 'm',
                    0x31 => ascii_char = 'n',
                    0x18 => ascii_char = 'o',
                    0x19 => ascii_char = 'p',
                    0x10 => ascii_char = 'q',
                    0x13 => ascii_char = 'r',
                    0x1F => ascii_char = 's',
                    0x14 => ascii_char = 't',
                    0x16 => ascii_char = 'u',
                    0x2F => ascii_char = 'v',
                    0x11 => ascii_char = 'w',
                    0x2D => ascii_char = 'x',
                    0x15 => ascii_char = 'y',
                    0x2C => ascii_char = 'z',
                    0x39 => ascii_char = ' ',
                    0x1C => ascii_char = '\n',
                    else => {},
                }
                terminal_putchar(ascii_char);
            }
        }

        // Small CPU pause
        asm volatile ("pause");
    }

    // Infinite HLT loop
    while (true) {
        asm volatile ("hlt");
    }
}
