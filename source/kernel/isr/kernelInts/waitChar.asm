;
; ---------- [ WAIT FOR A CHARACTER FROM THE KEYBOARD ] ---------
;

%ifndef WAIT_CHAR_ASM
%define WAIT_CHAR_ASM

; Wait for a character from the keyboard
; PARAMS
;   - 0) DI   => The color to echo the character with set bit 8 (value: 1_0000_0000b) for the current terminal color
; RETURNS
;   - 0) AX   => The character, in ascii (lower 8 bits - AL)
ISR_waitChar:
  push di                     ; Save the color

  call kbd_waitForChar        ; Wait for a character from the keyboard

  pop di                      ; Restore color
  test di, 1_0000_0000b       ; Check if the user has requested the terminals color
  jz .afterSetColor           ; If not, then DI is already the color, just print the character and return it

  push ds                     ; If he did request the terminals color, Set it.  // Save DS because changing it for a sec
  mov bx, KERNEL_SEGMENT      ; Set DS to the kernels segment, so we can access the terminals color
  mov ds, bx                  ;
  mov di, ds:[trmColor]       ; Get the current terminal color
  pop ds                      ; Restore DS

.afterSetColor:
  shl di, 8                   ; Get the color in the high 8 bits of DI
  xor ah, ah                  ; Zero out high 8 bits of the character (they should be 0 but still)
  or di, ax                   ; Get the character in the lower 8 bits of DI
  push ax                     ; Save the character
  call printChar              ; Print it
  pop ax                      ; Restore the character so we return it

  jmp ISR_kernelInt_end       ; Return from the interrupt, while the character is in AL


; Wait for a character from the keyboard, but dont echo it back
; Takes no parameters
; RETURNS
;   - 0) AX   => The character in ascii (low 8 bits - AL)
ISR_waitCharNoEcho:
  call kbd_waitForChar        ; Wait for a character from the keyboard
  xor ah, ah                  ; Zero out high 8 bits (should be 0 but still)
  jmp ISR_kernelInt_end       ; Return from the interrupt

%endif