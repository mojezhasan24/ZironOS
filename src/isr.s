/* isr.s - Proper GNU Assembler syntax */
.global isr0
.type isr0, @function
isr0:
    cli
    hlt

.global irq12_handler
.type irq12_handler, @function
irq12_handler:
    pusha
    cld

    /* Read mouse data */
    in $0x60, %al
    movzx %al, %ebx  /* Zero-extend to 32-bit */

    /* Call Zig function */
    push %ebx
    call handle_mouse_data
    add $4, %esp

    /* Send EOI */
    mov $0x20, %al
    out %al, $0xA0
    out %al, $0x20

    popa
    iretl