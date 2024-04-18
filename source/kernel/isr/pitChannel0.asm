;
; ---------- [ HANDLER FOR PIT INTERRUPTS ] ----------
;

ISR_pitChannel_0:
  push ax

  ; PRINT_CHAR 'Q', VGA_TXT_YELLOW

  PIC8259_SEND_EOI INT_PIT_CHANNEL0

  pop ax
  iret