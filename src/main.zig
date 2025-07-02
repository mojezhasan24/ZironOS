const std = @import("std");
const idt = @import("idt.zig");
const io = @import("io.zig");
const boot_anim = @import("boot_anim.zig");
var extended_scancode: bool = false;
var awaiting_extended: bool = false;

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

const VGA_COLOR_YELLOW = VGA_COLOR_LIGHT_BROWN;

// Keyboard state tracking
var shift_pressed: bool = false;
var ctrl_pressed: bool = false;
var alt_pressed: bool = false;
var caps_lock: bool = false;
var num_lock: bool = true;
var scroll_lock: bool = false;

// Terminal state
var terminal_row: u8 = 0;
var terminal_column: u8 = 0;
var terminal_color: u8 = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
var cursor_visible: bool = true;
var cursor_blink_counter: u32 = 0;
var saved_cursor_row: u8 = 0;
var saved_cursor_col: u8 = 0;

// Command buffer for basic shell functionality
var command_buffer: [256]u8 = [_]u8{0} ** 256;
var command_length: u8 = 0;
var command_history: [10][256]u8 = [_][256]u8{[_]u8{0} ** 256} ** 10;
var history_count: u8 = 0;
var history_index: u8 = 0;
fn clear_line() void {
    terminal_row -= 0;
    terminal_column = 0;
    for (0..VGA_WIDTH) |i| {
        terminal_putentryat(' ', terminal_color, @truncate(i), terminal_row);
    }
    update_cursor();
}

// Screen buffer for scrolling
var screen_buffer: [VGA_HEIGHT][VGA_WIDTH]u16 = [_][VGA_WIDTH]u16{[_]u16{0} ** VGA_WIDTH} ** VGA_HEIGHT;

fn vga_entry_color(fg: u8, bg: u8) u8 {
    return fg | (bg << 4);
}

fn vga_entry(uc: u8, color: u8) u16 {
    return @as(u16, uc) | (@as(u16, color) << 8);
}

fn update_cursor() void {
    if (!cursor_visible) {
        // Hide cursor by moving it off-screen
        outb(0x3D4, 0x0F);
        outb(0x3D5, 0xFF);
        outb(0x3D4, 0x0E);
        outb(0x3D5, 0xFF);
        return;
    }

    const pos = @as(u16, terminal_row) * VGA_WIDTH + terminal_column;

    // Cursor low byte
    outb(0x3D4, 0x0F);
    outb(0x3D5, @truncate(pos & 0xFF));

    // Cursor high byte
    outb(0x3D4, 0x0E);
    outb(0x3D5, @truncate((pos >> 8) & 0xFF));
}

fn scroll_up() void {
    // Move all lines up by one
    var y: u8 = 1;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: u8 = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            const src_index = @as(usize, y) * VGA_WIDTH + x;
            const dst_index = @as(usize, y - 1) * VGA_WIDTH + x;
            VGA_MEMORY[dst_index] = VGA_MEMORY[src_index];
            screen_buffer[y - 1][x] = screen_buffer[y][x];
        }
    }

    // Clear bottom line
    var x: u8 = 0;
    while (x < VGA_WIDTH) : (x += 1) {
        const index = @as(usize, VGA_HEIGHT - 1) * VGA_WIDTH + x;
        VGA_MEMORY[index] = vga_entry(' ', terminal_color);
        screen_buffer[VGA_HEIGHT - 1][x] = vga_entry(' ', terminal_color);
    }

    terminal_row = VGA_HEIGHT - 1;
}

fn terminal_initialize() void {
    var y: u8 = 0;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: u8 = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            const index = @as(usize, y) * VGA_WIDTH + x;
            const entry = vga_entry(' ', terminal_color);
            VGA_MEMORY[index] = entry;
            screen_buffer[y][x] = entry;
        }
    }
    terminal_row = 0;
    terminal_column = 0;
    update_cursor();
}

