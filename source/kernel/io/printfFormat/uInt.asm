;
; -------- [ PRINTFs UNSIGNED INT PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_UINT
%define IO_PRINTF_UINT

printf_format_uInt:
  push si                         ; Save string pointer

  mov si, [bp - 2]                ; Get pointer to arguments in SI
  add word [bp - 2], 2            ; Increase the argument point (+2 because each arg is two bytes)

  lea di, [bp - 3]

  mov ax, ss:[si]                    ; Get formatting argument in AX
  
  xor cx, cx                      ; Zero out digits counter (for printing the string later)
printf_format_uIntDigitsLoop:
  xor dx, dx
  mov bx, 10
  div bx
  add dl, 30h
  mov ss:[di], dl
  inc cx
  dec di
  test ax, ax
  jnz printf_format_uIntDigitsLoop 

printf_format_uIntPrintLoop:
  mov al, ss:[di + 1] 
  PRINT_CHAR al
  inc di
  loop printf_format_uIntPrintLoop

  pop si
  inc si
  jmp printf_printLoop

%endif