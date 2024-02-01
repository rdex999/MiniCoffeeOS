;
; ---------- [ BASIC MACROS FOR BOOTLOADER ] ----------
;

%ifndef MACROS_ASM
%define MACROS_ASM

%include "source/bootloader/macros/getRegions.asm"

; prints an 11 byte string (this macro is for debuggind)
; PARAMS
;   0) const char* => the string
%macro PRINT_STR11 1

  mov di, %1
  mov cx, 11
%%printAgain:
  mov al, [di]
  mov ah, 0Eh
  int 10h
  inc di
  loop %%printAgain

%endmacro

%endif