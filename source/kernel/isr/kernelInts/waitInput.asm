;
; ---------- [ WAIT FOR A STRING INPUT ] ---------
;

%ifndef WAIT_INPUT_ASM
%define WAIT_INPUT_ASM

; Wait for a string input, which ends when the user presses the ENTER key.
; PARAMS
;   - 0) ES:DI  => The buffer to store the data in
;   - 1) SI     => The maximum amount of bytes to read
; RETURNS
;   - 0) AX     => The amount of bytes actualy read
ISR_waitInput:
  call read                     ; Wait for input from the user
  jmp ISR_kernelInt_end_restBX  ; Return from the interrupt, while the amount of bytes read is in AX

%endif