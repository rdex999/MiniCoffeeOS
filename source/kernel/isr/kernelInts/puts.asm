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
  test di, 1_0000_0000b             ; Check if the user has requested the current terminal color
  jz .afterSetColor                 ; If not then the color is in DI, just print the string

  push gs                           ; Save GS because modifying it
  mov bx,KERNEL_SEGMENT             ; Set GS to the kernels segment so we can access trmColor
  mov gs, bx                        ; 
  mov di, gs:[trmColor]             ; Get the current terminal color
  pop gs                            ; Restore GS

.afterSetColor:
  call printStr                     ; Print the string (from DS:SI)
  xor ax, ax
  jmp ISR_kernelInt_end             ; Return from the interrupt

%endif