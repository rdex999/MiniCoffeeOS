;
; ---------- [ INTERRUPT SECRIVE ROUTINES ] ----------
;

%include "kernel/isr/divZero.asm"

%ifdef KBD_DRIVER
  %include "kernel/isr/keyboard.asm"
%endif