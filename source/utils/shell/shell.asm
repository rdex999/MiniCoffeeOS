org 100h

  mov di, 0Dh | 100h
  lea si, str
  mov ax, 2
  int 20h

  jmp $

str: db "Hello from the shell!", 0Ah, 0
dw 0AABBh      ;;; DEBUG