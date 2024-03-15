;
; ---------- [ INTERRUPT SECRIVE ROUTINES ] ----------
;

%include "source/kernel/isr/divZero.asm"

%ifdef KBD_DRIVER
  %include "source/kernel/isr/keyboard.asm"
%endif