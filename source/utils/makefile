#
# ---------- [ BUILD THE UTILITIES ] ---------
#

# When using this file, specify -f = .

.PHONY: all shell

all: shell
	mcopy -i $(FDA) $(BLD)/bin "::bin"

shell: $(BLD)/bin/shell
$(BLD)/bin/shell: $(SRC)/utils/shell/shell.asm
	$(AS) $(AS_FLAGS) -o $@ $?