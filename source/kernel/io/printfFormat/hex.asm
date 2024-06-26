;
; -------- [ PRINTFs HEXADECIMAL PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_HEX
%define IO_PRINTF_HEX

printf_format_hex:
  push si

  mov si, [bp - 2]                          ; Get the array pointer in SI
  add word [bp - 2], PRINTF_ARGUMENT_SIZE   ; Make argument pointer point to next argument
  lea di, [bp - PRINTF_BUFFER_START]

  mov si, ss:[si]                           ; Get the number to print in SI

printf_format_hexDigitsLoop:
  mov ax, si
  and ax, 0Fh                         ; Remove upper bytes, and leave the 4 LSBs
  cmp al, 0Ah
  jl printf_format_hexLetter

  add al, 37h                         ; Convert digit to ascii letter
  jmp printf_format_hexSkipLetter

printf_format_hexLetter:
  add al, 30h                         ; Convert digit to ascii number

printf_format_hexSkipLetter:
  mov ss:[di], al                        ; Store letter/number in buffer
  dec di
  shr si, 4                           ; Remove last hex digit from number
  test si, si
  jnz printf_format_hexDigitsLoop

  lea cx, [bp - PRINTF_BUFFER_START]
  sub cx, di                          ; Get how many digits were found
printf_format_hexPrintLoop:
  inc di
  push di
  push cx
  mov al, ss:[di]
  mov ah, es:trmColor
  PRINT_CHAR al, ah
  pop cx
  pop di

  loop printf_format_hexPrintLoop

  pop si
  jmp printf_printLoop

%endif