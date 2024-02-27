; %define ISR_KEYBOARD_GET_SCANCODES

; Sets DI to the keycode, and executes ISR_keyboard_setKeycode
; PARAMS
;   - 0) int16    => The keycode, (not the index in keyboardKeycodes, the index is keycode-1)
%macro ISR_KEYBOARD_NORM_KEY_EVENT 1

  mov di, %1                          ; Set argument for ISR_keyboard_setKeycode
  jmp ISR_keyboard_setKeycode         ; Execute ISR_keyboard_setKeycode

%endmacro

; Jumps if AL == scancode
; PARANS
;   - 0) The scancode to compare AL to
;   - 1) the lable to jump to if equal
%macro ISR_KEYBOARD_SCANCODE_JUMP 2

  cmp al, %1                              ; Comapre AL to the scancode
  je %2                                   ; If equal then jump to the given lable

%endmacro

; Sets flags in keyboardKeycodes, and keyboardCurrentKeycode
; **THIS IS NOT A FUNCTION, JUMP TO IT TO EXECUTE
; PARAMS
;   - 0) DI   => The keycode, (not the index in keyboardKeycodes, the index is keycode-1)
ISR_keyboard_setKeycode:
  cmp byte [bp - 1], 0                        ; Check if the key is being pressed or released
  je ISR_keyboard_setKeycode_pressed          ; If pressed then setup stuff for key press

  ; If released then set the current keycode to 0
  ; And the keycode in the keycodes array to 0
  mov byte ds:[keyboardCurrentKeycode], 0     ; Set current keycode to 0 as its released
  mov byte ds:[keyboardKeycodes - 1 + di], 0  ; Set the keycode in the keycode array to 0
  jmp ISR_keyboard_end                        ; Return from iterrupt

ISR_keyboard_setKeycode_pressed:
  mov ax, di                                  ; Because the keycode is 8 bits (1 byte)
  mov byte ds:[keyboardCurrentKeycode], al    ; Set the current keycode to the new keycode
  mov byte ds:[keyboardKeycodes - 1 + di], 1  ; Set the keycode in the keycode array to the new keycode
  jmp ISR_keyboard_end                        ; Return from the interrupt

; Handles keyboard events, (interrupts)
ISR_keyboard:
  pusha                                       ; Save all registersz
  push bp                                     ; Set up stack fram
  mov bp, sp                                  ;

  ; sub sp, <size>
  dec sp                                      ; Allocate 1 byte

  mov byte [bp - 1], 0        ; Flag for if the key in released (0 for pressed, 1 for released)

  cli                                         ; Disable interrupts while processing this interrupt

  push ds                                     ; Save data segment as were modifying it

  ; Set the data segment to the kernel data segment, as we dont know what it was when the interrupt happened
  mov bx, KERNEL_SEGMENT                      ; Cant modify segment directly
  mov ds, bx                                  ; Set data segment to kernel data segment

  ; Equivalent C code:
; if(bKbdSkipNextInt){
;   bKbdSkipNextInt = false;
;   return;
; }
  cmp byte ds:[kbdSkipNextInt], 0             ; Check if should skip this interrupt
  je ISR_keyboard_dontSkipInt                 ; If not, then execute this interrupt

  ; If should not execute this interrupt, set flag off (so next interrupt WILL execute) and return.
  mov byte ds:[kbdSkipNextInt], 0             ; Set flag off
  jmp ISR_keyboard_end                        ; Return

ISR_keyboard_dontSkipInt:

  ; This #define is commented out on the top of this file, uncomment to get keyboard scan codes
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

  in al, PS2_DATA_PORT                        ; Get the keyboard scan code in AL

  ; Check for special keys
  cmp al, KBD_SCANCODE_SPECIAL
  je ISR_keyboard_special_E0

  cmp al, KBD_SCANCODE_SPECIAL+1
  je ISR_keyboard_special_E1

  ; Check for a break code
  cmp al, KBD_SCANCODE_NORM_BREAK             ; Check for break code
  je ISR_keyboard_normBreak                   ; IF break then jump to its handler code

ISR_keyboard_normChecks:
  ; Perform a switch-case on the scan code (there should be around a 104 of these)
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


  mov byte ds:[keyboardCurrentKeycode], 0           ; (default) If none of the above, then just set the current key to NULL

ISR_keyboard_end: 
  PIC8259_SEND_EOI IRQ_KEYBOARD                     ; Send an EOI to the PIC, so new interrupts can be called
  pop ds                                            ; Restore data segment
  mov sp, bp                                        ; Restore stack fram
  pop bp                                            ;
  popa                                              ; Restore all registers
  iret                                              ; Return from interrupt

ISR_keyboard_special_E0:
  jmp ISR_keyboard_end

ISR_keyboard_special_E1:
  jmp ISR_keyboard_end

ISR_keyboard_normBreak:
  ; If the key is released, then skip the next interrupt as the keyboard will send a new one next to this one
  mov byte ds:[kbdSkipNextInt], 1                   ; Set flag to skip next interrupt
  mov byte [bp - 1], 1                              ; Set flag to indicate key release
  call ps2_8042_waitOutput                          ; Wait for data from PIC
  in al, PS2_DATA_PORT                              ; Get the real scan code in AL
  jmp ISR_keyboard_normChecks                       ; Go to the scan code switch case with the new scan code

  ; Handlers for scan codes
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