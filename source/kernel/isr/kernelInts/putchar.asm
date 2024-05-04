;
; ---------- [ PRINT A CHARACTER ] ----------
;

%ifndef PRINT_CHAR_ASM
%define PRINT_CHAR_ASM

; Print a single character at the current cursor position, with echo
; PARAMS
;   - 0) DI   => The color, 0FFh for the current terminal color (lower 8 bits only)
;   - 1) SI   => The character, lower 8 bits only
; Doesnt return anything
ISR_putchar:
  shl si, 8
  or di, si
  call printChar

  jmp ISR_kernelInt_end

%endif