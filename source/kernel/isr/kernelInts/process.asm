;
; --------- [ PROCESS RELATED INTERRUPTS ] ---------
;


%ifndef INT_PROCESS_ASM
%define INT_PROCESS_ASM

; Terminate the current process. (exit)
; Doesnt take any parameters
; Doesnt return anything
ISR_exit:
  push gs                                         ; Save GS, because were gonna change it
  mov bx, KERNEL_SEGMENT                          ; Set GS to the kernels segment, so we can access the processes array
  mov gs, bx                                      ;

  mov al, gs:[currentProcessIdx]                  ; Get the index of the current process (not this interrupt)
  xor ah, ah                                      ; Zero out high 8 bits
  mov bx, PROCESS_DESC_SIZEOF                     ; We want to multiply by the size of a process descriptor
  mul bx                                          ; Get the offset into the processes array, for the current process (offset in AX)

  lea si, processes                               ; Get a pointer to the processes array
  add si, ax                                      ; Offset it into the current process

  mov byte gs:[si + PROCESS_DESC_FLAGS8], 0       ; Set the processes flags to 0
  mov word gs:[si + PROCESS_DESC_SLEEP_MS16], 0   ; Set its sleep time to 0

  pop gs                                          ; Restore GS
  jmp ISR_kernelInt_end                           ; Return from the interrupt

%endif