;
; ---------- [ CLEARS THE SCREEN ] ----------
;

%ifndef SCREEN_ASM
%define SCREEN_ASM

; clears the screen
clear:
  push bp
  mov bp, sp
  sub sp, 2

  push es
  mov bx, KERNEL_SEGMENT
  mov es, bx

  mov word es:[trmIndex], 0
  mov word [bp - 2], 80*25

clear_loop:
  mov al, ' '
  mov ah, es:[trmColor]
  PRINT_CHAR al, ah
  dec word [bp - 2]
  jnz clear_loop

  mov word es:[trmIndex], 0

  pop es
  mov sp, bp
  pop bp
  ret

%endif