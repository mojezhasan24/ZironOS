const io = @import("io.zig");
const std = @import("std");
const idt = @import("idt.zig");
// const io = @import("io.zig");
const irq = @import("irq.zig");
pub var tick_count: usize = 0;

// Timer configuration constants
pub const TIMER_FREQUENCY = 1000; // 1000 Hz (1ms intervals)
pub const PIT_FREQUENCY = 1193182; // PIT base frequency
pub const TIMER_DIVISOR = PIT_FREQUENCY / TIMER_FREQUENCY;

// Initialize the Programmable Interval Timer (PIT)
pub fn init_timer() void {
    // Set PIT to mode 3 (square wave generator)
    io.outb(0x43, 0x36);

    // Set frequency divisor
    io.outb(0x40, @truncate(TIMER_DIVISOR & 0xFF));
    io.outb(0x40, @truncate((TIMER_DIVISOR >> 8) & 0xFF));
}

// Get uptime in milliseconds
pub fn get_uptime_ms() usize {
    return tick_count;
}

// Get uptime in seconds
pub fn get_uptime_seconds() usize {
    return tick_count / TIMER_FREQUENCY;
}

const terminal_write = @import("terminal.zig").terminal_write;

export fn irq0_handler() void {
    tick_count += 1;
    if (tick_count % 1000 == 0) {
        terminal_write("[TIMER]\n");
    }
    io.outb(0x20, 0x20);
}

pub export fn irq12_callback() void {
    const data = @import("mouse.zig").mouse_read();
    @import("mouse.zig").handle_mouse_data(data);

    // Send EOI to PIC
    @import("io.zig").outb(0xA0, 0x20); // Secondary PIC
    @import("io.zig").outb(0x20, 0x20); // Primary PIC
}
