;
; --------- [ PROCESS RELATED INTERRUPTS ] ---------
;


%ifndef INT_PROCESS_ASM
%define INT_PROCESS_ASM

; Terminate the current process. (exit)
; Doesnt take any parameters
; Doesnt return anything
ISR_exit:
  push gs                                         ; Save current GS because were changing it
  mov bx, KERNEL_SEGMENT                          ; Set GS to the kernels segment so we can access the currently running process
  mov gs, bx                                      ;
  mov di, gs:[currentProcessIdx]                  ; Get the current process index
  inc di                                          ; Convert it into a PID
  and di, 0FFh                                    ; PID is only 8 bits
  pop gs                                          ; Restore GS

  call terminateProcess                           ; Terminate the process

  jmp ISR_kernelInt_end                           ; Return from the interrupt

%endif