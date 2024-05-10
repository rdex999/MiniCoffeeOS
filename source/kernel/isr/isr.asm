;
; ---------- [ INTERRUPT SECRIVE ROUTINES ] ----------
;

%include "kernel/isr/divZero.asm"
%include "kernel/isr/pitChannel0.asm"
%include "kernel/isr/cmosUpdate.asm"
%include "kernel/isr/kernelInt.asm"

%ifdef KBD_DRIVER
  %include "kernel/isr/keyboard.asm"
%endif

; This ISR handles multiple interrupts, which are dangerous for the CPU
; so much that were terminating the current process, which made the error.
ISR_invalidOpcode:
  pusha 

  PRINT_CHAR 'I', VGA_TXT_YELLOW
  call terminateCurrentProcess            ; Terminate the current process
  popa
  iret                                    ; Return from the interrupt
