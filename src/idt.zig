const std = @import("std");

// Make sure these are defined somewhere (usually in gdt.zig or segments.zig)
pub const CODE_SELECTOR = 0x08;  // Typical code segment selector for kernel mode

pub const IDTEntry = packed struct {
    offset_low: u16,
    selector: u16,
    zero: u8 = 0,
    type_attr: u8,
    offset_high: u16,

    pub fn init(handler: usize, selector: u16, type_attr: u8) IDTEntry {
        return IDTEntry{
            .offset_low = @as(u16, @intCast(handler & 0xFFFF)),
            .selector = selector,
            .type_attr = type_attr,
            .offset_high = @as(u16, @intCast((handler >> 16) & 0xFFFF)),
        };
    }
};

pub var idt: [256]IDTEntry = undefined;

// Declare the external assembly handlers
extern fn isr0() callconv(.Naked) void;
extern fn irq12_handler() callconv(.Naked) void;

pub fn initIDT() void {
    // Initialize all entries to default handler first
    for (&idt, 0..) |*entry, i| {
        entry.* = IDTEntry.init(
            @intFromPtr(&isr0),
            CODE_SELECTOR,
            0x8E,  // P=1, DPL=00, S=0, Type=1110 (32-bit interrupt gate)
        );
        _ = i; // Suppress unused variable warning
    }
    
    // Initialize IRQ12 (mouse) entry
    // IRQ12 is interrupt 44 (32 + 12) in protected mode
    idt[44] = IDTEntry.init(
        @intFromPtr(&irq12_handler),
        CODE_SELECTOR,
        0x8E,  // P=1, DPL=00, S=0, Type=1110 (32-bit interrupt gate)
    );
    
    // Initialize PIC (Programmable Interrupt Controller)
    init_pic();
}

fn init_pic() void {
    const io = @import("io.zig");
    
    // Save masks
    const mask1 = io.inb(0x21);
    const mask2 = io.inb(0xA1);
    
    // Initialize PIC1
    io.outb(0x20, 0x11); // ICW1: Init with ICW4
    io.outb(0x21, 0x20); // ICW2: IRQ 0-7 -> INT 0x20-0x27
    io.outb(0x21, 0x04); // ICW3: PIC2 at IRQ2
    io.outb(0x21, 0x01); // ICW4: 8086 mode
    
    // Initialize PIC2
    io.outb(0xA0, 0x11); // ICW1: Init with ICW4
    io.outb(0xA1, 0x28); // ICW2: IRQ 8-15 -> INT 0x28-0x2F
    io.outb(0xA1, 0x02); // ICW3: Cascade identity
    io.outb(0xA1, 0x01); // ICW4: 8086 mode
    
    // Restore masks but enable IRQ12 (mouse)
    io.outb(0x21, mask1);
    io.outb(0xA1, mask2 & ~@as(u8, 0x10)); // Enable IRQ12 (bit 4 on PIC2)
}

pub fn loadIDT() void {
    const IDTPointer = packed struct {
        limit: u16,
        base: usize,
    };

    var idtr = IDTPointer{
        .limit = @sizeOf(IDTEntry) * idt.len - 1,
        .base = @intFromPtr(&idt),
    };

    asm volatile (
        \\ lidt %[idtr]
        :
        : [idtr] "m" (idtr)
        : "memory"
    );
}