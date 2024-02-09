;
; -------- [ PRINTFs INT PRINT ROUTINE ] ----------
;

%ifndef IO_PRINTF_INT
%define IO_PRINTF_INT


printf_format_signedInt:
  push si                         ; Save string pointer

  mov si, [bp - 2]                ; Get pointer to arguments in SI
  add word [bp - 2], 2            ; Increase the argument point (+2 because each arg is two bytes)

  lea di, [bp - 3]                ; Get pointer to first byte of buffer

  mov ax, ss:[si]                 ; Get formatting argument in AX
  mov bx, ax                      ; BX = The number to print
  shl bx, 1                       ; Check if the number is negative
  jnc printf_format_signedIntInit ; Jump if positive

  mov si, ax                      ; Save number
  PRINT_CHAR '-'                  ; Print a '-' to because negative
  mov ax, si                      ; Restore number
  neg ax                          ; Negate the number and print as positive.

printf_format_signedIntInit:
  xor cx, cx                      ; Zero out digits counter (for printing the string later)
printf_format_intDigitsLoop:
  xor dx, dx                      ; Zero out remainder register
  mov bx, 10                      ; For divibing by 10
  div bx                          ; Divibe the number by 10, and get last digit in DL
  add dl, 30h                     ; Convert digit to ascii
  mov ss:[di], dl                 ; Store digit (as ascii) in buffer
  inc cx                          ; Increase characters counter
  dec di                          ; Decrement buffer
  test ax, ax                     ; Check if the division result is 0 (is there are no more digits to print)
  jnz printf_format_intDigitsLoop ; While its not zero continue getting digits to buffer

printf_format_intPrintLoop:
  mov al, ss:[di + 1]             ; Get character in AL
  PRINT_CHAR al                   ; Print AL
  inc di                          ; Increase pointer
  loop printf_format_intPrintLoop ; Print characters from DI as long as CX > 0

  pop si                          ; Restore string pointer
  inc si                          ; Increase string pointer to point to character after the formatting option
  jmp printf_printLoop            ; Continue printing characters from string

%endif