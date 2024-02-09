;
; ---------- [ PRINTFs STRING PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_STRING
%define IO_PRINTF_STRING

printf_format_string:
  push si                         ; Save string pointer

  mov si, [bp - 2]                ; Get pointer to arguments in SI
  add word [bp - 2], 2            ; Increase the argument point (+2 because each arg is two bytes)

  mov si, ss:[si]

printf_format_stringLoop:
  cmp byte [si], 0
  je printf_format_stringEnd
  mov al, [si]
  PRINT_CHAR al 
  inc si
  jmp printf_format_stringLoop

printf_format_stringEnd:
  pop si
  inc si
  jmp printf_printLoop

%endif