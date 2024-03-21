; %define ISR_KEYBOARD_GET_SCANCODES

; Handles keyboard events, (interrupts)
ISR_keyboard:
  pusha                                   ; Save all registersz
  push bp                                 ; Set up stack fram
  mov bp, sp                              ;

  push ds                                 ; Save old data segment
  mov bx, KERNEL_SEGMENT                  ; Make data segment the kernels data segment
  mov ds, bx                              ; so we can access the right memory

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

  in al, PS2_DATA_PORT                    ; Get scan code from keyboartd

  cmp al, KBD_SCANCODE_SPECIAL            ; Check if its an extended scan code
  je ISR_keyboard_special                 ; If special then handle special keys

  cmp al, KBD_SCANCODE_NORM_BREAK         ; Check if the key is released
  je ISR_keyboard_breakNorm               ; If the key is released then handle a key release

  cmp al, ds:[kbdSkipForScanExt]          ; Check if this scan code is a part of a previous extended scan code, which is marked for skip
  jne ISR_keyboard_special_notToSkip      ; If should skip this one then unmark it and return from this interrupt

  ; Should skip it
  mov byte ds:[kbdSkipForScanExt], 0      ; Unmark this scan code
  jmp ISR_keyboard_end                    ; Return from interrupt

ISR_keyboard_special_notToSkip:

  ; Get the scancodes keycode, from the keycode array
  xor ah, ah                              ; Pointers are 16 bits so zero out high part of AX
  mov di, ax                              ; Access memory on DI
  mov al, ds:[kbdKeycodes + di]           ; Get the key code in AL
  mov di, ax                              ; Set DI to the keycode to then set which keys are pressed

  cmp al, ds:[kbdSkipForKey]              ; Check if this key should be skipped, as the keyboard sends two interrupts
  jne ISR_keyboard_notToSkip              ; after a key is released. If it shouldnt be skiped then continue.

  mov byte ds:[kbdSkipForKey], 0          ; If it should be skipped, then unmark it from skip so next time we dont skip it
  jmp ISR_keyboard_end                    ; Return from interrupt

ISR_keyboard_notToSkip:
  ; If the key should not be skipped then its a normal key press, and we should set so no key should be skipped
  mov byte ds:[kbdSkipForKey], 0          ; No key should be skipped

  mov ds:[kbdCurrentKeycode], al          ; Set the current key being pressed to this key

  cmp al, KBD_KEY_CAPSLOCK                ; Check if the pressed key is cpaslock
  je ISR_keyboard_notToSkip_capsLock      ; If it is caps lock then process caps lock event

  ; Will be here if the key is not the caps lock key 
  mov byte ds:[kbdKeys - 1 + di], 1       ; Turn key on in the keys array
  jmp ISR_keyboard_end                    ; Return from interrupt

ISR_keyboard_notToSkip_capsLock:
  GET_KEY_STATE KBD_KEY_CAPSLOCK                    ; Check if caps lock was already toggled on
  jne ISR_keyboard_notToSkip_capsLockTurnOff        ; If it was then turn it of

  mov byte ds:[kbdKeys - 1 + KBD_KEY_CAPSLOCK], 1   ; If it wasnt toggled on, (meaning it was off) then turn it on
  jmp ISR_keyboard_end                              ; Return from interrupt

ISR_keyboard_notToSkip_capsLockTurnOff:
  mov byte ds:[kbdKeys - 1 + KBD_KEY_CAPSLOCK], 0   ; If it was toggled on, then turn it off
  jmp ISR_keyboard_end                              ; Return from interrupt


ISR_keyboard_special:
  in al, PS2_DATA_PORT                    ; We are here because of the E0 byte, so read input port again to get the scan code

  cmp al, KBD_SCANCODE_NORM_BREAK         ; Check if the key was released
  je ISR_keyboard_breakSpecial            ; If released then handle an extended scan code release event

  ; The keyboard will send this scan code again after this interrupt, without the E0 byte. So mark it for skip.
  mov ds:[kbdSkipForScanExt], al          ; Mark scan code for skip

  xor ah, ah                              ; Memory address is 16 bits so zero out high part
  mov di, ax                              ; Access memory with DI
  mov al, ds:[kbdExtendedKeycodes + di]   ; Get the scancodes corresponding key code in AL

  mov di, ax                              ; Access memory with DI (AH is already 0)
  mov byte ds:[kbdKeys + di - 1], 1       ; Mark this key as pressed in the keys array
  mov ds:[kbdCurrentKeycode], al          ; Set the current key that is being pressed to this key

  jmp ISR_keyboard_end                    ; Return from interrupt

ISR_keyboard_breakSpecial:
  in al, PS2_DATA_PORT                    ; Read input port again to get scancode

  ; The keyboard will send this scan code again after this interrupt, without the E0 byte. So mark it for skip.
  mov ds:[kbdSkipForScanExt], al          ; Mark scan code for skip

  xor ah, ah                              ; Memory address is 16 bits so zero out high part
  mov di, ax                              ; Access memory with DI
  mov al, ds:[kbdExtendedKeycodes + di]   ; Get this scancodes corresponding key code in AL 
  mov di, ax                              ; Access memory with DI (AH is already zero)
  
  mov byte ds:[kbdKeys + di - 1], 0       ; Mark this key as not pressed in the keyboard array
  mov byte ds:[kbdCurrentKeycode], 0      ; Set the current key that is being pressed to NULL

  jmp ISR_keyboard_end                    ; Return from interrupt

ISR_keyboard_breakNorm:
  in al, PS2_DATA_PORT                    ; The keyboard sent a break code (key released) then read again to get the scan code
  
  xor ah, ah                              ; Memory locations are 16 bits, so zero out high part
  mov di, ax                              ; Access memory with DI
  mov al, ds:[kbdKeycodes + di]           ; Get the keycode for this scan code
  mov di, ax                              ; We want to access the keys array with the keycode as the index, to set it to 0

  ; Because the keyboard will send another interrupt after this one, with the same scan code,
  ; we should set the key to be skipped to this key so we wont process a key that is not really being pressed
  mov ds:[kbdSkipForKey], al              ; Set the key to be skipped to this key

  mov byte ds:[kbdCurrentKeycode], 0      ; Because the key is released set the current keycode to 0

  GET_KEY_STATE KBD_KEY_CAPSLOCK          ; Check if the key released is caps lock
  jne ISR_keyboard_end                    ; If it is, then no need to unmark it from the keys array
  mov byte ds:[kbdKeys + di - 1], 0       ; Set this key in the keys array to 0 because it is no longer being pressed

ISR_keyboard_end: 
  PIC8259_SEND_EOI IRQ_KEYBOARD           ; Send an EOI to the PIC, so new interrupts can be called
  pop ds                                  ; Restore data segment
  mov sp, bp                              ; Restore stack frame
  pop bp                                  ;
  popa                                    ; Restore all registers
  iret                                    ; Return from interrupt