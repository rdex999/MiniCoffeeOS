;
; ---------- [ BASIC MACROS FOR BOOTLOADER ] ----------
;

%ifndef MACROS_ASM
%define MACROS_ASM

%include "bootloader/macros/getRegions.asm"

; prints an 11 byte string (this macro is for debuggind)
; PARAMS
;   0) const char* => the string
%macro PRINT_STR11 1

%if %1 != di
  mov di, %1
%endif
  mov cx, 11
%%printAgain:
  mov al, [di]
  mov ah, 0Eh
  int 10h
  inc di
  loop %%printAgain

%endmacro

%macro PRINT_CHAR 1

%if %1 != al
  mov al, %1
%endif
  mov ah, 0Eh
  int 10h

%endmacro

%macro PRINT_INT16 1

  pusha                             ; Save all registers

  mov si, sp
  sub sp, 6                         ; Allocate 6 bytes on stack
  mov byte ss:[si], 0               ; Zero terminate the string

  %if %1 != ax
    mov ax, %1                      ; AX will be divided by 10 each time to get the last digit of the number
  %endif

  ; Each time, divibe the nunber by 10 and get the remainder. 1234 % 10 = 4 // 123 % 10 = 3 // ...... // 1 % 10 = 1 ; AX = 0
%%nextDigit:
  push ax                           ; Save AX (for some reason AX cant survive 3 instructions)
  dec si                            ; Decrement buffer pointer
  xor dx, dx                        ; Zero out division remainder
  mov bx, 10                        ; Divibe by 10 to get last digit in DL/DX
  pop ax                            ; Restore AX, for divibing it
  div bx                            ; AX /= BX // Get last digit in DL
  add dl, 48                        ; Convert to ascii
  mov ss:[si], dl                   ; Store digit in buffer
  test ax, ax                       ; If the result of the division is not zero then continue
  jnz %%nextDigit

%%printLoop:
  cmp byte ss:[si], 0               ; Check for null character, so dont print it
  je %%stopPrint                    ; If null the stop printing
  mov ah, 0Eh                       ; int10h/AH=0Eh   // print character and advance cursor
  mov al, ss:[si]                   ; Get character in AL
  int 10h                           ; Print character
  inc si                            ; Increase buffer pointer
  jmp %%printLoop                   ; Continue printing

%%stopPrint:
  add sp, 6                         ; Free 6 bytes
  popa                              ; Restore registers

%endmacro

%macro PRINT_NEWLINE 0

  PRINT_CHAR 0Ah
  PRINT_CHAR 0Dh

%endmacro

%endif