const std = @import("std");

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
