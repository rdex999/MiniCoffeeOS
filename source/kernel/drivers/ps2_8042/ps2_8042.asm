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
  push ds                                   ; Save old data segment
  mov bx, KERNEL_SEGMENT                    ; Set data segment to kernel data segment
  mov ds, bx                                ;
  sti                                       ; Enable interrupt so we wont get in an infinite loop while waiting for the keycode

  cmp byte ds:[kbdCurrentKeycode], 0        ; Check if there is a key thats currently pressed
  je .waitLoop            ; If not then wait for one the mark it as the first in a row

  ; Will be here if there is a key currently being pressed
  cmp byte ds:[kbdIsFirst], 0               ; Check if the key pressed is the first in a row, so we know if should delay or not
  je .delayAndRet         ; If not then give a small delay and return

  ; Will get here if the key is the first in the row
  ; Prepare for delay of about 0.6 seconds
  push word ds:[kbdCurrentKeycode]

  mov di, KBD_HIGH_DELAY                    ; Get the time of the high delay
  call kbdDelayKey                          ; Delay, as long as the key is the same
  pop dx
  cmp al, dl
  je .afterSetFirst                         ; If it is, set kbdIsFirst to false

  mov byte ds:[kbdIsFirst], 1               ; If not the same, mark this key as first in the row
  jmp .delayAndRet                          ; Make a short delay, and return

.afterSetFirst:
  mov byte ds:[kbdIsFirst], 0               ; If it is the same, mark this key as not first in row
  jmp .delayAndRet                          ; Make a short delay and return

.waitLoop:
  ; Will get here if there is no key currently being pressed
  hlt                                       ; Stop the CPU until there is an interrupt, so we wont burn the cpu while waiting
  cmp byte ds:[kbdCurrentKeycode], 0        ; If the interrupt was a keyboard one, then the current key should be set.
  je .waitLoop            ; If the current key is set then stop waiting for a key

  mov byte ds:[kbdIsFirst], 1               ; Mark this key as the first in row

.delayAndRet:
  push word ds:[kbdCurrentKeycode]          ; Save the current key so we know if it changed while delaying
  mov di, KBD_LOW_DELAY                     ; Get the time of the low delay
  call kbdDelayKey                          ; Make a short delay as long as the keyt remains the same
  pop dx                                    ; Restore key
  test al, al                               ; Check if the current key is null
  jz .waitLoop                              ; If it is, wait for a key press

  cmp al, dl                                ; Check if the kay had changed
  je .end                                   ; If it didnt then return

  mov byte ds:[kbdIsFirst], 1               ; If it did change mark it as first is row

.end:
  pop ds                                    ; Restore old data segment
  ret                                       ; Return


; A sub-function of kbd_waitForKeycode
; Will wait a given time, but if a key is pressed it will return before the given time
; PARAMS
;   - 0) DI   => The maximum time to wait (in milliseconds)
; RETURNS
;   - 0) In AL, the current keycode after returning
kbdDelayKey:
  push ds                               ; Save the current DS segment
  mov bx, KERNEL_SEGMENT                ; Set it to the kernels segment so we can access sysClock
  mov ds, bx                            ;

  call getLowTime                       ; Get the current time in milliseconds (the start time)
  mov si, ax                            ; Store it in SI 

  mov dl, ds:[kbdCurrentKeycode]        ; Get the current keycode
  sti                                   ; Enable interrupts so the keyboard works (and the time)

.waitLoop:
  hlt                                   ; Halt until there is an interrupts
  
  cmp ds:[kbdCurrentKeycode], dl        ; Check if the current keycode is the same as the one we started with
  jne .retKey                           ; If its not the same, return

  push si                               ; Save counters and stuff before function call
  push di                               ;
  push dx                               ;
  call getLowTime                       ; Get the current time in milliseconds
  pop dx                                ; Restore stuff after the function call
  pop di                                ;
  pop si                                ;

  sub ax, si                            ; Subtract the start time from the current time, to get the time that has passed
  cmp ax, di                            ; Check if the time passed is less then the requested amount
  jb .waitLoop                          ; If not, continue waiting

.retKey:
  mov al, ds:[kbdCurrentKeycode]        ; Get the current keycode

.end:
  pop ds                                ; Restore old DS segment
  ret

; Waits for a printable key to be pressed, or multiple keys which correspond to one character
; For example <SHIFT> + <A> => 'A'
; Takes to parameters
; RETURNS
;   - AL      => The ascii code for the character. (The character)
;   - BL      => The keycode for the character
kbd_waitForChar:
  push ds                                 ; Save old data segment
  mov bx, KERNEL_SEGMENT                  ; Set data segment to kernel segment so we can access keyboard variables
  mov ds, bx                              ; 
  
