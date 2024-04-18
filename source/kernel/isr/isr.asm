;
; ---------- [ INTERRUPT SECRIVE ROUTINES ] ----------
;

%include "kernel/isr/divZero.asm"
%include "kernel/isr/pitChannel0.asm"

%ifdef KBD_DRIVER
  %include "kernel/isr/keyboard.asm"
%endif