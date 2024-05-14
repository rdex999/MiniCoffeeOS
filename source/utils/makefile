#
# ---------- [ BUILD THE UTILITIES ] ---------
#

# When using this file, specify -f = .

.PHONY: all ui shell text files

all: ui shell text files
	cp build/kernel.bin build/bin/	
	mcopy -i $(FDA) $(BLD)/bin "::bin"

ui: $(BLD)/bin/ui
$(BLD)/bin/ui: $(SRC)/utils/ui/ui.asm
	$(AS) $(AS_FLAGS) -o $@ $?

shell: $(BLD)/bin/shell
$(BLD)/bin/shell: $(SRC)/utils/shell/shell.asm
	$(AS) $(AS_FLAGS) -o $@ $?

text: $(BLD)/bin/text
$(BLD)/bin/text: $(SRC)/utils/text/text.asm
	$(AS) $(AS_FLAGS) -o $@ $?

files: $(BLD)/bin/files
$(BLD)/bin/files: $(SRC)/utils/files/files.asm
	$(AS) $(AS_FLAGS) -o $@ $?