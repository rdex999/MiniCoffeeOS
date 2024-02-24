; Handles keyboard events, (interrupts)
ISR_keyboard:
  pusha

  PRINT_NEWLINE
  in al, PS2_DATA_PORT
  xor ah, ah
  PRINT_INT16 ax

  PRINT_NEWLINE
  in al, PS2_DATA_PORT
  xor ah, ah
  PRINT_INT16 ax
  PRINT_NEWLINE


  PIC8259_SEND_EOI 1  
  popa

  iret