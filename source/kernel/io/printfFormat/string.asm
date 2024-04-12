;
; ---------- [ PRINTFs STRING PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_STRING
%define IO_PRINTF_STRING

printf_format_string:
  push si                                           ; Save string pointer

  mov si, [bp - 2]                                  ; Get pointer to arguments in SI

  add word [bp - 2], PRINTF_ARGUMENT_POINTER_SIZE   ; Increase the argument point (+2 because each arg is two bytes)


  mov si, ss:[si]
  mov di, es:[trmColor]
  call printStr

  pop si 
  jmp printf_printLoop

%endif