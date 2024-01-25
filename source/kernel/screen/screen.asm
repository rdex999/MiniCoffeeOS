;
; ---------- [ BASIC SCREEN MANIPULATION FUNCTIONS ] ----------
;

%ifndef SCREEN_ASM
%define SCREEN_ASM

; clears the screen
clear:
  mov ah, 2
  xor dx, dx  ; DL column, DH row // both 0
  xor bh, bh
  int 10h

  mov cx, 25*80
  mov al, ' '
clear_loop:
  mov ah, 0Eh
  int 10h
  loop clear_loop

  mov ah, 2
  xor dx, dx  ; DL column, DH row // both 0
  xor bh, bh
  int 10h
  ret

%endif