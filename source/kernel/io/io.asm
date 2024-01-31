;
; ---------- [ BASIC INPUT/OUTPUT FUNCTIONS ] ----------
;

%ifndef IO_ASM
%define IO_ASM

%include "source/kernel/macros/macros.asm"

; prints a zero terminated string.
; PARAMS
; 0) const char* (DI) => the string
printStr:
  mov al, [di]
  cmp al, 0
  je printStr_end

  cmp al, 0Bh       ; check for tab
  je printStr_tab

  mov ah, 0Eh
  int 10h
  inc di 
  jmp printStr

printStr_end:
  ret

printStr_tab:       ; loops 4 times and prints a space each time
  inc di                      ; Increase string pointer
  push di                     ; Save string pointer for now
  GET_CURSOR_POSITION 0       ; Get the column in DL
printStr_tabLoop:
  PRINT_CHAR ' '
  inc dl                      ; Increase column number
  mov al, dl                  ; Store copy of column number in AL
  mov bl, 4                   ; Because divibing by 4
  xor ah, ah                  ; Zero remainder register
  div bl                      ; divibe the copy of the column number by 4
  test ah, ah                 ; Check if the remainder is 0 (to stop printing spaces)
  jnz printStr_tabLoop        ; If the remainder is not zero then continue printing spaces

  ; Will get here when need to stop printing spaces
  pop di                      ; Restore string pointer
  jmp printStr                ; Continue printing characters from the string

; reads a string into a buffer with echoing. zero terminates the string.
; PARAMS
; 0) char* (DI) => buffer
; 1) int16 (SI) => length to read
; RETURNS
; int16 => number of bytes read
read:
  push bp
  mov bp, sp
  sub sp, 2

  GET_CURSOR_POSITION 0

  mov [bp - 2], dx  ; store starting location
  xor cx, cx        ; zero out bytes read counter
  dec si            ; dont overwrite

read_loop:
  xor ah, ah  ; read single character (returns it in AL)
  int 16h

  cmp al, 13  ; check for <enter>
  je read_end

  cmp al, 8   ; check for <backspace>
  je read_backspace

  mov [di], al    ; write character to buffer

  mov ah, 0Eh   ; echo character back
  int 10h

  inc di    ; increase buffer pointer
  inc cx    ; increase bytes read
  dec si    ; decrement bytes left to read
  jnz read_loop ; if bytes left to read is 0 then stop reading

read_end:

  mov byte [di], 0  ; zero terminate the string

  mov ax, cx  ; return counter
  mov sp, bp
  pop bp
  ret

read_backspace:
  
  GET_CURSOR_POSITION 0 

  cmp [bp - 2], dx    ; Compare the location at which started reading to this location
  jge read_loop       ; if the starting location is greater or equal to this then dont delete characters

  dec cx    ; decrement characters read
  dec di    ; decrement buffer pointer
  inc si    ; increase bytes left to read

  dec dx    ; decrement location

  xor bh, bh  ;
  mov ah, 2   ; set location from DX (DH => row, DL, column)
  int 10h     ;

  mov ah, 0Ah   ; write a space without addvancing the cursor
  mov al, ' '   ; 
  int 10h       ;

  jmp read_loop

%endif