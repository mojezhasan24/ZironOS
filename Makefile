.PHONY: all build iso clean run check

# Default target
all: iso

# Check for required tools
check:
	@which zig > /dev/null || (echo "Error: zig not found in PATH" && exit 1)
	@which grub-mkrescue > /dev/null || (echo "Error: grub-mkrescue not found in PATH" && exit 1)
	@which xorriso > /dev/null || (echo "Error: xorriso not found in PATH" && exit 1)
	@which qemu-system-x86_64 > /dev/null || (echo "Error: qemu-system-x86_64 not found in PATH" && exit 1)
	@echo "All required tools found"

# Build the kernel
build: check
	zig build

# Create ISO image
iso: build
	@mkdir -p iso_root/boot/grub
	zig build iso

# Clean build artifacts
clean:
	rm -rf zig-out/ zig-cache/
	rm -f zironos.iso
	rm -f iso_root/zironos

# Run in QEMU
run: iso
	qemu-system-x86_64 -cdrom zironos.iso -m 512M