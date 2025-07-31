const io = @import("io.zig");
const std = @import("std");

pub const MouseState = struct {
    x: i16,
    y: i16,
    buttons: u8,
};

pub var mouse_state: MouseState = .{
    .x = 40, // Start at center of screen
    .y = 12,
    .buttons = 0,
};

var packet: [3]u8 = undefined;
var packet_stage: u8 = 0;

// Mouse initialization sequence
pub fn mouse_init() bool {
    // Disable first PS/2 port
    mouse_wait_write();
    io.outb(0x64, 0xAD);

    // Disable second PS/2 port
    mouse_wait_write();
    io.outb(0x64, 0xA7);

    // Flush output buffer
    io.inb(0x60);

    // Set controller configuration
    mouse_wait_write();
    io.outb(0x64, 0x20);
    mouse_wait_read();
    var config = io.inb(0x60);

    // Enable IRQ12 (bit 1) and disable PS/2 port translation (bit 6)
    config |= 0x02; // Enable IRQ12
    config &= ~@as(u8, 0x40); // Disable translation

    mouse_wait_write();
    io.outb(0x64, 0x60);
    mouse_wait_write();
    io.outb(0x60, config);

    // Enable second PS/2 port (mouse)
    mouse_wait_write();
    io.outb(0x64, 0xA8);

    // Send command to mouse: enable data reporting
    if (!mouse_write(0xF4)) {
        return false;
    }

    // Wait for ACK
    mouse_wait_read();
    const ack = io.inb(0x60);
    if (ack != 0xFA) {
        return false;
    }

    // Enable first PS/2 port (keyboard)
    mouse_wait_write();
    io.outb(0x64, 0xAE);

    return true;
}

fn mouse_wait_write() void {
    var timeout: u32 = 100000;
    while (timeout > 0) : (timeout -= 1) {
        if ((io.inb(0x64) & 0x02) == 0) {
            return;
        }
    }
}

fn mouse_wait_read() void {
    var timeout: u32 = 100000;
    while (timeout > 0) : (timeout -= 1) {
        if ((io.inb(0x64) & 0x01) != 0) {
            return;
        }
    }
}

fn mouse_write(data: u8) bool {
    // Send command to write to mouse
    mouse_wait_write();
    io.outb(0x64, 0xD4);

    // Send the data
    mouse_wait_write();
    io.outb(0x60, data);

    return true;
}

pub export fn handle_mouse_data(data: u8) void {
    switch (packet_stage) {
        0 => {
            // First byte must have bit 3 set (sync bit)
            if ((data & 0x08) != 0) {
                packet[0] = data;
                packet_stage = 1;
            }
        },
        1 => {
            packet[1] = data;
            packet_stage = 2;
        },
        2 => {
            packet[2] = data;
            packet_stage = 0;
            update_mouse_state();
        },
        else => packet_stage = 0,
    }
}

fn update_mouse_state() void {
    const buttons = packet[0] & 0x07;
    var dx = @as(i16, @as(i8, @bitCast(packet[1])));
    var dy = @as(i16, @as(i8, @bitCast(packet[2])));

    // Apply sensitivity scaling
    dx /= 2;
    dy /= 2;

    mouse_state.x += dx;
    mouse_state.y -= dy; // Invert Y axis for screen coordinates

    // Clamp to screen bounds
    if (mouse_state.x < 0) mouse_state.x = 0;
    if (mouse_state.x >= 80) mouse_state.x = 79;
    if (mouse_state.y < 0) mouse_state.y = 0;
    if (mouse_state.y >= 25) mouse_state.y = 24;

    mouse_state.buttons = buttons;

    // Draw cursor at new position
    draw_cursor();
}

fn draw_cursor() void {
    const VGA_MEMORY = @as(*volatile [25 * 80]u16, @ptrFromInt(0xB8000));
    const pos = @as(usize, @intCast(mouse_state.y)) * 80 + @as(usize, @intCast(mouse_state.x));

    // Draw a simple cursor character
    const cursor_char: u8 = if (mouse_state.buttons != 0) '*' else '+';
    const color: u8 = 0x0F; // White on black

    VGA_MEMORY[pos] = (@as(u16, color) << 8) | cursor_char;
}

pub fn get_mouse_state() MouseState {
    return mouse_state;
}
