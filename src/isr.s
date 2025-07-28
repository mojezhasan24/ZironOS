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

    ; Read mouse data
    inb $0x60, %al         
    mov %al, %bl           

    ; Call Zig function to handle mouse data
    push %ebx              
    call handle_mouse_data 
    add $4, %esp           
    movb $0x20, %al
    outb %al, $0xA0        
    outb %al, $0x20        
    popa                   
    iretl                  