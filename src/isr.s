.section .text
.global isr0
.type isr0, @function
isr0:
    cli
    hlt