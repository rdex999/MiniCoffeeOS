; %define ISR_KEYBOARD_GET_SCANCODES

; Handles keyboard events, (interrupts)
ISR_keyboard:
  pusha                                       ; Save all registersz
  push bp                                     ; Set up stack fram
  mov bp, sp                                  ;

  push ds                                     ; Save old data segment
  mov bx, KERNEL_SEGMENT                      ; Make data segment the kernels data segment
  mov ds, bx                                  ; so we can access the right memory

  %ifdef ISR_KEYBOARD_GET_SCANCODES
    ;;;;;;;;; FOR DEBUG
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

    jmp ISR_keyboard_end
  %endif

  in al, PS2_DATA_PORT

  cmp al, KBD_SCANCODE_SPECIAL
  je ISR_keyboard_end

  cmp al, KBD_SCANCODE_NORM_BREAK
  je ISR_keyboard_breakNorm

  xor ah, ah
  mov di, ax
  mov al, ds:[kbdKeycodes + di]
  mov di, ax

  cmp al, ds:[kbdSkipForKey]
  jne ISR_keyboard_notToSkip

  mov byte ds:[kbdSkipForKey], 0
  jmp ISR_keyboard_end

ISR_keyboard_notToSkip:
  mov byte ds:[kbdSkipForKey], 0

  mov byte ds:[kbdKeys + di - 1], 1
  mov ds:[kbdCurrentKeycode], al

  jmp ISR_keyboard_end
ISR_keyboard_breakNorm:
  in al, PS2_DATA_PORT
  
  xor ah, ah
  mov di, ax
  mov al, ds:[kbdKeycodes + di]
  mov di, ax

  mov ds:[kbdSkipForKey], al

  mov byte ds:[kbdCurrentKeycode], 0
  mov byte ds:[kbdKeys + di - 1], 0

ISR_keyboard_end: 
  PIC8259_SEND_EOI IRQ_KEYBOARD                     ; Send an EOI to the PIC, so new interrupts can be called
  pop ds                                            ; Restore data segment
  mov sp, bp                                        ; Restore stack frame
  pop bp                                            ;
  popa                                              ; Restore all registers
  iret                                              ; Return from interrupt