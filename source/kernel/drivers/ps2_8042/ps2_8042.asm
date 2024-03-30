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
  push bp                                   ; Store stack frame
  mov bp, sp                                ;
  sub sp, 3                                 ; Allocate 3 bytes, *(bp - 1) is used for the keycode and *(bp - 3) in for the time

  push ds                                   ; Save old data segment
  mov bx, KERNEL_SEGMENT                    ; Set data segment to kernel data segment
  mov ds, bx                                ;
  sti                                       ; Enable interrupt so we wont get in an infinite loop while waiting for the keycode

  cmp byte ds:[kbdCurrentKeycode], 0        ; Check if there is a key thats currently pressed
  je kbd_waitForKeycode_waitLoop            ; If not then wait for one the mark it as the first in a row

  ; Will be here if there is a key currently being pressed
  cmp byte ds:[kbdIsFirst], 0               ; Check if the key pressed is the first in a row, so we know if should delay or not
  je kbd_waitForKeycode_delayAndRet         ; If not then give a small delay and return

  ; Will get here if the key is the first in the row
  ; Prepare for delay of about 0.6 seconds
  mov al, ds:[kbdCurrentKeycode]            ; Save the current key code  
  mov [bp - 1], al                          ; as we will be checking if it remains pressed while delaying

  GET_SYS_TIME                              ; Get the system time before starting the delay, so we know how much time passes
  mov [bp - 3], dx                          ; Store the current system time

  ; The main delay loop
kbd_waitForKeycode_firstDelay:
  mov al, [bp - 1]                          ; Get the key that we started with
  cmp al, ds:[kbdCurrentKeycode]            ; Check if the key being pressed is the same
  je kbd_waitForKeycode_afterSetFirst       ; If its the same then dont return

  ; Will get here if the key pressed is not the same
  mov byte ds:[kbdIsFirst], 1               ; If its not the same then mark it as the first in a row, do a small delay and return
  jmp kbd_waitForKeycode_delayAndRet        ; Short delay and return
   
kbd_waitForKeycode_afterSetFirst:
  GET_SYS_TIME                              ; Get the current system time
  sub dx, [bp - 3]                          ; currentSysTime - prevSysTime = time in the loop

  cmp dx, KBD_HIGH_DELAY                                ; Check if the delayed time is above 0.6 seconds
  jb kbd_waitForKeycode_firstDelay          ; If its not, then continue delaying

  ; Will get here when the delay is finished
  mov byte ds:[kbdIsFirst], 0               ; As this key was marked as first, unmark it so the next key wont have a big delay
  jmp kbd_waitForKeycode_delayAndRet        ; Short delay and return

kbd_waitForKeycode_waitLoop:
  ; Will get here if there is no key currently being pressed
  hlt                                       ; Stop the CPU until there is an interrupt, so we wont burn the cpu while waiting
  cmp byte ds:[kbdCurrentKeycode], 0        ; If the interrupt was a keyboard one, then the current key should be set.
  je kbd_waitForKeycode_waitLoop            ; If the current key is set then stop waiting for a key

  mov byte ds:[kbdIsFirst], 1               ; Mark this key as the first in row

kbd_waitForKeycode_delayAndRet:
  mov al, ds:[kbdCurrentKeycode]            ; Get the current key code in AL
  test al, al                               ; Check if its valid
  jz kbd_waitForKeycode_waitLoop            ; If not then wait for a key

  ; If it is valid then make a short delay and return
  mov [bp - 1], al

  ; Delay of 0.03 seconds
  mov word [bp - 3], KBD_LOW_DELAY_COUNT                  ; Set the amount of times to make a super small delay
kbd_waitForKeycode_delayAndRet_loop:
  mov si, 0FFh                                            ; A very small delay
  mov di, 4                                               ; so each time we can check if the same key is still being pressed
  call sleep                                              ; Perform the delay

  mov al, [bp - 1]                                        ; Get che keycode in AL
  cmp al, ds:[kbdCurrentKeycode]                          ; Check if its still the same key
  je kbd_waitForKeycode_delayAndRet_loopAfterCurrentCheck ; If its still the same then dont mark it as first

  ; If its not the same then mark it as first and return
  mov byte ds:[kbdIsFirst], 1                             ; Mark as first
  jmp kbd_waitForKeycode_delayAndRet                      ; Delay again and return

