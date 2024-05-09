#
# ---------- [ BUILD THE UTILITIES ] ---------
#

# When using this file, specify -f = .

.PHONY: all ui shell

all: ui shell
	mcopy -i $(FDA) $(BLD)/bin "::bin"

ui: $(BLD)/bin/ui
$(BLD)/bin/ui: $(SRC)/utils/ui/ui.asm
	$(AS) $(AS_FLAGS) -o $@ $?

shell: $(BLD)/bin/shell
$(BLD)/bin/shell: $(SRC)/utils/shell/shell.asm
	$(AS) $(AS_FLAGS) -o $@ $?