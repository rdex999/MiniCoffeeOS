;
; --------- [ A PRINTF SUB-ROUTINE FOR PRINTING UNSIGNED INTEGERS ] ---------
;

.uint:
  mov si, [bp - 2]                              ; Get a pointer to the arguments array
  mov ax, ss:[si]                               ; Get the next argument (the number to print)
  add word [bp - 2], 2                          ; Add 2 to the argument pointer, so it points to the next argument

  lea si, [bp - (4 + 1)]                        ; Get a pointer to the buffer (for integers and stuff)
.uint_getDigits:
  mov bx, 10                                    ; We want to divide by 10 to get the last digit
  xor dx, dx                                    ; Zero out remainder
  div bx                                        ; Divide the number by 10

  add dl, 30h                                   ; Convert the last digit to a character
  mov ss:[si], dl                               ; Store it
  dec si                                        ; Decrement buffer pointer
  
  test al, al                                   ; Check if the division result is 0 (in which case we need to stop dividing)
  jnz .uint_getDigits                           ; If its not zero, continue getting digits

.uint_printStr:
  lea dx, [bp - (4 + 1)]                        ; Get a pointer to the end of the buffer
  sub dx, si                                    ; Subtract from it the current location in the buffer, to get the strings length

  inc si                                        ; Increment buffer pointer (off by 1)

  mov bx, KERNEL_SEGMENT                        ; Set DS to the kernels segment so we can access the terminals color
  mov ds, bx                                    ;
  mov di, ds:[trmColor]                         ; Get the current terminal color

  mov bx, ss                                    ; Set DS to the stack segment, because the number string is stored on the stack
  mov ds, bx

  call printStrLen                              ; Print the number

  mov ds, [bp - 4]                              ; Reset DS to its original value
  mov si, [bp + INT_PRINTF_FIRST_ARG]           ; Get the string pointer
  jmp .checkLetters                             ; Continue checking characters
