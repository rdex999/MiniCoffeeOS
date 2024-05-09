%include "shared/interrupts.asm"

org 100h

main:





main_end:
  mov ax, INT_N_EXIT
  int INT_F_KERNEL

;
; ---------- [ DATA SECTION ] ---------
;

