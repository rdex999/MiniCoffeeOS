;
; --------- [ A PRINTF SUB-ROUTINE FOR PRINTING UNSIGNED INTEGERS ] ---------
;

.int:
  mov si, [bp - 2]                              ; Get a pointer to the arguments array
  mov ax, ss:[si]                               ; Get the next argument (the number to print)
  add word [bp - 2], 2                          ; Add 2 to the argument pointer, so it points to the next argument

  lea si, [bp - (4 + 1)]                        ; Get a pointer to the buffer (for integers and stuff)

  test ax, 1 << 15                              ; Check sign bit
  jz .uint_getDigits                            ; If the sign bit is clear (0) just print the number as a normal unsigned int

  neg ax                                        ; If the sign bit is set, then negate the number (to get its positive version)
  push ax                                       ; Save the result
  push si                                       ; Save buffer pointer

  mov bx, KERNEL_SEGMENT                        ; Set DS to the kernels segment so we can access the terminals color
  mov ds, bx                                    ;
  mov di, ds:[trmColor]                         ; Get the current terminal color
  mov ds, [bp - 4]                              ; Reset DS to its original value

  shl di, 8                                     ; Get the color in the high 8 bits of DI
  or di, '-'                                    ; Set the low 8 bits of DI to the character
  call printChar                                ; Print it

  pop si                                        ; Restore the buffer pointer
  pop ax                                        ; Restore positive version of the number
  jmp .uint_getDigits                           ; Print the number as a unsigned integer