kbd_waitForKeycode_delayAndRet_loopAfterCurrentCheck:
  dec word [bp - 3]                                       ; Decrement delay counter
  jnz kbd_waitForKeycode_delayAndRet_loop                 ; If its not zero then continue delaying
  

  mov al, [bp - 1]                                        ; If zero then get the keycode in AL and return

kbd_waitForKeycode_end:
  pop ds                                                  ; Restore old data segment
  mov sp, bp                                              ;
  pop bp                                                  ; Restore stack frame
  ret                                                     ; Return


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
  
  GET_KEY_STATE KBD_KEY_RIGHT_SHIFT       ; Check if the right shift key is currently being pressed
  jne kbd_waitForChar_capital
  
  GET_KEY_STATE KBD_KEY_CAPSLOCK          ; Check if caps lock is on
  jne kbd_waitForChar_capslock            ; If caps lock is one then process for caps lock

  ; Will get here if no shift key is pressed or caps lock, processing for a lower case letter
  mov al, ds:[kbdAsciiCodes - 1 + di]     ; Get lower case letter ascii for keycode
  jmp kbd_waitForChar_end                 ; Delay and return

kbd_waitForChar_capital:
  ; Check if shift is on along with caps lock
  GET_KEY_STATE KBD_KEY_CAPSLOCK          ; Check caps lock state
  jne kbd_waitForChar_capital_withCaps    ; If caps lock is on then react accordingly

  ; Will be here if caps lock is off
  mov al, ds:[kbdAsciiCapCodes - 1 + di]  ; If shift was pressed, then get the capital ascii character for the keycode
  jmp kbd_waitForChar_end                 ; Delay and return

kbd_waitForChar_capital_withCaps:
  ; Will get here if shift is pressed when caps lock is on
  ; If <caps> + <shift> and the key pressed was an alphabetic one, then give its lower case version
  ; If <caps> + <shift> and the key pressed was a number/symbol, then give its capital version
  mov bl, ds:[kbdAsciiCodes - 1 + di]     ; Get the lower case ascii for the key, just to perform checks

  cmp bl, 'a'                             ; Check for alphabetic characters
  jb kbd_waitForChar_capslock_capAscii    ; If not alphabetic then give capital symbol

  cmp bl, 'z'                             ; Check for alphabetic characters
  ja kbd_waitForChar_capslock_capAscii    ; If not alphabetic then give capital symbol

  ; Will get here if the key is an alphabetic character
  mov al, bl                              ; Get lower ascii character
  jmp kbd_waitForChar_end                 ; Delay and return

kbd_waitForChar_capslock:
  ; Will be here if caps lock is on
  GET_KEY_STATE KBD_KEY_LEFT_SHIFT        ; Check if left shift is on
  jne kbd_waitForChar_capital_withCaps    ; If on then handle typing with caps lock and shift

  GET_KEY_STATE KBD_KEY_RIGHT_SHIFT       ; Check if left shift is on
  jne kbd_waitForChar_capital_withCaps    ; If on then handle typing with caps lock and shift 

  mov bl, ds:[kbdAsciiCodes - 1 + di]     ; Get the lower case version of the key, just to check if its between 'a' and 'z'
  
  cmp bl, 'a'                             ; Check if the key is below 'a'
  jb kbd_waitForChar_capslock_symbol      ; If below 'a' then its a symbol, so process capslock on a symbol

  cmp bl, 'z'                             ; Check if the key is above 'z'
  ja kbd_waitForChar_capslock_symbol      ; If above 'z' then its a symbol so process for a symbol

kbd_waitForChar_capslock_capAscii:
  ; Will get here if the key is between 'a' and 'z' (key >= 'a' && key <= 'z')
  mov al, ds:[kbdAsciiCapCodes - 1 + di]  ; If it is between 'a' and 'z' then get the capital ascii character of the key in AL
  jmp kbd_waitForChar_end                 ; Delay and return

kbd_waitForChar_capslock_symbol:
  ; If the key is not between 'a' and 'z' then its a symbol, and capslock on a symbol (<CAPS_ON> + <1> = 1) just gives you the symbol
  mov al, ds:[kbdAsciiCodes - 1 + di]     ; Get the capital ascii code for the key, then delay and return

kbd_waitForChar_end:
  pop ds                                  ; Restore old data segment
  ret