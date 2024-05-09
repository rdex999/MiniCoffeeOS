;
; --------- [ MACROS FOR PRINTING ] ----------
;

%ifndef PRINT_ASM
%define PRINT_ASM

%include "shared/interrupts.asm"

%macro PRINTF_INT_LM 1-*

  ; %0 gives the number of parameters passed to the macro.
  ; %rep is a NASM preprocessor command, which will repeate the following block of code N times.
  ; Basicaly push all the arguments from right to left, and dont push the string.
  %rep %0; - 1
    ; Rotate will rotate the macros arguments, (just like the ROR instruction)
    ; Say the arguments are 1, 2, 3, 4
    ; %rotate -1 ; ARGS: 4, 1, 2, 3     ; meaning %1 is 4
    %rotate -1
    push %1             ; Push the currently first arguemnts (as they rotate)
  %endrep
  ; push %{-1:-1}      ; Push the string buffer, as its the first argument for printf
  mov ax, INT_N_PRINTF
  int INT_F_KERNEL 
  %if %0 * 2 != 0
    add sp, %0 * 2        ; Free stack space
  %endif

%endmacro


%endif