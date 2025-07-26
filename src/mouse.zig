const io = @import("io.zig");

pub fn mouse_wait(type: u8) void {
    // wait type 0: wait to write
    // wait type 1: wait to read
    var timeout: u16 = 100000;
    if (type == 0) {
        while (timeout > 0) : (timeout -= 1) {
            if ((io.inb(0x64) & 2) == 0) return;
        }
    } else {
        while (timeout > 0) : (timeout -= 1) {
            if ((io.inb(0x64) & 1) != 0) return;
        }
    }
}

pub fn mouse_write(a: u8) void {
    mouse_wait(0);
    io.outb(0x64, 0xD4);
    mouse_wait(0);
    io.outb(0x60, a);
}

pub fn mouse_read() u8 {
    mouse_wait(1);
    return io.inb(0x60);
}

pub fn mouse_install() void {
    // Enable auxiliary device (mouse)
    mouse_wait(0);
    io.outb(0x64, 0xA8);

    // Enable the interrupts
    mouse_wait(0);
    io.outb(0x64, 0x20);
    mouse_wait(1);
    var status = io.inb(0x60);
    status |= 2;
    mouse_wait(0);
    io.outb(0x64, 0x60);
    mouse_wait(0);
    io.outb(0x60, status);

    // Tell mouse to use default settings
    mouse_write(0xF6);
    _ = mouse_read();

    // Enable the mouse
    mouse_write(0xF4);
    _ = mouse_read();

    // Now mouse will start sending IRQ12 on movement
}
