;
; ---------- [ PRINT FORMATED STRING ] ----------
;

%ifndef IO_PRINTF
%define IO_PRINTF

; Prints a formated string. (Just like the C printf);
; Supported formatting options:
;   - string            [ %s ]  => Null terminated string (16 bits)
;   - character         [ %c ]  => A single character (8 bits)
;   - signed integer    [ %d ]  => A positive/negative integer number (16 bits)  
;   - unsigned integer  [ %u ]  => A positive integer number (16 bits)
; PARAMS [ pushed to stack from right to left ]
;   - 0)    string
;   - 1..)  formating args (the number for %d for example)
printf:
  push bp
  mov bp, sp
  sub sp, 4

  lea ax, [bp + 6]              ; *(bp + 6) is the second argument
  mov [bp - 2], ax              ; *(bp - 2) will be used as a pointer to the next argument on the stack

  ; mov si, [bp - ]



printf_end:
  mov sp, bp
  pop bp
  ret

  printf_errorFormat: db "[ printf ]: Error, invalid formatting option.", NEWLINE, 0


%endif