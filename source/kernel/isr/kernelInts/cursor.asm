;
; ---------- [ CURSOR RELATED INTERRUPTS ] ----------
;

%ifndef INT_CURSOR_ASM
%define INT_CURSOR_ASM


; Get the current cursor location
; Takes to parameters
; RETURNS
;   - 0) AH   => The row (Y)
;   - 1) AL   => The column (X)
ISR_getCursorLocation:
  call getCursorIndex               ; Get the cursors index in VGA

  ; Formula for converting VGA index into a row and a column
  ; row = index / 80;
  ; col = index % 80;
  mov bx, 80                        ; Amount of columns in a row
  xor dx, dx                        ; Zero out high 8 bits
  div bx                            ; Divide the index by the amount of columns in a row

  mov ah, al                        ; Get the row in AH
  mov al, dl                        ; Get column in AL
  jmp ISR_kernelInt_end             ; Return from the interrupt


; Set the cursors location
; PARAMS
;   - 0) DI   => The row (Y)
;   - 1) SI   => The column (X)
; Doesnt return anything
ISR_setCursorLocation:
  ; Formula for converting a row and col pair to a VGA index
  ; index = row * 80 + col;
  mov ax, di                        ; Get index in DI
  mov bx, 80                        ; Amount of columns in a row
  mul bx                            ; Multiply the row by the amount of columns in a row

  add ax, si                        ; Add the column to it
  mov di, ax                        ; Get index in DI
  call setCursorIndex               ; Set the cursor location to it
  xor ax, ax                        ; Zero out return value
  jmp ISR_kernelInt_end             ; Return from the interrupt

%endif