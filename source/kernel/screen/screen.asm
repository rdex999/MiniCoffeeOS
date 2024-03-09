;
; ---------- [ BASIC SCREEN MANIPULATION FUNCTIONS ] ----------
;

%ifndef SCREEN_ASM
%define SCREEN_ASM

; clears the screen
clear:
  mov ax, 0700h                   ; AH = 7 AL = 0   => Clear screen
  mov bh, 7                       ; Gray color
  xor cx, cx                      ; Upper left row (CH) and column (CL)
  mov dx, 1950h                   ; Lower right row (DH) and column (DL)  | DH = 25, DL = 80
  int 10h                         ; Perform interrupt

  SET_CURSOR_POSITION 0, 0, 0     ; Set the cursor to (0, 0)
  ret

%endif