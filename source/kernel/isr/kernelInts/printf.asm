;
; ---------- [ A SIMPLE PRINTF FUNCTION ] ----------
;

%ifndef INT_PRINTF_ASM
%define INT_PRINTF_ASM


; A C-like printf implementation.
; Arguments are pushed to the stack, from right to left
; Pointers are segmented from the DS segment
; Clean the stack yourself!
; PARAMS
;   - 0) A null terminated string
;   - ...) Arguments
; Doesnt return anything
ISR_printf:
  push bp                                       ; Save stack frame
  mov bp, sp                                    ;
  sub sp, 4 + 6                                 ; Allocate space for local stuff, + a small buffer for printing integers and stuff

  ; Those might change, so i made them macros
  %define INT_PRINTF_FIRST_ARG (2 + KERNEL_INT_STACK + 8)

  ; *(bp - 2)   - Arguments array pointer offset (segment is SS)
  ; *(bp - 4)   - Old DS segment

  lea di, [bp + INT_PRINTF_FIRST_ARG + 2]       ; Get a pointer to the first formatting argument (after the string)
  mov [bp - 2], di                              ; Store it, as it will be used for accessing the arguments
  mov [bp - 4], ds                              ; Save old DS segment

  mov si, [bp + INT_PRINTF_FIRST_ARG]           ; Get a pointer to the string
  cld                                           ; Clear direction flag so LODSB will increment SI

.checkLetters:
  lodsb                                         ; Get the next character in the string, in AL

  test al, al                                   ; Check if its the end of the string
  jz .foundNull                                 ; If it is, print the rest of the string and return

  cmp al, '%'                                   ; Check if the character is a '%'
  jne .checkLetters                             ; If its not, just continue searching the string

  lodsb                                         ; If it is, then get the character after that, which is the formatting option (%u, %i, ...)

  ; Here we print the string until the '%'
  push ax                                       ; Save the character (formatting option)
  mov dx, si                                    ; Get the string pointer in DX
  mov si, [bp + INT_PRINTF_FIRST_ARG]           ; Set SI to the beginning of the current string part
  mov [bp + INT_PRINTF_FIRST_ARG], dx           ; Update the current string part to the character after the formatting option
  sub dx, si                                    ; Get the length of the string (the one thats going to be printed)
  sub dx, 2                                     ; Subtract 2, one for the '%' and one for the formatting option

  mov bx, KERNEL_SEGMENT                        ; Set DS to the kernels segment so we can access the terminals color
  mov ds, bx                                    ;
  mov di, ds:[trmColor]                         ; Get the current terminal color
  mov ds, [bp - 4]                              ; Get the original DS segment
  call printStrLen                              ; Print the string until the '%'
  pop ax                                        ; Restore formatting option

  cmp al, 'u'                                   ; Check if the formatting option is for an unsigned integer
  je .uint                                      ; If it is, handle it

  cmp al, 'd'                                   ; Check if the formatting option is for a signed integer
  je .int                                       ; If it is, handle it

  cmp al, 'x'                                   ; Check if the formatting option is for a lower-case hexadecimal number
  je .hexLow                                    ; If it is, handle it

  cmp al, 'X'                                   ; Check if the formatting option is for a capital hexadecimal number
  je .hexCapital                                ; If it is, handle it

  cmp al, 's'                                   ; Check if the formatting option is for a capital hexadecimal number
  je .string                                ; If it is, handle it

  ; If the formatting option is none of the above, print an error message and return
  mov bx, KERNEL_SEGMENT                        ; Set DS to the kernels segment, because the error message is there
  mov ds, bx                                    ;
  lea si, printf_errorFormat                    ; Get a pointer to the error message
  mov di, COLOR(VGA_TXT_RED, VGA_TXT_DARK_GRAY) ; Set the color
  call printStr                                 ; Print the error message
  jmp .end                                      ; Return

.foundNull:
  mov si, [bp + INT_PRINTF_FIRST_ARG]           ; Get the beginning of the current string part

  mov bx, KERNEL_SEGMENT                        ; Set DS to the kernels segment so we can access the terminals color
  mov ds, bx                                    ; 
  mov di, ds:[trmColor]                         ; Get the current terminal color
  
  mov ds, [bp - 4]                              ; Get the original DS segment
  call printStr                                 ; Print the string

.end:
  mov ds, [bp - 4]                              ; Get the original DS segment
  mov sp, bp                                    ; Restore stack frame
  pop bp                                        ;
  jmp ISR_kernelInt_end                         ; Return from the interrupt

%include "kernel/isr/kernelInts/printfRoutine/uint.asm"
%include "kernel/isr/kernelInts/printfRoutine/int.asm"
%include "kernel/isr/kernelInts/printfRoutine/hex.asm"
%include "kernel/isr/kernelInts/printfRoutine/string.asm"

%endif