;
; ---------- [ BASIC INPUT/OUTPUT FUNCTIONS ] ----------
;

%ifndef IO_ASM
%define IO_ASM

%include "kernel/macros/macros.asm"
%include "kernel/io/printf.asm"

; prints a zero terminated string.
; PARAMS
; 0) const char* (DI) => the string
printStr:
  mov al, [di]                    ; AL = character from string
  cmp al, 0                       ; If the character is 0, then stop writing
  je printStr_end

  cmp al, 0Bh                     ; check for tab
  je printStr_tab

  cmp al, 0Ah                     ; Check for newline
  je printStr_newline

  mov ah, 0Eh                     ; int10h/AH=0Eh   // Write character from AL and advance the cursor
  int 10h
  inc di                          ; Increase string pointer
  jmp printStr                    ; Continue printing more characters

printStr_end:
  ret

printStr_tab:       ; loops 4 times and prints a space each time
  inc di                      ; Increase string pointer
  push di                     ; Save string pointer for now
  GET_CURSOR_POSITION 0       ; Get the column in DL
printStr_tabLoop:
  PRINT_CHAR ' '              ; Print a space
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

printStr_newline:
  mov ah, 0Eh                 ; value 10 is in AL
  int 10h                     ; print Line Feed character
  PRINT_CHAR 0Dh              ; print Carriage Return character
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
  sub sp, 4                   ; Allocate 4 bytes

  mov [bp - 2], si            ; Store bytes left to read
  mov word [bp - 4], 0        ; Store amount of bytes read

read_loop:
  ; xor ah, ah                  ;
  ; int 16h                     ; int16h/AH=0   // Get character input 
  push di
  call kbd_waitForChar
  pop di

  ; Special characters check 
  cmp al, 13                  ; Check for <enter>
  je read_handleEnter
  cmp al, 8                   ; Check for <backspace>
  je read_handleBackspace

  ; If the character entered was not <enter> or <backspace>,
  ; and the amount of characters left to read is 0 then dont allow to read more 
  cmp word [bp - 2], 0        ; If the amount of bytes left to read is 0 then dont read more characters
  je read_loop

  mov [di], al                ; Store character in buffer
  inc di                      ; Increase buffer pointer to point to next available location
  push di                     ; Store buffer pointer

  mov ah, 0Eh                 ;
  int 10h                     ; int10h/AH=0Eh   // Write character and advance the cursor

  pop di                      ; Restore buffer pointer

  inc word [bp - 4]           ; Increase the amount of bytes read
  dec word [bp - 2]           ; Decrement the amount of bytes left to read
  jmp read_loop               ; Continue reading characters

read_handleEnter:
  mov byte [di], 0            ; zero terminate the string
  mov ax, [bp - 4]            ; Return the amount of bytes read

  mov sp, bp
  pop bp
  ret

read_handleBackspace:
  cmp word [bp - 4], 0          ; Compare the amount of bytes read to 0, to check if can delete more characters
  je read_loop                  ; If the amount of bytes read is 0, then dont allow to delete more

  dec di                        ; Decrement buffer pointer
  dec word [bp - 4]             ; Decrement bytes read so far
  inc word [bp - 2]             ; Increase number of bytes left to read

  push di                       ; Save buffer pointer for now

  GET_CURSOR_POSITION 0         ; Get the cursor position on page 0. DL => column, DH => row
  test dl, dl                               ; Check if the column is 0
  jnz read_handleBackspace_decCol           ; If the column is not zero then decrement it

  ; If the column is zero then decrement the row and set column to 79
  dec dh                                    ; Decrement row
  mov dl, 80-1                              ; Set column to 79
  jmp read_handleBackspace_setCursorPos     ; Skip next line

read_handleBackspace_decCol:
  ; If the column is not zero then decrement it
  dec dl                                  ; Decrement column

read_handleBackspace_setCursorPos:
  xor bh, bh                              ; Set page number to 0
  mov ah, 2                               ;
  int 10h                                 ; int10h/AH=2   // Set cursor position, DL => col, DH => row (DL, DH allready set)

  mov cx, 1                               ; Write the character one time
  xor bh, bh                              ; Write on page zero
  mov al, ' '                             ; Write a space to delete previous character
  mov ah, 0Ah                             ; int10h/AH=0Ah   // Write character from AL without advancing the cursor 
  int 10h

  pop di                                  ; Restore buffer pointer
  jmp read_loop

%endif