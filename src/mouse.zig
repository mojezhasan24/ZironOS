const io = @import("io.zig");

// Mouse state tracking
pub var mouse_packet: [3]u8 = undefined;
pub var packet_ready: bool = false;
pub var packet_stage: u8 = 0;
pub var mouse_x: i16 = 0;
pub var mouse_y: i16 = 0;
pub var mouse_buttons: u8 = 0;

/// Wait for mouse controller readiness
pub fn mouse_wait(wait_type: u8) bool {
    var timeout: u32 = 100000;
    if (wait_type == 0) { // Wait to write
        while (timeout > 0) : (timeout -= 1) {
            if ((io.inb(0x64) & 0x02) == 0) return true;
        }
    } else { // Wait to read
        while (timeout > 0) : (timeout -= 1) {
            if ((io.inb(0x64) & 0x01) != 0) return true;
        }
    }
    return false; // Timeout occurred
}

/// Write a command to the mouse
pub fn mouse_write(command: u8) void {
    _ = mouse_wait(0); // Wait to write
    io.outb(0x64, 0xD4); // Tell controller we're writing to mouse
    _ = mouse_wait(0);
    io.outb(0x60, command); // Send the actual command
}

/// Read a byte from the mouse
pub fn mouse_read() u8 {
    _ = mouse_wait(1); // Wait for data
    return io.inb(0x60);
}

/// Handle incoming mouse data (called from IRQ12 handler)
pub fn handle_mouse_data(data: u8) void {
    switch (packet_stage) {
        0 => {
            if (data & 0x08 != 0) { // Check sync bit
                mouse_packet[0] = data;
                packet_stage = 1;
            }
        },
        1 => {
            mouse_packet[1] = data;
            packet_stage = 2;
        },
        2 => {
            mouse_packet[2] = data;
            packet_ready = true;
            packet_stage = 0;
            process_mouse_packet();
        },
        else => packet_stage = 0,
    }
}

/// Process a complete 3-byte mouse packet
fn process_mouse_packet() void {
    const packet = mouse_packet;
    mouse_buttons = packet[0] & 0x07;

    // Calculate movement (handling sign extension)
    var dx: i16 = @as(i16, packet[1]);
    var dy: i16 = @as(i16, packet[2]);

    // Handle negative deltas (sign extension)
    if ((packet[0] & 0x10) != 0) dx |= 0xFF00;
    if ((packet[0] & 0x20) != 0) dy |= 0xFF00;

    // Update position
    mouse_x += dx;
    mouse_y -= dy; // Invert Y axis

    // Optional: Add bounds checking
    if (mouse_x < 0) mouse_x = 0;
    if (mouse_y < 0) mouse_y = 0;

    // For debugging:
    // @import("terminal.zig").print("Mouse: X={}, Y={}, Buttons={b}\n", .{mouse_x, mouse_y, mouse_buttons});
}

/// Initialize the PS/2 mouse
pub fn mouse_install() void {
    // Enable auxiliary device
    _ = mouse_wait(0);
    io.outb(0x64, 0xA8);

    // Enable interrupts
    _ = mouse_wait(0);
    io.outb(0x64, 0x20);
    _ = mouse_wait(1);
    var status = io.inb(0x60);
    status |= 0x02; // Enable mouse interrupts
    status &= 0x20; // Disable mouse clock
    _ = mouse_wait(0);
    io.outb(0x64, 0x60);
    _ = mouse_wait(0);
    io.outb(0x60, status);

    // Set default settings
    mouse_write(0xF6);
    _ = mouse_read(); // ACK

    // Enable data reporting
    mouse_write(0xF4);
    _ = mouse_read(); // ACK

    // Optional: Set sample rate to get 3-byte packets
    mouse_write(0xF3); // Set sample rate
    _ = mouse_read(); // ACK
    mouse_write(200); // 200 samples/sec
    _ = mouse_read(); // ACK

    mouse_write(0xF3); // Set sample rate again
    _ = mouse_read(); // ACK
    mouse_write(100); // 100 samples/sec
    _ = mouse_read(); // ACK

    mouse_write(0xF3); // Set sample rate again
    _ = mouse_read(); // ACK
    mouse_write(80); // 80 samples/sec
    _ = mouse_read(); // ACK

    // This sequence enables scroll wheel if available
}

/// Get current mouse state
pub fn get_mouse_state() struct { x: i16, y: i16, buttons: u8 } {
    return .{
        .x = mouse_x,
        .y = mouse_y,
        .buttons = mouse_buttons,
    };
}
