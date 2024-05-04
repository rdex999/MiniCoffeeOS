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