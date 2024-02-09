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

  ; *(bp - 2) // Formatting arguments array pointer.
  ; *(bp - 7) // Buffer for formatting.
  sub sp, 2+6                     ; Allocate 7 bytes

  lea di, [bp + 6]              ; *(bp + 4) // First formatting argument
  mov [bp - 2], di              ; Store pointer to arguments array at *(bp - 2)

  mov si, [bp + 4]              ; Get pointer to first byte of the string in SI

printf_printLoop:
  mov al, [si]                  ; Since there will be a lot of compares, its better to compare a register instead of a pointer
  inc si
  
  ; Kind of like a switch-case, to check for special characters 
  cmp al, 0                       ; Check for null character
  je printf_end
  cmp al, 0Ah                     ; Check for newline
  je printf_newline
  cmp al, 0Bh                     ; Check for <tab>
  je printf_tab
  cmp al, '%'                     ; Check for percent ( % ), for formatting
  je printf_format

  ; If none of the above, then just print the character
  PRINT_CHAR al                   ; Print the character
  jmp printf_printLoop            ; Continue printing characters from string

printf_newline:
  PRINT_NEWLINE                   ; Print a newline (ascii 0Ah)
  jmp printf_printLoop            ; Continue printing characters from string

printf_tab:
  push si                         ; Save string pointer for now
  GET_CURSOR_POSITION 0           ; Get the column in DL
printf_tabLoop:
  PRINT_CHAR ' '                  ; Print a space
  inc dl                          ; Increase column number
  mov al, dl                      ; Store copy of column number in AL
  mov bl, 4                       ; Because divibing by 4
  xor ah, ah                      ; Zero remainder register
  div bl                          ; divibe the copy of the column number by 4
  test ah, ah                     ; Check if the remainder is 0 (to stop printing spaces)
  jnz printf_tabLoop              ; If the remainder is not zero then continue printing spaces

  ; Will get here when need to stop printing spaces
  pop si                          ; Restore string pointer
  jmp printf_printLoop            ; Continue printing characters from the string

printf_format:
  ; Again, kind of a switch case for checking formatting options.
  ; inc si                          ; Increase text pointer to point to formatting option
  mov al, [si]                    ; More efficient to compare a register and not pointers

  cmp al, 'd'                     ; Check signed integer
  je printf_format_signedInt
  cmp al, 'u'                     ; Check unsigned integer
  je printf_format_uInt
  cmp al, 's'
  je printf_format_string
  cmp al, 'c'
  je printf_format_char
  cmp al, '%'
  je printf_format_modulo

  ; If none of the above, then print an error message and return.
  lea di, [printf_errorFormat]    ; Get message pointer to DI
  call printStr                   ; Print the error message
  jmp printf_end                  ; Return

printf_format_modulo:
  PRINT_CHAR '%'
  inc si
  jmp printf_printLoop

%include "source/kernel/io/printfFormat/uInt.asm"
%include "source/kernel/io/printfFormat/int.asm"
%include "source/kernel/io/printfFormat/string.asm"
%include "source/kernel/io/printfFormat/char.asm"

printf_end:
  mov sp, bp
  pop bp
  ret

  printf_errorFormat: db "[ printf ]: Error, invalid formatting option.", NEWLINE, 0


%endif