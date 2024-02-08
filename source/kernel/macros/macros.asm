;
; ---------- [ BASIC MACROS ] ----------
;

%ifndef MACROS_ASM
%define MACROS_ASM

; LC stands for: Line Feed, Carriage Return
%define NEWLINE_LC 0Ah, 0Dh
%define NEWLINE 0Ah
%define TAB 0Bh

; 2*20*512  // 2 FATs, 20 sectors per fat, 512 bytes per sector
%define TOTAL_FAT_SIZE 20480

; 512 * 32 = 16384   // 512 => root directory entries // 32 bytes per entry
%define ROOT_DIRECTORY_SIZE 16384

%define KERNEL_SEGMENT 2000h

; compares two strings and if equal then jump to given lable
%macro STRCMP_JUMP_EQUAL 3

  lea di, %1
  lea si, %2
  call strcmp
  test ax, ax
  jz %3

%endmacro

%macro CMDCMP_JUMP_EQUAL 3

  lea di, [%1]
  lea si, [%2]
  call cmdcmp
  test ax, ax
  jz %3

%endmacro

; prints 10 and 13 (ascii codes). goes down a line
%macro PRINT_NEWLINE 0

  mov ah, 0Eh
  mov al, 10
  int 10h

  mov ah, 0Eh
  mov al, 13
  int 10h

%endmacro


%macro PRINT_STR11 1

  lea di, [%1]
  mov cx, 11
%%printAgain:
  mov al, es:[di]
  mov ah, 0Eh
  int 10h
  inc di
  loop %%printAgain

%endmacro

; Prints a string, example: PRINT_STR "Hello world!"
%macro PRINT_STR 1

  pusha                       ; Save all registers. I know pusha sucks, but its good enough for debugging
  jmp %%skipStrBuffer         ; Skip string buffer declaration 
%%strBuffer: db %1, 0         ; Declare the string, as %1 is replaced with its content

%%skipStrBuffer:
  lea si, %%strBuffer         ; Get a pointer to the first byte of the string
%%printAgain:
  cmp byte [si], 0            ; Check for null character
  je %%stopPrint              ; If null then stop printing
  mov ah, 0Eh                 ; int10h/AH-0Eh print character and advance cursor
  mov al, [si]                ; Get next character from string
  int 10h                     ; Print character from AL
  inc si                      ; Increase string pointer
  jmp %%printAgain            ; Continue printing characters

%%stopPrint:
  popa                        ; Restore all registers. (Again IK popa sucks, but its ok for debug)

%endmacro

; prints a single character
%macro PRINT_CHAR 1

  mov ah, 0Eh
%if %1 != al 
  mov al, %1
%endif
  int 10h

%endmacro

; Not the best, but good enough for debugging
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


; sets the cursors position
; PARAMS
; 0) int => row
; 1) int => column
; 2) int => page
%macro SET_CURSOR_POSITION 3

  mov ah, 2h 
  mov dh, %1
  mov dl, %2
  mov bh, %3
  int 10h

%endmacro


; Gets the cursors position
; PARAMS
; 0) int16 => page number
; RETURNS
; 0) DH => row
; 1) DL => column
; 2) CH => cursor start position
; 3) CL => cursor bottom line
%macro GET_CURSOR_POSITION 1

  ; since XOR is more efficient
  %if %1 == 0
    xor bh, bh
  %else
    mov bh, %1
  %endif

  mov ah, 3
  int 10h

%endmacro



%endif