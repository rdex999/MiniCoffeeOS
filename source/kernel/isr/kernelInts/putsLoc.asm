;
; ---------- [ PRINT A STRING STARTING FROM A SPECIFIC LOCATION ] ---------
;

%ifndef PUTS_LOC_ASM
%define PUTS_LOC_ASM

; Print a string starting from a specific location
; PARAMS
;   - 0) DI     => The color, set bit 8 (value: 1_0000_0000b) for the current terminal color
;   - 1) DS:SI  => The string to print, null terminated
;   - 2) DL     => The column (0 - 79)
;   - 3) DH     => The row (0 - 24)
; Doesnt return anything
ISR_putsLoc:
  push bp                           ; Save stack frame
  mov bp, sp                        ;
  sub sp, 4                         ; Allocate space for local stuff

  test di, 1_0000_0000b             ; Check if the user has requested the current terminal color
  jz .afterSetColor                 ; If not then the color is in DI, just print the string

  push gs                           ; Save GS because modifying it
  mov bx,KERNEL_SEGMENT             ; Set GS to the kernels segment so we can access trmColor
  mov gs, bx                        ; 
  mov di, gs:[trmColor]             ; Get the current terminal color
  pop gs                            ; Restore GS

.afterSetColor:
  mov [bp - 2], di                  ; Store the color

  mov cl, dl                        ; Get the column in CL, because DX changes after the MUL instruction

  mov al, dh                        ; Get row in AL
  xor ah, ah                        ; Zero out high 8 bits
  mov bx, 80                        ; Get the amount of columns in a row
  mul bx                            ; Multiply the row by the amount of columns in a row

  xor ch, ch                        ; Zero high 8 bits
  add ax, cx                        ; Add the column to the result
  push si                           ; Save string pointer
  push ax                           ; Save VGA index

  call getCursorIndex               ; Get the current cursors location so we can switch back to it later
  mov [bp - 4], ax                  ; Store it

  pop di                            ; Restore the VGA index, and set it to the current cursor location
  call setCursorIndex               ; Set current cursor location

  pop si                            ; Restore string pointer
  mov di, [bp - 2]                  ; Get the color to print with
  call printStr                     ; Print the string on the requested location

  mov di, [bp - 4]                  ; Get the original cursor location
  call setCursorIndex               ; Set it to the current location

  mov sp, bp                        ; Restore stack frame
  pop bp                            ;
  jmp ISR_kernelInt_end             ; Return from the interrupt

%endif