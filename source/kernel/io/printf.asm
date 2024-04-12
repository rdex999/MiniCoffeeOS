;
; ---------- [ PRINT FORMATED STRING ] ----------
;

%ifndef IO_PRINTF
%define IO_PRINTF

; Prints a formated string. (Just like the C printf);
; Supported formatting options:
;   - string            [ %s ]  => Null terminated string (16 bits)
;   - character         [ %c ]  => A single character (16 bits)
;   - signed integer    [ %d ]  => A positive/negative integer number (16 bits)  
;   - unsigned integer  [ %u ]  => A positive integer number (16 bits)
; PARAMS [ pushed to stack from right to left ]
; * Pointers are used from DS segment
;   - 0)    string
;   - 1..)  formating args (the number for %d for example)
printf:
  %define PRINTF_ARGUMENT_SIZE 2
  %define PRINTF_ARGUMENT_POINTER_SIZE 4
  %define PRINTF_BUFFER_START 9

  push bp
  mov bp, sp
  sub sp, 8+6

  mov [bp - 8], es              ; *(bp - 8) will hold the old ES
  mov bx, KERNEL_SEGMENT
  mov es, bx

  lea ax, [bp + 6]              ; *(bp + 6) is the second argument
  mov [bp - 2], ax              ; *(bp - 2) will be used as a pointer to the next argument on the stack

  mov si, [bp + 4]              ; SI will be used as the string pointer
  
  ; *(bp - 4) will be used as the current string beginning 
  ; (a beginning is after a formating option ( %d ) or the beginning of the string)
  mov [bp - 4], si              
  
  mov word [bp - 6], 0          ; *(bp - 6) will be used as the current string length

printf_printLoop:

  cld 
  lodsb

  cmp al, '%'
  je printf_checkFormat

  test al, al
  jz printf_nullChar

  inc word [bp - 6] 
  jmp printf_printLoop

printf_nullChar:
  mov si, [bp - 4]
  mov dx, [bp - 6]
  mov di, es:[trmColor]
  call printStrLen

printf_end:
  mov es, [bp - 8]
  mov sp, bp
  pop bp
  ret

printf_checkFormat:
  push si 
  mov si, [bp - 4]
  mov dx, [bp - 6]
  mov di, es:[trmColor]
  call printStrLen
  pop si

  lodsb
  mov [bp - 4], si
  mov word [bp - 6], 0

  cmp al, 'u'
  je printf_format_uInt

  ; cmp al, 'd'
  ; je printf_format_signedInt

  ; cmp al, 'c'
  ; je printf_format_char

  ; cmp al, 's'
  ; je printf_format_string

  ; cmp al, 'x'
  ; je printf_format_hex

  push ds
  mov bx, es
  mov ds, bx
  lea si, [printf_errorFormat]
  mov di, es:[trmColor]
  call printStr
  pop ds
  jmp printf_end

  printf_errorFormat: db "[ - printf ]: Error, invalid formatting option.", NEWLINE, 0

  %include "kernel/io/printfFormat/uInt.asm"
  ; %include "kernel/io/printfFormat/int.asm"
  ; %include "kernel/io/printfFormat/char.asm"
  ; %include "kernel/io/printfFormat/string.asm"
  ; %include "kernel/io/printfFormat/hex.asm"

%endif