; Sets flags in keyboardKeycodes, and keyboardCurrentKeycode
; **THIS IS NOT A FUNCTION, JUMP TO IT TO EXECUTE
; PARAMS
;   - 0) DI   => The keycode, (not the index in keyboardKeycodes, the index is keycode-1)
ISR_keyboard_setKeycode:
  cmp byte [bp - 1], 0
  je ISR_keyboard_setKeycode_pressed

  mov byte ds:[keyboardCurrentKeycode], 0
  mov byte ds:[keyboardKeycodes - 1 + di], 0
  jmp ISR_keyboard_end

ISR_keyboard_setKeycode_pressed:
  mov ax, di
  mov byte ds:[keyboardCurrentKeycode], al
  mov byte ds:[keyboardKeycodes - 1 + di], 1
  jmp ISR_keyboard_end

; Handles keyboard events, (interrupts)
ISR_keyboard:
  pusha
  push bp
  mov bp, sp

  ; sub sp, <size>
  dec sp

  mov byte [bp - 1], 0        ; Flag for if the key in released (0 for pressed, 1 for released)

  push ds

  mov bx, KERNEL_SEGMENT
  mov ds, bx

  cmp byte ds:[kbdSkipNextInt], 0
  je ISR_keyboard_dontSkipInt

  mov byte ds:[kbdSkipNextInt], 0
  jmp ISR_keyboard_end

ISR_keyboard_dontSkipInt:
  ; PRINT_NEWLINE
  ; in al, PS2_DATA_PORT
  ; xor ah, ah
  ; PRINT_INT16 ax

  ; PRINT_NEWLINE
  ; in al, PS2_DATA_PORT
  ; xor ah, ah
  ; PRINT_INT16 ax
  ; PRINT_NEWLINE
  ; jmp ISR_keyboard_end

  in al, PS2_DATA_PORT

  cmp al, KBD_SCANCODE_SPECIAL
  je ISR_keyboard_special_E0

  cmp al, KBD_SCANCODE_SPECIAL+1
  je ISR_keyboard_special_E1

  cmp al, KBD_SCANCODE_NORM_BREAK
  je ISR_keyboard_normBreak

ISR_keyboard_normChecks:
  cmp al, 76h
  je ISR_keyboard_76

  mov byte ds:[keyboardCurrentKeycode], 0

ISR_keyboard_end: 
  PIC8259_SEND_EOI IRQ_KEYBOARD
  pop ds
  mov sp, bp
  pop bp
  popa
  iret

ISR_keyboard_special_E0:
  jmp ISR_keyboard_end

ISR_keyboard_special_E1:
  jmp ISR_keyboard_end

ISR_keyboard_normBreak:
  mov byte ds:[kbdSkipNextInt], 1
  mov byte [bp - 1], 1
  in al, PS2_DATA_PORT
  jmp ISR_keyboard_normChecks

ISR_keyboard_76:
  mov di, 1
  jmp ISR_keyboard_setKeycode
