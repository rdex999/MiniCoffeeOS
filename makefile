AS=nasm
AS_FLAGS= -f bin -i "source" -O3
SRC=source/
BLD=build/
FDA=floppy.img

$(FDA): $(BLD)boot.bin $(BLD)kernel.bin
	dd if=/dev/zero of=$(FDA) bs=1000K count=9
	mkfs.fat -F 16 -n "MYKERNEL" $(FDA)
	dd if=$(BLD)boot.bin of=$(FDA) conv=notrunc
	mcopy -i $(FDA) $(BLD)kernel.bin "::kernel.bin"
	mcopy -i $(FDA) test.txt "::test.txt"

	mcopy -i $(FDA) tmp/folder "::folder"
	mcopy -i $(FDA) tmp/folder/fld200 "::folder/fld200"

	mcopy -i $(FDA) tmp/t0.txt "::t0.txt"
	mcopy -i $(FDA) tmp/t1.txt "::t1.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t2.txt"
	mcopy -i $(FDA) tmp/t3.txt "::t3.txt"
	mcopy -i $(FDA) tmp/t4.txt "::t4.txt"
	mcopy -i $(FDA) tmp/t5.txt "::t5.txt"
	mcopy -i $(FDA) tmp/t6.txt "::t6.txt"
	mcopy -i $(FDA) tmp/t7.txt "::t7.txt"
	mcopy -i $(FDA) tmp/t8.txt "::t8.txt"
	mcopy -i $(FDA) tmp/t9.txt "::t9.txt"
	mcopy -i $(FDA) tmp/t10.txt "::t10.txt"
	mcopy -i $(FDA) tmp/t11.txt "::t11.txt"
	mcopy -i $(FDA) tmp/t12.txt "::t12.txt"
	mcopy -i $(FDA) tmp/t13.txt "::t13.txt"
	mcopy -i $(FDA) tmp/t14.txt "::t14.txt"
	mcopy -i $(FDA) tmp/t15.txt "::t15.txt"


$(BLD)boot.bin: $(SRC)bootloader/boot.asm
	$(AS) $(AS_FLAGS) -o $(BLD)boot.bin $(SRC)bootloader/boot.asm

$(BLD)kernel.bin: $(SRC)kernel/kernel.asm
	$(AS) $(AS_FLAGS) -o $(BLD)kernel.bin $(SRC)kernel/kernel.asm

clean:
	rm -f $(FDA)
	rm -rf build/*

run: $(FDA)
	make clean
	make
	qemu-system-x86_64 -drive file=$(FDA),format=raw,index=0,media=disk -rtc base=localtime
	clear