extern fn isr0() callconv(.Naked) void;

pub fn initIDT() void {
    const CODE_SELECTOR: u16 = 0x08;
    const isr_addr = @intFromPtr(@as([*]const u8, @ptrCast(&isr0)));
    idt.idt[0] = idt.IDTEntry.init(isr_addr, CODE_SELECTOR, 0x8E);
    idt.loadIDT();
}

fn terminal_putentryat(c: u8, color: u8, x: u8, y: u8) void {
    const index = @as(usize, y) * VGA_WIDTH + x;
    const entry = vga_entry(c, color);
    VGA_MEMORY[index] = entry;
    screen_buffer[y][x] = entry;
}

fn terminal_putchar(c: u8) void {
    switch (c) {
        '\n' => {
            terminal_column = 0;
            if (terminal_row >= VGA_HEIGHT - 1) {
                scroll_up();
            } else {
                terminal_row += 1;
            }
        },
        '\r' => {
            terminal_column = 0;
        },
        '\t' => {
            const tab_size = 4;
            const spaces_to_add = tab_size - (terminal_column % tab_size);
            var i: u8 = 0;
            while (i < spaces_to_add and terminal_column < VGA_WIDTH) : (i += 1) {
                terminal_putentryat(' ', terminal_color, terminal_column, terminal_row);
                terminal_column += 1;
            }
        },
        8 => { // Backspace
            if (terminal_column > 0) {
                terminal_column -= 1;
                terminal_putentryat(' ', terminal_color, terminal_column, terminal_row);
            } else if (terminal_row > 0) {
                terminal_row -= 1;
                terminal_column = VGA_WIDTH - 1;
                terminal_putentryat(' ', terminal_color, terminal_column, terminal_row);
            }
        },
        else => {
            terminal_putentryat(c, terminal_color, terminal_column, terminal_row);
            terminal_column += 1;
            if (terminal_column >= VGA_WIDTH) {
                terminal_column = 0;
                if (terminal_row >= VGA_HEIGHT - 1) {
                    scroll_up();
                } else {
                    terminal_row += 1;
                }
            }
        },
    }
    update_cursor();
}

fn terminal_write(data: []const u8) void {
    for (data) |c| {
        terminal_putchar(c);
    }
}

fn terminal_writenum(num: u32) void {
    if (num == 0) {
        terminal_putchar('0');
        return;
    }

    var buffer: [10]u8 = undefined;
    var i: u8 = 0;
    var n = num;

    while (n > 0) {
        buffer[i] = @truncate((n % 10) + '0');
        n /= 10;
        i += 1;
    }

    while (i > 0) {
        i -= 1;
        terminal_putchar(buffer[i]);
    }
}

fn clear_screen() void {
    terminal_initialize();
}

fn set_color(fg: u8, bg: u8) void {
    terminal_color = vga_entry_color(fg, bg);
}

// I/O functions
fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}

fn outb(port: u16, data: u8) void {
    asm volatile ("outb %[data], %[port]"
        :
        : [data] "{al}" (data),
          [port] "N{dx}" (port),
    );
}

// Enhanced scancode to ASCII conversion
fn scancode_to_ascii(scancode: u8) u8 {
    const base_chars = [_]u8{
        0, 0, '1', '2', '3', '4', '5', '6', '7', '8', // 0x00-0x09
        '9', '0', '-', '=', 8, '\t', 'q', 'w', 'e', 'r', // 0x0A-0x13
        't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', 0, // 0x14-0x1D
        'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', // 0x1E-0x27
        '\'', '`', 0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', // 0x28-0x31
        'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0, // 0x32-0x3B
    };

    const shift_chars = [_]u8{
        0, 0, '!', '@', '#', '$', '%', '^', '&', '*', // 0x00-0x09
        '(', ')', '_', '+', 8, '\t', 'Q', 'W', 'E', 'R', // 0x0A-0x13
        'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0, // 0x14-0x1D
        'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', // 0x1E-0x27
        '"', '~', 0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', // 0x28-0x31
        'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0, // 0x32-0x3B
    };

    if (scancode >= base_chars.len) return 0;

    var c: u8 = 0;
    if (shift_pressed) {
        c = shift_chars[scancode];
    } else {
        c = base_chars[scancode];
    }

    // Handle caps lock for letters
    if (caps_lock and c >= 'a' and c <= 'z') {
        c = c - 'a' + 'A';
    } else if (caps_lock and c >= 'A' and c <= 'Z' and !shift_pressed) {
        c = c - 'A' + 'a';
    }

    return c;
}

