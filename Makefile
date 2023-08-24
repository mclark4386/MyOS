ASM=nasm
BUILD_DIR=build
SRC_DIR=src
KERNEL_SRC_DIR=$(SRC_DIR)/kernel
BOOT_SRC_DIR=$(SRC_DIR)/bootloader

.PHONY: all floppy_image kernel bootloader clean always

#
#  Floppy image
#  

floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "MYOS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
#   Bootloader
#   
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(BOOT_SRC_DIR)/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

#
#   Kernel
#
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(KERNEL_SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

#
#   Always
#
always: 
	mkdir -p $(BUILD_DIR)


#
#   Clean
#
clean:
	rm -Rf $(BUILD_DIR)/*
