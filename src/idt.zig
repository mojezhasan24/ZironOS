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

// Declare the external assembly handler and Zig callback
extern fn irq12_handler() void;
extern fn irq12_callback() void;

pub fn initIDT() void {
    // Initialize IRQ12 (mouse) entry
    // IRQ12 is interrupt 44 (32 + 12) in protected mode
    idt[44] = IDTEntry.init(
        @intFromPtr(&irq12_handler),
        CODE_SELECTOR,
        0x8E,  // P=1, DPL=00, S=0, Type=1110 (32-bit interrupt gate)
    );
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