const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_MEMORY = @as(*volatile [VGA_WIDTH * VGA_HEIGHT]u16, @ptrFromInt(0xB8000));
var terminal_row: u8 = 0;
var terminal_column: u8 = 0;
var terminal_color: u8 = 0x07; // Light grey on black

fn vga_entry(c: u8, color: u8) u16 {
    return @as(u16, c) | (@as(u16, color) << 8);
}

pub fn terminal_write(s: []const u8) void {
    for (s) |c| {
        if (c == '\n') {
            terminal_row += 1;
            terminal_column = 0;
        } else {
            const idx = @as(usize, terminal_row) * VGA_WIDTH + terminal_column;
            VGA_MEMORY[idx] = vga_entry(c, terminal_color);
            terminal_column += 1;
            if (terminal_column >= VGA_WIDTH) {
                terminal_column = 0;
                terminal_row += 1;
            }
        }
        if (terminal_row >= VGA_HEIGHT) {
            terminal_row = 0;
        }
    }
}
