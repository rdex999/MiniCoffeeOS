AS=nasm
AS_FLAGS= -f bin -g # -g for debug symbols
SRC=source/
BLD=build/
FDA=floppy.img

$(FDA): $(BLD)boot.bin $(BLD)kernel.bin
	dd if=/dev/zero of=$(FDA) bs=512 count=2880
	mkfs.fat -F 12 -n "MYKERNEL" $(FDA)
	dd if=$(BLD)boot.bin of=$(FDA) conv=notrunc
	mcopy -i $(FDA) $(BLD)kernel.bin "::kernel.bin"


$(BLD)boot.bin: $(SRC)bootloader/boot.asm
	$(AS) $(AS_FLAGS) -o $(BLD)boot.bin $(SRC)bootloader/boot.asm

$(BLD)kernel.bin: $(SRC)kernel/kernel.asm
	$(AS) $(AS_FLAGS) -o $(BLD)kernel.bin $(SRC)kernel/kernel.asm

clean:
	rm $(FDA)
	rm -rf build/*

run: $(FDA)
	qemu-system-x86_64 -fda $(FDA)
	clear
