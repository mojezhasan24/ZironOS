🔷 ZironOS — A Tiny 32-bit Kernel in Zig

ZironOS is a minimalistic multiboot-compliant kernel written in Zig and x86 assembly. It boots with a boot animation using GRUB, prints to the screen using VGA text mode, and captures real-time keyboard input using raw scancodes.

https://github.com/user-attachments/assets/b72d2211-24b0-430e-97fb-9e2410b250c9




🌲 Project Structure

```project structure
ZironOS/

│   ├── main.zig           # Kernel logic (VGA + Keyboard input)
│   └── boot.s             # Entry point (_start) & stack setup
├── iso_root/
│   └── boot/
│       └── grub/
│           └── grub.cfg   # GRUB bootloader config
├── build.zig              # Zig build system
├── linker.ld              # Linker script with multiboot header
├── Makefile               # Build + run automation
└── README.md              # This file
```

🧰 Requirements

    Zig 0.11.0

    GRUB Tools: grub-mkrescue, xorriso, etc.

    QEMU (for testing without physical hardware)

📦 Install on Ubuntu/Debian

sudo apt update
sudo apt install grub-pc-bin xorriso qemu-system-x86

📦 Install on Arch

sudo pacman -S grub xorriso qemu

🚀 Build and Run
🔁 One-Command Boot Test

make run

🧱 Full Lifecycle

make check    # Ensure dependencies exist
make clean    # Remove old build/cache
make iso      # Build & generate ISO image
make run      # Launch QEMU and boot ZironOS

🖥️ What ZironOS Does

✅ Boots via GRUB (Multiboot 1)
✅ Sets up a clean stack and calls main
✅ Initializes a VGA buffer (80x25, 16 colors)
✅ Prints text in color using low-level memory writes
✅ Captures keyboard input and prints each character in real time

✨ Output on Boot
====================
   ZironOS v0.2.0
====================
ZironOS>

Then you can start typing — and it responds instantly!
🧪 Testing on QEMU

# Basic test
make run

# With debugging
make debug

💻 Testing on Real Hardware (⚠️ Expert-Only)

sudo dd if=zironos.iso of=/dev/sdX bs=4M status=progress

Then reboot and boot from the USB.
🧠 What's Inside

    boot.s sets up the multiboot header, entry point, and stack

    main.zig initializes the terminal and enters a keyboard input loop

    linker.ld ensures .multiboot is placed early and sections are aligned properly

    grub.cfg makes GRUB load the kernel via multiboot /zironos

🧱 Future Plans

    ⌨️ Basic shell with built-in commands

    📦 Memory paging

    📁 FAT32/EXT2 read-only FS support

    🧵 Task switching & cooperative multitasking

    🔌 Basic driver support (timer, serial)

❓ Troubleshooting
🔻 GRUB: No Multiboot Header Found?

    Ensure .multiboot is the first section in linker.ld

    Check objdump -h zig-out/bin/zironos — .multiboot must be near 0x100000

🔻 "Permission denied" or PAT issues with git push?

    Use a Personal Access Token instead of password

    Example:

    Username: your-github-username
    Password: <paste your token here>

💬 Credits

Built with 💙 using:

    Zig 0.11.0

    x86 assembly

    GRUB bootloader

    QEMU for testing
