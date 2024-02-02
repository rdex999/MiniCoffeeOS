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

; prints a single character
%macro PRINT_CHAR 1

  mov ah, 0Eh
  mov al, %1
  int 10h

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