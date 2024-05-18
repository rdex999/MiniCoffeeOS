include makeConf.mk

.PHONY: all always

all: always $(FDA)

always:
	mkdir -p $(BLD)
	mkdir -p $(BLD)/bin

$(FDA): $(BLD)/boot.bin $(BLD)/kernel.bin $(shell find $(SRC)/utils -name *.asm)
	dd if=/dev/zero of=$(FDA) bs=1000K count=9
	mkfs.fat -F 16 -n "MYKERNEL" $(FDA)
	dd if=$(BLD)/boot.bin of=$(FDA) conv=notrunc
	mcopy -i $(FDA) $(BLD)/kernel.bin "::kernel.bin"
	$(MAKE) -f $(SRC)/utils/makefile

$(BLD)/boot.bin: $(shell find $(SRC)/bootloader -name *.asm)
	$(AS) $(AS_FLAGS) -o $@ $(SRC)/bootloader/boot.asm

$(BLD)/kernel.bin: $(shell find $(SRC)/kernel -name *.asm)
	$(AS) $(AS_FLAGS) -o $@ $(SRC)/kernel/kernel.asm

clean:
	rm -f $(FDA)
	rm -rf $(BLD)/*

run: always $(FDA)
	qemu-system-x86_64 -drive file=$(FDA),format=raw,index=0,media=disk -rtc base=localtime
	clear