.waitValid:
  call kbd_waitForKeycode                 ; Wait for a key code, which will be in AL
  and ax, 0FFh
  mov si, ax

  test al, al                             ; Check if the keycode is valid. (Zero is an invalid keycode)
  jz .end                  ; If its zero then just return zero

  cmp al, KBD_KEY_LEFT_SHIFT              ; Check if it was the shift key
  je .waitValid            ; If the shift key was pressed, skip it, and continue waiting for another key

  cmp al, KBD_KEY_RIGHT_SHIFT             ; Check if it was the right shift key
  je .waitValid            ; If the shift key was pressed, skip it, and continue waiting for another key

  cmp al, KBD_KEY_CAPSLOCK                ; Check if it was the caps lock
  je .waitValid            ; Again, caps lock doesnt matter, just continue waiting for a key

  ; Will get here once we got a real key (not shift or caps lock)
  xor ah, ah                              ; We want to use the key code as an index
  mov di, ax                              ; Access memory with Di

  GET_KEY_STATE KBD_KEY_LEFT_SHIFT        ; Check if the left shift key is currently being pressed
  jne .capital             ; If it is, then process for a capital letter
  
  GET_KEY_STATE KBD_KEY_RIGHT_SHIFT       ; Check if the right shift key is currently being pressed
  jne .capital
  
  GET_KEY_STATE KBD_KEY_CAPSLOCK          ; Check if caps lock is on
  jne .capslock            ; If caps lock is one then process for caps lock

  ; Will get here if no shift key is pressed or caps lock, processing for a lower case letter
  mov al, ds:[kbdAsciiCodes - 1 + di]     ; Get lower case letter ascii for keycode
  jmp .end                 ; Delay and return

.capital:
  ; Check if shift is on along with caps lock
  GET_KEY_STATE KBD_KEY_CAPSLOCK          ; Check caps lock state
  jne .capital_withCaps    ; If caps lock is on then react accordingly

  ; Will be here if caps lock is off
  mov al, ds:[kbdAsciiCapCodes - 1 + di]  ; If shift was pressed, then get the capital ascii character for the keycode
  jmp .end                 ; Delay and return

.capital_withCaps:
  ; Will get here if shift is pressed when caps lock is on
  ; If <caps> + <shift> and the key pressed was an alphabetic one, then give its lower case version
  ; If <caps> + <shift> and the key pressed was a number/symbol, then give its capital version
  mov bl, ds:[kbdAsciiCodes - 1 + di]     ; Get the lower case ascii for the key, just to perform checks

  cmp bl, 'a'                             ; Check for alphabetic characters
  jb .capslock_capAscii    ; If not alphabetic then give capital symbol

  cmp bl, 'z'                             ; Check for alphabetic characters
  ja .capslock_capAscii    ; If not alphabetic then give capital symbol

  ; Will get here if the key is an alphabetic character
  mov al, bl                              ; Get lower ascii character
  jmp .end                 ; Delay and return

.capslock:
  ; Will be here if caps lock is on
  GET_KEY_STATE KBD_KEY_LEFT_SHIFT        ; Check if left shift is on
  jne .capital_withCaps    ; If on then handle typing with caps lock and shift

  GET_KEY_STATE KBD_KEY_RIGHT_SHIFT       ; Check if left shift is on
  jne .capital_withCaps    ; If on then handle typing with caps lock and shift 

  mov bl, ds:[kbdAsciiCodes - 1 + di]     ; Get the lower case version of the key, just to check if its between 'a' and 'z'
  
  cmp bl, 'a'                             ; Check if the key is below 'a'
  jb .capslock_symbol      ; If below 'a' then its a symbol, so process capslock on a symbol

  cmp bl, 'z'                             ; Check if the key is above 'z'
  ja .capslock_symbol      ; If above 'z' then its a symbol so process for a symbol

.capslock_capAscii:
  ; Will get here if the key is between 'a' and 'z' (key >= 'a' && key <= 'z')
  mov al, ds:[kbdAsciiCapCodes - 1 + di]  ; If it is between 'a' and 'z' then get the capital ascii character of the key in AL
  jmp .end                 ; Delay and return

.capslock_symbol:
  ; If the key is not between 'a' and 'z' then its a symbol, and capslock on a symbol (<CAPS_ON> + <1> = 1) just gives you the symbol
  mov al, ds:[kbdAsciiCodes - 1 + di]     ; Get the capital ascii code for the key, then delay and return

.end:
  mov bx, si
  pop ds 
  ret