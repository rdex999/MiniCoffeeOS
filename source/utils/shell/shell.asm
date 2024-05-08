org 100h

  mov di, 0Dh | 100h
  lea si, str
  mov ax, 2
  int 20h

  push sp
  push ss
  push word strData
  mov ax, 4
  int 20h
  add sp, 6

  jmp $

str: db "Hello from the shell!", 0Ah, 0
strData: db "SS: 0x%X and SP: 0x%X", 0Ah, 0