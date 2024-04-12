;
; -------- [ PRINTFs CHARACTER PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_CHAR
%define IO_PRINTF_CHAR

printf_format_char:
  mov di, [bp - 2]
  add word [bp - 2], PRINTF_ARGUMENT_SIZE

  push si
  mov ax, ss:[di]
  mov ah, es:[trmColor]
  PRINT_CHAR al, ah
  pop si

  jmp printf_printLoop

%endif