AS=nasm
AS_FLAGS= -f bin -i "source"
SRC=source/
BLD=build/
FDA=floppy.img

$(FDA): $(BLD)boot.bin $(BLD)kernel.bin
	dd if=/dev/zero of=$(FDA) bs=1000K count=9
	mkfs.fat -F 16 -n "MYKERNEL" $(FDA)
	dd if=$(BLD)boot.bin of=$(FDA) conv=notrunc
	mcopy -i $(FDA) $(BLD)kernel.bin "::kernel.bin"
	mcopy -i $(FDA) test.txt "::test.txt"

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

	mcopy -i $(FDA) tmp/t2.txt "::t16.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t17.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t18.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t19.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t20.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t21.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t22.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t23.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t24.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t25.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t26.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t27.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t28.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t29.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t30.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t31.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t32.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t33.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t34.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t35.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t36.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t37.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t38.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t39.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t40.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t41.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t42.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t43.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t44.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t45.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t46.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t47.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t48.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t49.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t50.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t51.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t52.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t53.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t54.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t55.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t56.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t57.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t58.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t59.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t60.txt"
	mcopy -i $(FDA) tmp/t2.txt "::t61.txt"

	mcopy -i $(FDA) tmp/folder "::folder"


$(BLD)boot.bin: $(SRC)bootloader/boot.asm
	$(AS) $(AS_FLAGS) -o $(BLD)boot.bin $(SRC)bootloader/boot.asm

$(BLD)kernel.bin: $(SRC)kernel/kernel.asm
	$(AS) $(AS_FLAGS) -o $(BLD)kernel.bin $(SRC)kernel/kernel.asm

clean:
	rm $(FDA)
	rm -rf build/*

run: $(FDA)
	make clean
	make
	qemu-system-x86_64 -drive file=$(FDA),format=raw,index=0,media=disk -rtc base=localtime
	clear
