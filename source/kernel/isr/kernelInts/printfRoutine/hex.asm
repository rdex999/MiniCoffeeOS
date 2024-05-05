;
; --------- [ A PRINTF SUB-ROUTINE FOR PRINTING HEXADECIMAL NUMBERS ] ---------
;

.hexLow:
  mov bx, 57h                                   ; If its a lower case number, set the "convert to character" value to this thing
  jmp .hex_afterSetLetterVal                    ; Skip the other thing

.hexCapital:
  mov bx, 37h                                   ; If its a capital case number, set the "convert to character" value to this thing

.hex_afterSetLetterVal:
  mov si, [bp - 2]                              ; Get a pointer to the arguments array
  mov ax, ss:[si]                               ; Get the next argument (the number to print)
  add word [bp - 2], 2                          ; Add 2 to the argument pointer, so it points to the next argument

  lea si, [bp - (4 + 1)]                        ; Get a pointer to the buffer (for integers and stuff)

.hex_getDigits:
  mov cx, ax                                    ; Get the number in CX, so we can work on it
  and cx, 0Fh                                   ; Get the last digit/character
  cmp cx, 0Ah                                   ; Check if its a digit or a character
  jb .hex_isNum                                 ; If its a number, convert it to a character with 30h

  add cx, bx                                    ; If its a character, convert it to ascii with the "convert to character" value
  jmp .hex_storeVal                             ; Skip the next line

.hex_isNum:
  add cx, 30h                                   ; If its a digit, convert it into ascii

.hex_storeVal:
  mov ss:[si], cl                               ; Store the number in the buffer
  dec si                                        ; Decrement buffer pointer
  shr ax, 4                                     ; Shift number by 4 to get the next digit in the low 4 bits
  test ax, ax                                   ; Check if the result is 0
  jnz .hex_getDigits                            ; If its not, continue getting characters

  jmp .uint_printStr                            ; After were done with the digits, just print the buffer as usual