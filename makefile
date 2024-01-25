AS=nasm
AS_FLAGS= -f bin
SRC=source/
BLD=build/
FDA=floppy.img

$(FDA): $(BLD)boot.bin $(BLD)kernel.bin
	dd if=/dev/zero of=$(FDA) bs=512 count=2880
	dd if=$(BLD)boot.bin of=$(FDA) conv=notrunc
	dd if=$(BLD)kernel.bin of=$(FDA) bs=512 seek=1 conv=notrunc

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
