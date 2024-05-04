include makeConf.mk

.PHONY: all always

all: always $(FDA)

always:
	mkdir -p $(BLD)
	mkdir -p $(BLD)/bin

$(FDA): $(BLD)/boot.bin $(BLD)/kernel.bin
	dd if=/dev/zero of=$(FDA) bs=1000K count=9
	mkfs.fat -F 16 -n "MYKERNEL" $(FDA)
	dd if=$(BLD)/boot.bin of=$(FDA) conv=notrunc
	mcopy -i $(FDA) $(BLD)/kernel.bin "::kernel.bin"
	$(MAKE) -f $(SRC)/utils/makefile

$(BLD)/boot.bin: $(SRC)/bootloader/boot.asm
	$(AS) $(AS_FLAGS) -o $@ $?

$(BLD)/kernel.bin: $(SRC)/kernel/kernel.asm
	$(AS) $(AS_FLAGS) -o $@ $?

clean:
	rm -f $(FDA)
	rm -rf $(BLD)/*

run: $(FDA)
	make clean
	make
	qemu-system-x86_64 -drive file=$(FDA),format=raw,index=0,media=disk -rtc base=localtime
	clear