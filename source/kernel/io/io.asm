;
; ---------- [ BASIC INPUT/OUTPUT FUNCTIONS ] ----------
;

; prints 10 and 13 (ascii codes). goes down a line
%macro PRINT_NEWLINE 0

  mov ah, 0Eh
  mov al, 10
  int 10h

  mov ah, 0Eh
  mov al, 13
  int 10h

%endmacro

; prints a single character
%macro PRINT_CHAR 1

  mov ah, 0Eh
  mov al, %1
  int 10h

%endmacro

; prints a zero terminated string.
; PARAMS
; 0) const char* (DI) => the string
printStr:
  mov al, [di]
  cmp al, 0
  je printStr_end

  cmp al, 0Bh   ; check for tab
  je printStr_tab

  mov ah, 0Eh
  int 10h
  inc di 
  jmp printStr

printStr_end:
  ret

printStr_tab:       ; loops 4 times and prints a space each time
  mov cx, 4
printStr_tabLoop:
  PRINT_CHAR ' '
  loop printStr_tabLoop
  inc di 
  jmp printStr


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

  mov ah, 3     ;
  xor bh, bh    ; get cursor location 
  int 10h       ;

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
  mov ah, 3   ; get cursor location
  xor bh, bh  ;
  int 10h     ;

  cmp [bp - 2], dx    ; Compare the location at which started reading to this location
  jge read_loop       ; if the starting location is greater or equal to this then dont delete characters

  dec cx    ; decrement characters read
  dec di    ; decrement buffer pointer
  inc si    ; increase bytes left to read

  dec dx    ; decrement location

  xor bh, bh  ;
  mov ah, 2   ; set location from DX (DH => row, DL, column)
  int 10h     ;

  mov ah, 0Ah   ; write a space
  mov al, ' '   ; 
  int 10h       ;

  jmp read_loop
