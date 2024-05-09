;
; ---------- [ USER RELATED INTERRUPTS ] ---------
;

%ifndef INT_USER_ASM
%define INT_USER_ASM


; Get the current directory that the user is at
; PARAMETERS
;   - 0) ES:DI  => A buffer to write the data into
; Doesnt return anything
ISR_getUserPath:
  push ds
  mov bx, KERNEL_SEGMENT
  mov ds, bx

  lea si, currentUserDirPath
  call strcpy

  pop ds

  jmp ISR_kernelInt_end

%endif