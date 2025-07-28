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
    call irq12_callback
    popa
    iretl