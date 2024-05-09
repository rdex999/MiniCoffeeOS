%include "shared/interrupts.asm"

org 100h

main:

  mov di, 100h
  lea si, str
  mov ax, INT_N_PUTS
  int INT_F_KERNEL

  mov di, 5000
  mov ax, INT_N_SLEEP
  int INT_F_KERNEL

  mov ax, INT_N_GET_SYS_DATE
  int INT_F_KERNEL

  xor dh, dh

  mov dl, ah
  push dx

  mov dl, bl
  push dx

  mov dl, bh
  push dx

  push strDate
  mov ax, INT_N_PRINTF
  int INT_F_KERNEL

  add sp, 8

main_end:
  jmp $


str: db "shell start", 0Ah, 0
strDate: db "date from shell: 20%u-%u-%u", 0Ah, 0
;
; ---------- [ DATA SECTION ] ---------
;

