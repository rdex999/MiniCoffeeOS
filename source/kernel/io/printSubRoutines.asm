;
; ---------- [ SUBROUTINES FOR PRINTING TABS/CR/NEWLINES ] ----------
;

%ifndef PRINT_SUB_ROUTINES_ASM
%define PRINT_SUB_ROUTINES_ASM

; Saves AX, DX, SI, before calling the function
; PARAMS
;   - 0) The function to call (a lable)
%macro PRINT_SPECIAL_SAVE_REGS 1

  push ax                         ; Save color
  push dx                         ; Save bytes counter
  push si                         ; Save string pointer
  mov si, ax                      ; second argument, the color (in AH, which goes to high part of SI)
  call %1                         ; Call handler function
  pop si                          ; Restore string pointer
  pop dx                          ; Restore bytes counter
  pop ax                          ; Restore color

%endmacro

; Prints a newline character at the given position in VGA
; USE THIS FUNCITON ONLY IN printStr AND printChar
; PARAMS
;   - 0) ES:DI  => The VGA and the index in it
;   - 1) SI     => The color of the spaces, only high 8 bits (use this parameter only if IO_NEWLINE_SPACES is defined)
; RETURNS
;   - In DI, the new index in VGA
printNewlineRoutine:
  mov ax, di                ; Get VGA index in AX as we divibe it
  mov cx, 80*2              ; Divibe by the number of columns in a row
  xor dx, dx                ; Zero out remainder
  div cx                    ; index % 80*2 = column
%ifdef IO_NEWLINE_SPACES
  sub cx, dx                ; Get column in CX
  shr cx, 1                 ; Divide the column by 2, Because CX is used as the spaces counter while each space is two bytes
  mov ax, si                ; Get color in AH
  mov al, ' '               ; Set character to a space
  cli                       ; Clear direction flag so STOSW will increment DI by 2 each time
  rep stosw                 ; Store AX at ES:DI and increment DI by 2, while CX is not zero
%else
  ; If shouldnt print spaces then just get to the beginning of the next row
  sub di, dx                ; Subtract the column to get to the beginning of the line
  add di, 80*2              ; Add the number of character in a line (80) while each character is 2 bytes
%endif
  ret                       ; The new index in the VGA (DI) will be returned

; Prints a carriage return character at a given index in VGA
; USE THIS FUNCTION ONLY IN printStr AND printChar
; PARAMS
;   - 0) ES:DI  => The VGA and the index in it
; RETURNS
;   - In DI, the new index in VGA
printCarriageReturnRoutine:
  mov ax, di                ; Get index in AX as we divibe it
  mov bx, 80*2              ; Divibe by the number of columns per column
  xor dx, dx                ; Zero out remainder
  div bx                    ; index % 80*2
  sub di, dx                ; Subtract result from index to get to the start of the line
  ret


; Prints a tab at the given index in VGA memory
; USE THIS FUNCTION ONLY IN printStr AND printChar
; PARAMS
;   - 0) ES:DI  => The VGA and the index in it
;   - 1) SI     => The color of the spaces, only high 8 bits (use this parameter only if IO_NEWLINE_SPACES is defined)
; RETURNS
;   - In DI, the new index in VGA
printTabRoutine:
  mov ax, di                      ; Get index in AX as we divibe it
  shr ax, 1                       ; Divide by 2, because we will use a pure cursor location

  inc ax                          ; Increase cursor location, so that tab will always have an effect

  ; We need to get the closest cursor location that is dividable by TXT_TAB_SIZE, so: closest = ceil(n / TXT_TAB_SIZE)
  mov bx, TXT_TAB_SIZE            ; Divide by TXT_TAB_SIZE
  xor dx, dx                      ; Zero out remainder
  div bx                          ; Divide

  test dx, dx                     ; Check if there is a remainder
  jz printTabRoutine_afterInc     ; If there is no remainder then dont increment

  inc ax                          ; If there is a remainder then increment location

printTabRoutine_afterInc:
  shl ax, 2+1                     ; log2(4) = 2   // +1 because also need to multiply by 2, because each character in VGA is 2 bytes

%ifdef IO_NEWLINE_SPACES
  mov cx, ax                      ; New location in CX
  sub cx, di                      ; Get the difference between the new location and the old location
  shr cx, 1                       ; Divide by 2. Get the amount of spaces to fill in CX

  mov ax, si                      ; Get color of spaces in AH
  mov al, ' '                     ; Print spaces
  rep stosw                       ; Repeate printing spaces until CX is 0
%else
  mov di, ax                      ; If should not print spaces then just set the new locatio
%endif

  ret
%endif