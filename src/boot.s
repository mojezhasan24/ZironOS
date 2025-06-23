# Multiboot header constants
.set ALIGN,    1<<0             # align loaded modules on page boundaries
.set MEMINFO,  1<<1             # provide memory map  
.set FLAGS,    ALIGN | MEMINFO  # multiboot flags
.set MAGIC,    0x1BADB002       # magic number for multiboot header
.set CHECKSUM, -(MAGIC + FLAGS) # checksum to prove we are multiboot

# Multiboot header - must be within first 8KB of kernel
.section .multiboot, "a"
.align 4
multiboot_header:
.long MAGIC
.long FLAGS
.long CHECKSUM

# Reserve stack space in BSS
.section .bss
.align 16
stack_bottom:
.skip 16384 # 16 KiB stack
stack_top:

# Entry point
.section .text
.global _start
.type _start, @function

_start:
    # Setup the stack pointer
    mov $stack_top, %esp
    
    # Ensure stack is 16-byte aligned (required for x86_64 ABI)
    and $-16, %esp
    
    # Call the kernel main function
    # GRUB handles the transition to 64-bit mode for x86_64 targets
    call main
    
    # If main returns, halt the system
halt:
    cli        # disable interrupts
    hlt        # halt processor
    jmp halt   # loop forever

.size _start, . - _start