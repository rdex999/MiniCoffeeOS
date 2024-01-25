;
; ---------- [ BASIC SCREEN MANIPULATION FUNCTIONS ] ----------
;

; sets the cursors position
; PARAMS
; 0) int => row
; 1) int => column
; 2) int => page
%macro SET_CURSOR_POSITION 3

  mov ah, 2h 
  mov dh, %1
  mov dl, %2
  mov bh, %3
  int 10h

%endmacro


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