fn process_command() void {
    // Null terminate command
    command_buffer[command_length] = 0;

    // Add to history
    if (command_length > 0 and history_count < 10) {
        var i: u8 = 0;
        while (i <= command_length) : (i += 1) {
            command_history[history_count][i] = command_buffer[i];
        }
        history_count += 1;
    }

    terminal_putchar('\n');

    // Process built-in commands
    const trimmed = trim_spaces(command_buffer[0..command_length]);
    if (std.mem.eql(u8, trimmed, "help")) {
        set_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK);
        terminal_write("ZironOS Built-in Commands:\n");
        set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
        terminal_write("  help     - Show this help\n");
        terminal_write("  clear    - Clear screen\n");
        terminal_write("  version  - Show OS version\n");
        terminal_write("  time     - Show system uptime\n");
        terminal_write("  colors   - Test color palette\n");
        terminal_write("  echo     - Echo arguments\n");
        terminal_write("  halt     - Shutdown system\n");
        terminal_write("  exit     - Exit/halt system\n");
    } else if (std.mem.eql(u8, trimmed, "clear")) {
        clear_screen();
    } else if (std.mem.eql(u8, trimmed, "version")) {
        set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
        terminal_write("ZironOS v0.2.0 Advanced Edition\n");
        terminal_write("32-bit x86 Kernel with Enhanced Features\n");
    } else if (std.mem.eql(u8, trimmed, "colors")) {
        var color: u8 = 0;
        while (color < 16) : (color += 1) {
            set_color(color, VGA_COLOR_BLACK);
            terminal_write("Color ");
            terminal_writenum(color);
            terminal_write(" ");
        }
        terminal_putchar('\n');
    } else if (std.mem.startsWith(u8, command_buffer[0..command_length], "echo ")) {
        const args = command_buffer[5..command_length];
        terminal_write(args);
        terminal_putchar('\n');
    } else if (std.mem.eql(u8, command_buffer[0..command_length], "halt")) {
        set_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK);
        terminal_write("System halting...\n");
        while (true) asm volatile ("hlt");
    } else if (std.mem.eql(u8, command_buffer[0..command_length], "exit")) { // <-- Added block
        set_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK);
        terminal_write("Exiting ZironOS...\n");
        while (true) asm volatile ("hlt");
    } else if (command_length > 0) {
        set_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK);
        terminal_write("Unknown command: ");
        terminal_write(command_buffer[0..command_length]);
        terminal_write("\nType 'help' for available commands.\n");
    }

    // Reset for next command
    set_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);
    command_length = 0;
    history_index = history_count;

    // Show prompt
    set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
    terminal_write("ZironOS> ");
    set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
}
fn trim_spaces(input: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = input.len;

    while (start < end and input[start] == ' ') : (start += 1) {}
    while (end > start and input[end - 1] == ' ') : (end -= 1) {}

    return input[start..end];
}

