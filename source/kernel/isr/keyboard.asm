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

  ; Basicaly check if we should skip this interuppt, as some times the keyboard sends more interrupts after one
  cmp byte ds:[kbdSkipIntCount], 0                  ; Check if the skip counter is zero
  je ISR_keyboard_start                             ; If it is zero, then continue and process this interrupt

  ; If its not zero then decrement it, and return from this interrupt
  dec byte ds:[kbdSkipIntCount]                     ; Decrement skip interrupt counter
  ; mov byte ds:[kbdSkipIntCount], 0
  jmp ISR_keyboard_end                              ; Return from this interrupt

ISR_keyboard_start:
  in al, PS2_DATA_PORT

  cmp al, KBD_SCANCODE_SPECIAL
  je ISR_keyboard_end

  cmp al, KBD_SCANCODE_NORM_BREAK
  je ISR_keyboard_breakNorm

  xor ah, ah
  mov di, ax
  mov al, ds:[kbdKeycodes + di]
  mov di, ax

  mov byte ds:[kbdKeys + di - 1], 1
  mov ds:[kbdCurrentKeycode], al

  jmp ISR_keyboard_end
ISR_keyboard_breakNorm:
  in al, PS2_DATA_PORT
  
  xor ah, ah
  mov di, ax
  mov al, ds:[kbdKeycodes + di]
  mov di, ax
  
  mov byte ds:[kbdCurrentKeycode], 0
  mov byte ds:[kbdKeys + di - 1], 0
  mov byte ds:[kbdSkipIntCount], 1

ISR_keyboard_end: 
  PIC8259_SEND_EOI IRQ_KEYBOARD                     ; Send an EOI to the PIC, so new interrupts can be called
  pop ds                                            ; Restore data segment
  mov sp, bp                                        ; Restore stack frame
  pop bp                                            ;
  popa                                              ; Restore all registers
  iret                                              ; Return from interrupt