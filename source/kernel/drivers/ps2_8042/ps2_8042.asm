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
  call kbd_waitForKeycode         ; Wait for a key code, which will be in AL
  
  push ds                         ; Save old data segment
  mov bx, KERNEL_SEGMENT          ; Set data segment to kernel segment so we can access keyboard variables
  mov ds, bx                      ; 

  test al, al                     ; Check if the keycode is valid. (Zero is an invalid keycode)
  jz kbd_waitForChar_end          ; If its zero then just return zero

  dec al                          ; Decrement the keycode, becuase it starts from 1
  xor ah, ah                      ; Zero out high part because we want to access memory with it, and memory is 16bits
  mov di, ax                      ; Access memory with DI
  mov al, [kbdAsciiCodes + di]    ; Get the ascii code for this keycode

  push ax                         ; Save ascii code
  mov di, 0E000h                  ; Wait 0E000h microseconds, a delay for key presses
  mov si, 1                       ; 0E000h * 1 = 0E000h
  call sleep                      ; Sleep n time
  pop ax                          ; Restore ascii code


kbd_waitForChar_end:
  pop ds                          ; Restore old data segment
  ret