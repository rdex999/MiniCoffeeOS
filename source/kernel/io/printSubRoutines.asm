;
; ---------- [ SUBROUTINES FOR PRINTING TABS/CR/NEWLINES ] ----------
;

%ifndef PRINT_SUB_ROUTINES_ASM
%define PRINT_SUB_ROUTINES_ASM

%macro PRINT_STR_SPECIAL_CHAR_STUB 1

  ; Save the color, then save the string pointer if need to use it as a parameter (if printing spaces in newlines is enabled)
  push ax                       ; Save color

  ; If should print spaces in newlines/tabs, then save SI as it will be the second parameter, as the color
%ifdef IO_NEWLINE_SPACES
  push si                       ; Save string pointer
  mov si, ax                    ; Set second argument to color (high 8 bits)
%endif
  call %1                       ; Call the special char handler function
%ifdef IO_NEWLINE_SPACES
  pop si                        ; Restore string pointer if it was used
%endif
  pop ax                        ; Restore color

%endmacro

%macro PRINT_STR_LEN_SPECIAL_CHAR_STUB 1
  
  ; Save the color, then save the string pointer if need to use it as a parameter (if printing spaces in newlines is enabled)
  push ax                       ; Save color
  push dx

  ; If should print spaces in newlines/tabs, then save SI as it will be the second parameter, as the color
%ifdef IO_NEWLINE_SPACES
  push si                       ; Save string pointer
  mov si, ax                    ; Set second argument to color (high 8 bits)
%endif
  call %1                       ; Call the special char handler function
%ifdef IO_NEWLINE_SPACES
  pop si                        ; Restore string pointer if it was used
%endif
  pop dx
  pop ax                        ; Restore color

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
  mov ax, di                  ; Get index in AX as we divibe it

  add ax, 2                   ; Increase character location by 1 (each character is two bytes) so tab will always have an effect

  ; Closest high dividable number => num * ceil(num / 4)
  mov bx, TXT_TAB_SIZE        ; Divibe by the tab size
  xor dx, dx                  ; Zero out remainder
  div bx                      ;

  test dx, dx                 ; Check if the remainder
  jz printTabRoutine_afterInc ; If the remainder is zero then dont increment result

  add ax, 2                   ; Increase character location by 1 (each character is two bytes)

printTabRoutine_afterInc:
  shl ax, 2                   ; log2(4) = 2   // Multiply by 4 (TXT_TAB_SIZE)
%ifdef IO_NEWLINE_SPACES
  ; If should fill with spaces then get the amount of spaces to fill, then fill it
  mov cx, ax                  ; Closes index in CX
  sub cx, di                  ; Get the amount of spaces to fill in CX
  shr cx, 1                   ; because we will store 2 bytes each time, divide by 2 so we wont store 2*2 bytes
  mov ax, si                  ; Color in AH
  mov al, ' '                 ; Space character in AL
  cli                         ; Clear direction flag so STOSW will increment DI by 2 each time
  rep stosw                   ; Store AX at ES:DI and increment DI by 2 each time, until CX is zero
%else
  ; If should not fill with spaces then just inrease the VGA index
  mov di, ax                  ; Get the new index in VGA in DI
%endif
  ret

%endif