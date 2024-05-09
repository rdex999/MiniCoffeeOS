;
; --------- [ PROCESS RELATED INTERRUPTS ] ---------
;


%ifndef INT_PROCESS_ASM
%define INT_PROCESS_ASM

; Terminate the current process. (exit)
; Doesnt take any parameters
; Doesnt return anything
ISR_exit:
  push gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx

  mov al, gs:[currentProcessIdx]
  xor ah, ah
  mov bx, PROCESS_DESC_SIZEOF
  mul bx

  lea si, processes
  add si, ax

  mov byte gs:[si + PROCESS_DESC_FLAGS8], 0
  mov word gs:[si + PROCESS_DESC_SLEEP_MS16], 0

  pop gs
  jmp ISR_kernelInt_end

%endif