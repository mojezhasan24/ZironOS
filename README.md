# ZironOS - A Simple Kernel in Zig

## Project Structure
```
zironos/
├── src/
│   ├── main.zig           # Kernel main code
│   └── boot.s             # Assembly bootloader
├── iso_root/
│   └── boot/
│       └── grub/
│           └── grub.cfg   # GRUB configuration
├── build.zig              # Zig build configuration
├── linker.ld              # Linker script
├── Makefile              # Build automation
└── README.md             # This file
```

## Prerequisites

1. **Zig 0.11.0** - Download from [ziglang.org](https://ziglang.org/download/)
2. **GRUB tools** - For creating bootable ISO
   ```bash
   # Ubuntu/Debian
   sudo apt install grub-pc-bin grub-common xorriso

   # Arch Linux
   sudo pacman -S grub xorriso

   # macOS (with Homebrew)
   brew install grub xorriso
   ```
3. **QEMU** (optional, for testing)
   ```bash
   # Ubuntu/Debian
   sudo apt install qemu-system-x86

   # Arch Linux  
   sudo pacman -S qemu

   # macOS
   brew install qemu
   ```

## Building

### Quick Start
```bash
# Check if you have all required tools
make check

# Build and create ISO
make iso

# Test in QEMU (if installed)
make run
```

### Manual Build Steps
```bash
# 1. Create directory structure
mkdir -p src iso_root/boot/grub

# 2. Build kernel
zig build

# 3. Create ISO
cp zig-out/bin/zironos iso_root/zironos
grub-mkrescue -o zironos.iso iso_root
```

## Testing

### In QEMU
```bash
# Basic run
make run

# With debugging output
make debug

# Manual QEMU command
qemu-system-x86_64 -cdrom zironos.iso
```

### On Real Hardware
⚠️ **WARNING**: Only test on hardware you don't mind potentially corrupting!

1. Flash the ISO to a USB drive:
   ```bash
   sudo dd if=zironos.iso of=/dev/sdX bs=4M status=progress
   ```
2. Boot from the USB drive

## Features

- ✅ Multiboot-compliant kernel
- ✅ VGA text mode output  
- ✅ Colorful terminal display
- ✅ Proper stack setup
- ✅ Memory-safe Zig code
- ✅ Cross-platform build system

## What You'll See

When you boot ZironOS, you should see:
```
ZironOS v0.1.0
Kernel loaded successfully!
Welcome to ZironOS - A kernel written in Zig
System initialized and ready.
```

Each line will be displayed in different colors!

## Next Steps

Some ideas for extending ZironOS:
- Add keyboard input handling
- Implement a simple shell
- Add memory management
- Create a filesystem
- Add multitasking support

## Troubleshooting

### Common Issues

1. **"No multiboot header found"**
   - Make sure the assembly file is properly linked
   - Check that the multiboot section comes first in the linker script

2. **"Zig build fails"**
   - Ensure you're using Zig 0.11.0
   - Check that all file paths in build.zig are correct

3. **"grub-mkrescue not found"**
   - Install GRUB tools as shown in prerequisites
   - On some systems, try `grub2-mkrescue` instead

4. **QEMU doesn't start**
   - Make sure QEMU is installed
   - Try `qemu-system-i386` instead of `qemu-system-x86_64`

### Clean and Rebuild
```bash
make clean
make iso
```