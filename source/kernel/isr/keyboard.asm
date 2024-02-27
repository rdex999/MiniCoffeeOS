; %define ISR_KEYBOARD_GET_SCANCODES

; Sets DI to the keycode, and executes ISR_keyboard_setKeycode
; PARAMS
;   - 0) int16    => The keycode, (not the index in keyboardKeycodes, the index is keycode-1)
%macro ISR_KEYBOARD_NORM_KEY_EVENT 1

  mov di, %1
  jmp ISR_keyboard_setKeycode

%endmacro

; Jumps if AL == scancode
; PARANS
;   - 0) The scancode to compare AL to
;   - 1) the lable to jump to if equal
%macro ISR_KEYBOARD_SCANCODE_JUMP 2

  cmp al, %1
  je %2

%endmacro

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

  cli

  push ds

  mov bx, KERNEL_SEGMENT
  mov ds, bx

  cmp byte ds:[kbdSkipNextInt], 0
  je ISR_keyboard_dontSkipInt

  mov byte ds:[kbdSkipNextInt], 0
  jmp ISR_keyboard_end

ISR_keyboard_dontSkipInt:
  %ifdef ISR_KEYBOARD_GET_SCANCODES
    PRINT_NEWLINE
    in al, PS2_DATA_PORT
    xor ah, ah
    PRINT_INT16 ax

    PRINT_NEWLINE
    in al, PS2_DATA_PORT
    xor ah, ah
    PRINT_INT16 ax
    PRINT_NEWLINE
    jmp ISR_keyboard_end
  %endif

  call ps2_8042_waitOutput
  in al, PS2_DATA_PORT

  cmp al, KBD_SCANCODE_SPECIAL
  je ISR_keyboard_special_E0

  cmp al, KBD_SCANCODE_SPECIAL+1
  je ISR_keyboard_special_E1

  cmp al, KBD_SCANCODE_NORM_BREAK
  je ISR_keyboard_normBreak

ISR_keyboard_normChecks:
  ISR_KEYBOARD_SCANCODE_JUMP 76h, ISR_keyboard_76   ; <ESC>

  ISR_KEYBOARD_SCANCODE_JUMP 5h, ISR_keyboard_5     ; <F1>

  ISR_KEYBOARD_SCANCODE_JUMP 6h, ISR_keyboard_6     ; <F2>

  ISR_KEYBOARD_SCANCODE_JUMP 4h, ISR_keyboard_4     ; <F3>

  ISR_KEYBOARD_SCANCODE_JUMP 0Ch, ISR_keyboard_C    ; <F4>

  ISR_KEYBOARD_SCANCODE_JUMP 3h, ISR_keyboard_3     ; <F5>

  ISR_KEYBOARD_SCANCODE_JUMP 0Bh, ISR_keyboard_B    ; <F6>

  ISR_KEYBOARD_SCANCODE_JUMP 83h, ISR_keyboard_83   ; <F7>

  ISR_KEYBOARD_SCANCODE_JUMP 0Ah, ISR_keyboard_A    ; <F8>
  
  ISR_KEYBOARD_SCANCODE_JUMP 1h, ISR_keyboard_1     ; <F9>
  
  ISR_KEYBOARD_SCANCODE_JUMP 9h, ISR_keyboard_9     ; <F10>


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
  call ps2_8042_waitOutput
  in al, PS2_DATA_PORT
  jmp ISR_keyboard_normChecks

ISR_keyboard_76:
  ISR_KEYBOARD_NORM_KEY_EVENT 1

ISR_keyboard_5:
  ISR_KEYBOARD_NORM_KEY_EVENT 2

ISR_keyboard_6:
  ISR_KEYBOARD_NORM_KEY_EVENT 3

ISR_keyboard_4:
  ISR_KEYBOARD_NORM_KEY_EVENT 4

ISR_keyboard_C:
  ISR_KEYBOARD_NORM_KEY_EVENT 5

ISR_keyboard_3:
  ISR_KEYBOARD_NORM_KEY_EVENT 6

ISR_keyboard_B:
  ISR_KEYBOARD_NORM_KEY_EVENT 7

ISR_keyboard_83:
  ISR_KEYBOARD_NORM_KEY_EVENT 8

ISR_keyboard_A:
  ISR_KEYBOARD_NORM_KEY_EVENT 9

ISR_keyboard_1:
  ISR_KEYBOARD_NORM_KEY_EVENT 10

ISR_keyboard_9:
  ISR_KEYBOARD_NORM_KEY_EVENT 11