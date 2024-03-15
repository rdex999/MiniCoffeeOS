%define ISR_KEYBOARD_GET_SCANCODES

; Handles keyboard events, (interrupts)
ISR_keyboard:
  pusha                                       ; Save all registersz
  push bp                                     ; Set up stack fram
  mov bp, sp                                  ;

  ; sub sp, <size>
  dec sp                                      ; Allocate 1 byte

  push ds
  mov bx, KERNEL_SEGMENT
  mov ds, bx

  %ifdef ISR_KEYBOARD_GET_SCANCODES
    PRINT_NEWLINE
    in al, PS2_DATA_PORT
    xor ah, ah
    PRINT_HEX16 ax
    PRINT_NEWLINE

    in al, PS2_DATA_PORT
    xor ah, ah
    PRINT_HEX16 ax
    PRINT_NEWLINE

    in al, PS2_DATA_PORT
    xor ah, ah
    PRINT_HEX16 ax
    PRINT_NEWLINE
  %endif

ISR_keyboard_end: 
  PIC8259_SEND_EOI IRQ_KEYBOARD                     ; Send an EOI to the PIC, so new interrupts can be called
  pop ds                                            ; Restore data segment
  mov sp, bp                                        ; Restore stack fram
  pop bp                                            ;
  popa                                              ; Restore all registers
  iret                                              ; Return from interrupt