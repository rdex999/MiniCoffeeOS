;
; -------- [ PRINTFs CHARACTER PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_CHAR
%define IO_PRINTF_CHAR

printf_format_char:
  mov di, [bp - 2]
  add word [bp - 2], 2

  mov ax, ss:[di]
  PRINT_CHAR al

  inc si
  jmp printf_printLoop


%endif