;
; -------- [ PRINTFs UNSIGNED INT PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_UINT
%define IO_PRINTF_UINT

printf_format_uInt:
  push si                                 ; Save string pointer

  mov si, [bp - 2]                        ; Get pointer to arguments in SI
  add word [bp - 2], PRINTF_ARGUMENT_SIZE ; Increase the argument pointer (+2 because each arg is two bytes)

  lea di, [bp - PRINTF_BUFFER_START]      ; Get pointer to first byte of buffer

  mov ax, ss:[si]                         ; Get formatting argument in AX
  
  xor cx, cx                              ; Zero out digits counter (for printing the string later)
printf_format_uIntDigitsLoop:
  xor dx, dx                        ; Zero out remainder register
  mov bx, 10                        ; For divibing by 10
  div bx                            ; Divibe the number by 10, and get last digit in DL
  add dl, 30h                       ; Convert digit to ascii
  mov ss:[di], dl                   ; Store digit (as ascii) in buffer
  inc cx                            ; Increase characters counter
  dec di                            ; Decrement buffer
  test ax, ax                       ; Check if the division result is 0 (is there are no more digits to print)
  jnz printf_format_uIntDigitsLoop  ; While its not zero continue getting digits to buffer

printf_format_uIntPrintLoop:
  mov al, ss:[di + 1]                 ; Get character in AL
  mov ah, es:[trmColor]
  push di
  push cx
  PRINT_CHAR al, ah                   ; Print AL
  pop cx
  pop di 
  inc di                              ; Increase pointer
  loop printf_format_uIntPrintLoop    ; Print characters from DI as long as CX > 0

  pop si                              ; Restore string pointer
  jmp printf_printLoop                ; Continue printing characters from string

%endif