export fn main() noreturn {
    boot_anim.play_boot_animation();
    terminal_initialize();
    initIDT();

    set_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK);
    terminal_write("==================================\n");
    terminal_write("    ZironOS v0.2.0\n");
    terminal_write("==================================\n\n");

    set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
    terminal_write("Type 'help' for available commands.\n");

    set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
    terminal_write("ZironOS> ");
    set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);

    while (true) {
        const status = inb(0x64);
        if ((status & 1) != 0) {
            const raw = inb(0x60);

            // Handle multi-byte scancodes (extended keys)
            if (raw == 0xE0) {
                awaiting_extended = true;
                continue;
            }

            if ((raw & 0x80) != 0) {
                // Key release
                const release = raw & 0x7F;
                switch (release) {
                    0x2A, 0x36 => shift_pressed = false,
                    0x1D => ctrl_pressed = false,
                    0x38 => alt_pressed = false,
                    else => {},
                }
                awaiting_extended = false; // Reset on release
                continue;
            }

            if (awaiting_extended) {
                awaiting_extended = false;
                switch (raw) {
                    0x48 => { // ↑ Up
                        if (history_index > 0) {
                            history_index -= 1;
                            command_length = 0;
                            // Clear the line (prompt + command)
                            clear_line();
                            set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
                            terminal_write("ZironOS> ");
                            set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
                            // Copy and redraw command from history
                            while (command_history[history_index][command_length] != 0 and command_length < 255) : (command_length += 1) {
                                command_buffer[command_length] = command_history[history_index][command_length];
                            }
                            command_buffer[command_length] = 0;
                            terminal_write(command_buffer[0..command_length]);
                        }
                    },
                    0x50 => { // ↓ Down
                        if (history_index + 1 < history_count) {
                            history_index += 1;
                            command_length = 0;
                            clear_line();
                            set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
                            terminal_write("ZironOS> ");
                            set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
                            while (command_history[history_index][command_length] != 0 and command_length < 255) : (command_length += 1) {
                                command_buffer[command_length] = command_history[history_index][command_length];
                            }
                            command_buffer[command_length] = 0;
                            terminal_write(command_buffer[0..command_length]);
                        } else {
                            clear_line();
                            set_color(VGA_COLOR_LIGHT_GREEN, VGA_COLOR_BLACK);
                            terminal_write("ZironOS> ");
                            set_color(VGA_COLOR_WHITE, VGA_COLOR_BLACK);
                            command_length = 0;
                            command_buffer[0] = 0;
                        }
                    },
                    0x4B => terminal_write("[←]"),
                    0x4D => terminal_write("[→]"),
                    else => {},
                }
                continue;
            }

            switch (raw) {
                0x01 => {
                    set_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK);
                    terminal_write("\n\nESC pressed - System halting...\n");
                    while (true) asm volatile ("hlt");
                },
                0x2A, 0x36 => shift_pressed = true,
                0x1D => ctrl_pressed = true,
                0x38 => alt_pressed = true,
                0x3A => caps_lock = !caps_lock,
                0x45 => num_lock = !num_lock,
                0x46 => scroll_lock = !scroll_lock,
                else => {
                    if (ctrl_pressed and raw == 0x2E) {
                        set_color(VGA_COLOR_LIGHT_RED, VGA_COLOR_BLACK);
                        terminal_write("^C\n");
                        command_length = 0;
                        process_command();
                        continue;
                    }

                    const ascii_char = scancode_to_ascii(raw);
                    if (ascii_char != 0) {
                        if (ascii_char == '\n') {
                            process_command();
                        } else if (ascii_char == 8) {
                            if (command_length > 0) {
                                command_length -= 1;
                                terminal_putchar(8);
                                terminal_putchar(' ');
                                terminal_putchar(8);
                            }
                        } else if (command_length < 255) {
                            command_buffer[command_length] = ascii_char;
                            command_length += 1;
                            terminal_putchar(ascii_char);
                        }
                    }
                },
            }
        }

        cursor_blink_counter += 1;
        if (cursor_blink_counter > 100000) {
            cursor_blink_counter = 0;
            cursor_visible = !cursor_visible;
            update_cursor();
        }

        asm volatile ("pause");
    }
}
