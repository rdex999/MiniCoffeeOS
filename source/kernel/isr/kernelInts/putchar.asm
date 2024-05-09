;
; ---------- [ PRINT A CHARACTER ] ----------
;

%ifndef PRINT_CHAR_ASM
%define PRINT_CHAR_ASM

; Print a single character at the current cursor position, with echo
; PARAMS
;   - 0) DI   => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) SI   => The character, lower 8 bits only
; Doesnt return anything
ISR_putchar:
  test di, 1_0000_0000b               ; Check if the user requested the current terminal color
  jz .afterSetColor                   ; If he didnt, then DI is already set to the color. Just print the character

  push gs                             ; Save GS because going to change it for a sec
  mov bx, KERNEL_SEGMENT              ; Set GS to the kernels segment so we can access trmColor
  mov gs, bx                          ;

  mov di, gs:[trmColor]               ; Get the current terminal color
  pop gs                              ; Restore GS

.afterSetColor:
  shl di, 8                           ; Get the color in high 8 bits of DI
  or di, si                           ; Color in high 8 bits of DI, and character in low 8 bits
  call printChar                      ; Print the character with it being in the low 8 bits of DI and the color in the high 8 bits

  jmp ISR_kernelInt_end               ; Return from the interrupt

%endif