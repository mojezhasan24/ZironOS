const io = @import("io.zig");
const std = @import("std");

pub const MouseState = struct {
    x: i16,
    y: i16,
    buttons: u8,
};

pub var mouse_state: MouseState = .{
    .x = 0,
    .y = 0,
    .buttons = 0,
};

var packet: [3]u8 = undefined;
var packet_stage: u8 = 0;

pub export fn handle_mouse_data(data: u8) void {
    switch (packet_stage) {
        0 => if ((data & 0x08) != 0) {
            packet[0] = data;
            packet_stage = 1;
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
    const dx = @as(i8, @bitCast(packet[1]));
    const dy = @as(i8, @bitCast(packet[2]));

    mouse_state.x +%= dx;
    mouse_state.y -%= dy;
    mouse_state.buttons = buttons;

    if (mouse_state.x < 0) mouse_state.x = 0;
    if (mouse_state.y < 0) mouse_state.y = 0;
}

pub fn get_mouse_state() MouseState {
    return mouse_state;
}
pub fn mouse_init() bool {
    return true; // stub for now
}
