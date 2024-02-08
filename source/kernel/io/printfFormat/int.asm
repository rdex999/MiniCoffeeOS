;
; -------- [ PRINTFs INT PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_INT
%define IO_PRINTF_INT


printf_format_signedInt:
  push si                         ; Save string pointer

  mov si, [bp - 2]                ; Get pointer to arguments in SI
  add word [bp - 2], 2            ; Increase the argument point (+2 because each arg is two bytes)

  lea di, [bp - 3]

  mov ax, ss:[si]                 ; Get formatting argument in AX
  mov bx, ax                      ; BX = The number to print
  shl bx, 1                       ; Check if the number is negative
  jnc printf_format_signedIntInit ; Jump if positive

  mov si, ax
  PRINT_CHAR '-'
  mov ax, si
  neg ax

printf_format_signedIntInit:
  xor cx, cx                      ; Zero out digits counter (for printing the string later)
printf_format_intDigitsLoop:
  xor dx, dx
  mov bx, 10
  div bx
  add dl, 30h
  mov ss:[di], dl
  inc cx
  dec di
  test ax, ax
  jnz printf_format_intDigitsLoop 

printf_format_intPrintLoop:
  mov al, ss:[di + 1] 
  PRINT_CHAR al
  inc di
  loop printf_format_intPrintLoop

  pop si
  inc si
  jmp printf_printLoop

%endif