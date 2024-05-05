;
; ---------- [ PRINT A STRING ] ---------
;

%ifndef PUTS_ASM
%define PUTS_ASM

; Print a string starting from the current cursor location
; PARAMS
;   - 0) DI     => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) DS:SI  => The string to print, null terminated
; Doesnt return anything
ISR_puts:
  test di, 1_0000_0000b
  jz .afterSetColor

  push gs
  mov bx,KERNEL_SEGMENT
  mov gs, bx
  mov di, gs:[trmColor]
  pop gs

.afterSetColor:
  call printStr
  jmp ISR_kernelInt_end

%endif