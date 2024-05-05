;
; ---------- [ WAIT FOR A STRING INPUT ] ---------
;

%ifndef WAIT_INPUT_ASM
%define WAIT_INPUT_ASM


ISR_waitInput:
  call read                   ; Wait for input from the user
  jmp ISR_kernelInt_end       ; Return from the interrupt, while the amount of bytes read is in AX

%endif