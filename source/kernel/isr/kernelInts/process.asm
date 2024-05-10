;
; --------- [ PROCESS RELATED INTERRUPTS ] ---------
;


%ifndef INT_PROCESS_ASM
%define INT_PROCESS_ASM

; Terminate the current process. (exit)
; Doesnt take any parameters
; Doesnt return anything
ISR_exit:
  call terminateCurrentProcess                    ; Terminate the current process
  jmp ISR_kernelInt_end                           ; Return from the interrupt

%endif