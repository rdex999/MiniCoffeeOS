;
; --------- [ HANDLE USER COMMANDS ] ----------
;

%include "shared/interrupts.asm"

org 100h

main:
  push bp
  mov bp, sp

  lea si, str
  mov di, 100h
  mov ax, INT_N_PUTS
  int INT_F_KERNEL


main_end:
  mov sp, bp
  pop bp

  mov ax, INT_N_EXIT
  int INT_F_KERNEL



;
; --------- [ DATA SECTION ] ---------
;

str: db "Hello from the shell!", 0Ah, 0