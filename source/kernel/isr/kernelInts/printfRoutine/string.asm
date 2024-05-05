;
; --------- [ A PRINTF SUB-ROUTINE FOR PRINTING STRINGS ] ---------
;

.string:
  mov si, [bp - 2]                              ; Get a pointer to the arguments array
  mov si, ss:[si]                               ; Get the next argument (the number to print)
  add word [bp - 2], 2                          ; Add 2 to the argument pointer, so it points to the next argument

  mov bx, KERNEL_SEGMENT                        ; Set DS to the kernels segment so we can access the terminals color
  mov ds, bx                                    ;
  mov di, ds:[trmColor]                         ; Get the current terminal color
  
  mov ds, [bp - 4]                              ; Set DS to its original value
  call printStr                                 ; Print the string

  mov si, [bp + INT_PRINTF_FIRST_ARG]           ; Get the string pointer
  jmp .checkLetters                             ; Continue checking letters and printing stuff
