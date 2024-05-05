;
; ---------- [ PRINT A CHARACTER ON A SPECIFIC LOCATION ] ----------
;

%ifndef PUTCHAR_LOC_ASM
%define PUTCHAR_LOC_ASM

; Print a single character at a specific location
; PARAMS
;   - 0) DI   => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) SI   => The character, lower 8 bits only
;   - 2) DL   => The column (0 - 79)
;   - 3) DH   => The row (0 - 24)
; Doesnt return anything
ISR_putcharLoc:
  push bp                             ; Save stack frame
  mov bp, sp                          ;
  sub sp, 6                           ; Allocate space for local stuff

  mov cx, dx                          ; Get the column and the row in CL and CH respectivly (because DX changes after the MUL instruction)

  ; Formula to get the VGA index for a row and a col:
  ; index = row * 80 + col;
  xor ah, ah                          ; Zero out high 8 bits of the VGA index

  mov al, dh                          ; Get the row in AL
  mov bx, 80                          ; Get the number for columns in a row
  mul bx                              ; Multiply them

  xor ch, ch                          ; Zero out row, to get only the column
  add ax, cx                          ; Add the column to the result

  mov [bp - 2], ax                    ; Save the index

  test di, 1_0000_0000b               ; Check if the color is the current terminal color
  jz .afterSetColor                   ; If the color is not the terminal color, then DI is set to the color. Continue and print the character
  
  push gs                             ; Save GS, because modifying it for a sec
  mov bx, KERNEL_SEGMENT              ; Set GS to the kernels segment, so we can access trmColor
  mov gs, bx                          ;

  mov di, gs:[trmColor]               ; Get the current terminal color
  pop gs                              ; Restore GS

.afterSetColor:
  ; When getting here, the color should be in the low 8 bits of DI
  shl di, 8
  or di, si                           ; Get the color at the high 8 bits of DI and the character in the low 8 bits
  mov [bp - 4], di                    ; Save the character and the color
  
  call getCursorIndex                 ; Get the current cursor location
  mov [bp - 6], ax                    ; Save the result

  mov di, [bp - 2]                    ; Get the requested location to print the character on
  call setCursorIndex                 ; Set it to the current cursor location

  mov di, [bp - 4]                    ; Get the requested character
  call printChar                      ; Print it

  mov di, [bp - 6]                    ; Get the original cursor location
  call setCursorIndex                 ; Switch back to it

  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  xor ax, ax
  jmp ISR_kernelInt_end               ; Return from the interrupt

%endif