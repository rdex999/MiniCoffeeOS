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
  %define PRINTF_ARGUMENT_POINTER_SIZE 2
  %define PRINTF_BUFFER_START 9

  push bp
  mov bp, sp
  sub sp, 8+6                   ; Allocte space for local variables, and a buffer of 6 bytes

  mov [bp - 8], es              ; *(bp - 8) will hold the old ES
  mov bx, KERNEL_SEGMENT        ; Set ES to kernel segment
  mov es, bx                    ; 

  lea ax, [bp + 6]              ; *(bp + 6) is the second argument
  mov [bp - 2], ax              ; *(bp - 2) will be used as a pointer to the next argument on the stack

  mov si, [bp + 4]              ; SI will be used as the string pointer
  
  ; *(bp - 4) will be used as the current string beginning 
  ; (a beginning is after a formating option ( %d ) or the beginning of the string)
  mov [bp - 4], si              
  
  mov word [bp - 6], 0          ; *(bp - 6) will be used as the current string length

printf_printLoop:

  cld                           ; Clear direction flag so LODSB will increase SI
  lodsb                         ; Load byte from DS:SI to AL, and increase SI

  cmp al, '%'                   ; Check if the character is a '%' (so should format)
  je printf_checkFormat         ; If it is then process it

  test al, al                   ; Check if its the end of the string
  jz printf_nullChar            ; If it is then return

  inc word [bp - 6]             ; Increase current string part length
  jmp printf_printLoop          ; Continue checking characters

printf_nullChar:
  mov si, [bp - 4]              ; Get the start of the current string part
  mov dx, [bp - 6]              ; Get the length of the current string part
  mov di, es:[trmColor]         ; Get the terminal color
  call printStrLen              ; Print the current string part

printf_end:
  mov es, [bp - 8]              ; Restore old ES
  mov sp, bp                    ; Restore stack frame
  pop bp                        ;
  ret

printf_checkFormat:
  push si                       ; Save string pointer
  mov si, [bp - 4]              ; Get start of current string part
  mov dx, [bp - 6]              ; Get current string part length
  mov di, es:[trmColor]         ; Get terminal color
  call printStrLen              ; Print current string part
  pop si                        ; Restore string pointer

  lodsb                         ; Load the next character (formatting option) from DS:SI, and increment SI 
  mov [bp - 4], si              ; SI now points to the character after the formatting option, so set that as the current string beginning
  mov word [bp - 6], 0          ; Reset the current string part length counter

  ; Check formatting options
  cmp al, 'u'
  je printf_format_uInt

  cmp al, 'd'
  je printf_format_signedInt

  cmp al, 'c'
  je printf_format_char

  cmp al, 's'
  je printf_format_string

  cmp al, 'x'
  je printf_format_hex

  ; If none of the above then print an error message saying thats an invalid formatting option 
  push ds                                         ; Save old DS segment
  mov bx, es                                      ; Set DS segment to kernel segment
  mov ds, bx                                      ; (ES if already set to kernel segment)
  lea si, [printf_errorFormat]                    ; Get pointer to string in SI (second argument)
  mov di, COLOR(VGA_TXT_RED, VGA_TXT_DARK_GRAY)   ; Print the message in red with a dark gray background
  call printStr                                   ; Print the error message
  pop ds                                          ; Restore old DS segment
  jmp printf_end                                  ; Return

  %include "kernel/io/printfFormat/uInt.asm"
  %include "kernel/io/printfFormat/int.asm"
  %include "kernel/io/printfFormat/char.asm"
  %include "kernel/io/printfFormat/string.asm"
  %include "kernel/io/printfFormat/hex.asm"

%endif