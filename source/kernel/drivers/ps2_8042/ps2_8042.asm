; The PS/2 8042 micro controller chip (keyboard controller) is used to interact with the keyboard,
; and some unrelated stuff that was supported to reduce costs.

; Wait until bit 1 (value = 2) of status register is cleared, means that can send commands.
; Takes no arguments.
ps2_8042_waitInput:
  in al, PS2_STATUS_REGISTER
  test al, 2
  jnz ps2_8042_waitInput
  ret

; Wait until bit 0 (value = 1) of status register is set.
; Basicaly wait until there is data waiting for us in the data port.
; Takes no arguments.
ps2_8042_waitOutput:
  in al, PS2_STATUS_REGISTER
  test al, 1
  jz ps2_8042_waitOutput
  ret

; Waits for a key press from the keyboard
; Takes no parameters
; RETURNS
;   - AL      => The keycode
kbd_waitForKeycode:
  push ds
  mov bx, KERNEL_SEGMENT
  mov ds, bx
  sti
kbd_waitForKeycode_waitLoop:
  hlt
  cmp byte ds:[kbdCurrentKeycode], 0
  je kbd_waitForKeycode_waitLoop

  mov al, ds:[kbdCurrentKeycode]
kbd_waitForKeycode_end:
  pop ds 
  ret


; Waits for a printable key to be pressed, or multiple keys which correspond to one character
; For example <SHIFT> + <A> => 'A'
; Takes to parameters
; RETURNS
;   - AL      => The ascii code for the character. (The character)
kbd_waitForChar:
  push ds                                 ; Save old data segment
  mov bx, KERNEL_SEGMENT                  ; Set data segment to kernel segment so we can access keyboard variables
  mov ds, bx                              ; 
  
kbd_waitForChar_waitValid:
  call kbd_waitForKeycode                 ; Wait for a key code, which will be in AL

  test al, al                             ; Check if the keycode is valid. (Zero is an invalid keycode)
  jz kbd_waitForChar_end                  ; If its zero then just return zero

  cmp al, KBD_KEY_LEFT_SHIFT              ; Check if it was the shift key
  je kbd_waitForChar_waitValid            ; If the shift key was pressed, skip it, and continue waiting for another key

  cmp al, KBD_KEY_RIGHT_SHIFT             ; Check if it was the right shift key
  je kbd_waitForChar_waitValid            ; If the shift key was pressed, skip it, and continue waiting for another key

  cmp al, KBD_KEY_CAPSLOCK                ; Check if it was the caps lock
  je kbd_waitForChar_waitValid            ; Again, caps lock doesnt matter, just continue waiting for a key

  ; Will get here once we got a real key (not shift or caps lock)
  xor ah, ah                              ; We want to use the key code as an index
  mov di, ax                              ; Access memory with Di

  GET_KEY_STATE KBD_KEY_LEFT_SHIFT        ; Check if the left shift key is currently being pressed
  jne kbd_waitForChar_capital             ; If it is, then process for a capital letter
  
  GET_KEY_STATE KBD_KEY_RIGHT_SHIFT        ; Check if the right shift key is currently being pressed
  jne kbd_waitForChar_capital
  
  GET_KEY_STATE KBD_KEY_CAPSLOCK          ; Check if caps lock is on
  jne kbd_waitForChar_capslock            ; If caps lock is one then process for caps lock

  ; Will get here if no shift key is pressed or caps lock, processing for a lower case letter
  mov al, ds:[kbdAsciiCodes - 1 + di]     ; Get lower case letter ascii for keycode
  jmp kbd_waitForChar_afterCapState       ; 

kbd_waitForChar_capital:
  GET_KEY_STATE KBD_KEY_CAPSLOCK
  jne kbd_waitForChar_capital_withCaps

  mov al, ds:[kbdAsciiCapCodes - 1 + di]  ; If shift was pressed, then get the capital ascii character for the keycode
  jmp kbd_waitForChar_afterCapState

kbd_waitForChar_capital_withCaps:
  mov bl, ds:[kbdAsciiCodes - 1 + di]

  cmp bl, 'a'
  jb kbd_waitForChar_capslock_capAscii

  cmp bl, 'z'
  ja kbd_waitForChar_capslock_capAscii

  mov al, ds:[kbdAsciiCodes - 1 + di]
  jmp kbd_waitForChar_afterCapState

kbd_waitForChar_capslock:
  GET_KEY_STATE KBD_KEY_LEFT_SHIFT
  jne kbd_waitForChar_capital_withCaps

  GET_KEY_STATE KBD_KEY_RIGHT_SHIFT
  jne kbd_waitForChar_capital_withCaps

  mov bl, ds:[kbdAsciiCodes - 1 + di]     ; Get the lower case version of the key, just to check if its between 'a' and 'z'
  
  cmp bl, 'a'                             ; Check if the key is below 'a'
  jb kbd_waitForChar_capslock_symbol      ; If below 'a' then its a symbol, so process capslock on a symbol

  cmp bl, 'z'                             ; Check if the key is above 'z'
  ja kbd_waitForChar_capslock_symbol      ; If above 'z' then its a symbol so process for a symbol

kbd_waitForChar_capslock_capAscii:
  ; Will get here if the key is between 'a' and 'z' (key >= 'a' && key <= 'z')
  mov al, ds:[kbdAsciiCapCodes - 1 + di]  ; If it is between 'a' and 'z' then get the capital ascii character of the key in AL
  jmp kbd_waitForChar_afterCapState       ; Delay and return

kbd_waitForChar_capslock_symbol:
  ; If the key is not between 'a' and 'z' then its a symbol, and capslock on a symbol (<CAPS_ON> + <1> = 1) just gives you the symbol
  mov al, ds:[kbdAsciiCodes - 1 + di]     ; Get the capital ascii code for the key, then delay and return

kbd_waitForChar_afterCapState:
  push ax                                 ; Save ascii code
  mov di, 0E000h                          ; Wait 0E000h microseconds, a delay for key presses
  mov si, 1                               ; 0E000h * 1 = 0E000h
  call sleep                              ; Sleep n time
  pop ax                                  ; Restore ascii code


kbd_waitForChar_end:
  pop ds                                  ; Restore old data segment
  ret