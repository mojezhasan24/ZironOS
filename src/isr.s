.section .text
.global isr0
.type isr0, @function
isr0:
    cli
    hlt
global irq12_handler
irq12_handler:
    pusha
    call irq12_callback
    popa
    iretd
