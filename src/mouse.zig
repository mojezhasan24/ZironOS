const io = @import("io.zig");

pub const MouseState = struct {
    x: i16,
    y: i16,
    buttons: u8,
};

pub var mouse_state: MouseState = .{
    .x = 40, // center-ish
    .y = 12,
    .buttons = 0,
};

var packet: [3]u8 = undefined;
var packet_index: u8 = 0;

pub export fn handle_mouse_data(data: u8) void {
    switch (packet_index) {
        0 => if ((data & 0x08) != 0) {
            packet[0] = data;
            packet_index = 1;
        },
        1 => {
            packet[1] = data;
            packet_index = 2;
        },
        2 => {
            packet[2] = data;
            packet_index = 0;
            update_mouse_state();
        },
        else => packet_index = 0,
    }
}

fn update_mouse_state() void {
    const dx = @as(i8, @bitCast(packet[1]));
    const dy = @as(i8, @bitCast(packet[2]));
    const buttons = packet[0] & 0x07;

    mouse_state.x += dx;
    mouse_state.y -= dy; // upward movement decreases y

    // Clamp within screen bounds
    if (mouse_state.x < 0) mouse_state.x = 0;
    if (mouse_state.x > 79) mouse_state.x = 79;
    if (mouse_state.y < 0) mouse_state.y = 0;
    if (mouse_state.y > 24) mouse_state.y = 24;

    mouse_state.buttons = buttons;

    // Optional: draw cursor or log state
    // draw_cursor(mouse_state.x, mouse_state.y);
}

pub fn mouse_init() void {
    io.outb(0x64, 0xA8); // Enable mouse device
    io.outb(0x64, 0x20);
    var status = io.inb(0x60);
    status |= 0x02;
    io.outb(0x64, 0x60);
    io.outb(0x60, status);

    mouse_write(0xF6);
    _ = mouse_read(); // default settings
    mouse_write(0xF4);
    _ = mouse_read(); // enable data reporting
}

fn mouse_write(cmd: u8) void {
    mouse_wait_write();
    io.outb(0x64, 0xD4);
    mouse_wait_write();
    io.outb(0x60, cmd);
}

fn mouse_read() u8 {
    mouse_wait_read();
    return io.inb(0x60);
}

fn mouse_wait_write() void {
    while ((io.inb(0x64) & 0x02) != 0) {}
}
fn mouse_wait_read() void {
    while ((io.inb(0x64) & 0x01) == 0) {}
}
