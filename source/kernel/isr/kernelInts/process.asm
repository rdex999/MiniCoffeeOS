;
; --------- [ PROCESS RELATED INTERRUPTS ] ---------
;


%ifndef INT_PROCESS_ASM
%define INT_PROCESS_ASM

; Terminate the current process. (exit)
; PARAMETERS
;   - 0) DI   => The error code. Set this to 0 if there was no error, and an error code otherwise
; Doesnt return anything
ISR_exit:
  call terminateCurrentProcess                    ; Terminate the current process
  jmp ISR_kernelInt_end                           ; Return from the interrupt

%endif