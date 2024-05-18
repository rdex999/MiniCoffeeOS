;
; ---------- [ READ A STRING FROM THE KEYBOARD ] ---------
;

%ifndef READ_ASM
%define READ_ASM

; reads a string into a buffer with echoing. zero terminates the string.
; PARAMS
;   - 0) ES:DI  => buffer
;   - 1) SI     => length to read
; RETURNS
;   - AX  => number of bytes read
read:
  push bp                             ; Save stack frame
  mov bp, sp                          ;
  sub sp, 14                          ; Allocate space for local stuff

  ; *(bp - 2)       - Current location in given buffer
  ; *(bp - 4)       - Old GS segment
  ; *(bp - 6)       - Amount of bytes read so far
  ; *(bp - 8)       - Cursor offset (not its location)
  ; *(bp - 10)      - Amount of bytes left to read
  ; *(bp - 12)      - Last character in buffer pointer
  ; *(bp - 14)      - Old DS segment

  mov [bp - 2], di                    ; Save current location in buffer
  mov [bp - 12], di                   ; Save location of last character in buffer
  mov [bp - 4], gs                    ; Save old GS segment (GS will be used as the kernels segment)
  mov [bp - 10], si                   ; Save requested amount of bytes to read
  mov word [bp - 6], 0                ; Initialize bytes read so far to 0
  mov [bp - 14], ds                   ; Store old DS segment (using it for memcpy)

  mov word [bp - 8], 0                ; Initialize the cursors offset to 0

  mov bx, es                          ; Set ES = DS
  mov ds, bx                          ;

  mov bx, KERNEL_SEGMENT              ; Set GS to the kernels segment so can access the terminals color
  mov gs, bx                          ;

.readLoop:
  call kbd_waitForChar                ; For for a keypress, and get teh ascii code in AL and the keycode in BL

  cmp al, BACKSPACE                   ; Check if the key pressed is the backspace key
  je .handleBackspace                 ; If it is, move the characters backwards and shit

  cmp al, CARRIAGE_RETURN             ; Check if the key pressed is the enter key
  je .handleEnter                     ; If it is, null terminate the string and return the amount of bytes read

  cmp bl, KBD_KEY_LEFT_ARROW          ; Check if the key pressed is the left arrow
  je .handleLeftArrow                 ; If its the left arrow, handle it

  cmp bl, KBD_KEY_RIGHT_ARROW         ; Check if the key pressed is the right arrow
  je .handleRightArrow                ; If it is, handle it

  cmp word [bp - 10], 0               ; Check if the amount of bytes left to read is 0, in which case dont allow any key except backspace and enter
  je .readLoop                        ; If its zero, continue waiting for a key

  cmp al, TAB                         ; Check if the key pressed is a tab
  je .readLoop                        ; If it is, continue waiting for a key

  test al, al                         ; If its none of the above, (because also checked the keycode) check if the ascii character is 0
  jz .readLoop                        ; If it is, continue waiting for a key (its null if the key was ALT or some shit)

  inc word [bp - 6]                   ; Increase the amount of bytes read so far
  inc word [bp - 8]                   ; Increase the cursors offset

  mov bx, [bp - 2]                    ; Get the current location in the buffer
  cmp bx, [bp - 12]                   ; Check if its the same as the location of the last character in the buffer
  je .storeCharNoOffset               ; If it is the same, dont copy characters and offset shit

  ; If its not the same, need to copy characters in the buffer one place to the right, 
  ; then copy the characters on the screen and then print the entered character
  push ax                             ; Save entered character
  mov si, [bp - 2]                    ; Get the current location in the buffer

  mov dx, [bp - 12]                   ; Get the location of the last character in the buffer
  sub dx, si                          ; Get the amount of characters between the current character and the last one
  inc dx                              ; Increase by 1 to count the last character

  mov di, si                          ; Set the destination to the location of the next character
  dec si                              ; Set source to the character before the next one (copy the characters one place back)
  push dx                             ; Save amount of bytes to copy
  call memcpy                         ; Copy the characters

  call getCursorIndex                 ; Get the current cursor location so can change back to it
  pop cx                              ; Restore amount of bytes copied
  push ax                             ; Save current cursor location

  mov di, [bp - 2]                    ; Get a pointer to the location of the next character
.copyScreenChars:
  mov al, es:[di]                     ; Get the current character in the string
  mov ah, gs:[trmColor]               ; Set the color to the current terminal color
  push di                             ; Save current character pointer
  push cx                             ; Save amount of characters to copy on the screen
  mov di, ax                          ; Get the character and color to print in DI
  call printChar                      ; Print the current character 1 place forward
  pop cx                              ; Restore amount of characters to copy
  pop di                              ; Restore current character pointer

  inc di                              ; Increase current character pointer
  loop .copyScreenChars               ; Continue offseting characters

  pop di                              ; Restore original cursor location
  call setCursorIndex                 ; Reset the cursors location to its original value

  pop ax                              ; Restore character entered

.storeCharNoOffset:
  push ax                             ; Save character entered
  mov ah, gs:[trmColor]               ; Set the print color to the current color of the terminal
  PRINT_CHAR ax                       ; Print the character
  pop ax                              ; Restore character entered

  mov di, [bp - 2]                    ; Get a pointer to the current character location
  stosb                               ; Store the character entered in the buffer
  inc word [bp - 2]                   ; Increase current character in buffer pointer
  inc word [bp - 12]                  ; Increase location of last character in the buffer

  dec word [bp - 10]                  ; Decrement amount of bytes left to read
  jmp .readLoop                       ; Continue reading characters

.handleLeftArrow:
  cmp word [bp - 8], 0                ; Check if the cursor offset is 0, in which case cant go a place backwards
  je .readLoop                        ; If its zero, continue reading characters

  dec word [bp - 2]                   ; Decrement the current character location in buffer
  dec word [bp - 8]                   ; Decrement the cursors offset

  call getCursorIndex                 ; Get the current cursor location

  dec ax                              ; Decrement it
  mov di, ax                          ; Argument goes in DI (new cursor location)
  call setCursorIndex                 ; Move the cursor one place back

  jmp .readLoop                       ; Continue reading characters

.handleRightArrow:
  mov bx, [bp - 2]                    ; Get the current location in the buffer
  cmp bx, [bp - 12]                   ; Check if its the same as the location of the last character in the buffer
  je .readLoop                        ; If its the same, then the dont allow the cursor to go right. Continue reading characters

  inc word [bp - 2]                   ; If not the same, increase the location of the current character in the buffer
  inc word [bp - 8]                   ; Increase the cursors offset

  call getCursorIndex                 ; Get the current cursor location

  inc ax                              ; Increase it
  mov di, ax                          ; Argument goes in DI
  call setCursorIndex                 ; Move the cursor one place to the right

  jmp .readLoop                       ; Continue reading characters

.handleBackspace:
  cmp word [bp - 8], 0                ; Check if the cursors offset is 0 (the initial place of the cursor)
  je .readLoop                        ; If it is, then there is nothing to delete, continue reading characters

  dec word [bp - 2]                   ; Decrement current location in buffer
  dec word [bp - 6]                   ; Decrement amount of bytes read so far
  dec word [bp - 8]                   ; Decrement the cursors offset
  inc word [bp - 10]                  ; Increase amount of bytes left to read
  dec word [bp - 12]                  ; Decrement the location of the last character in the buffer

  mov bx, [bp - 2]                    ; Get the current location in the buffer
  cmp bx, [bp - 12]                   ; Check if its the same as the location of the last character in the buffer
  je .handleBackspace_onEnd           ; If its the same, dont offset characters

  mov si, [bp - 2]                    ; Get a pointer to the current character in the buffer

  mov dx, [bp - 12]                   ; Get a pointer to the last character in the buffer
  sub dx, si                          ; Get the amount of bytes to copy
  push dx                             ; Save it
  inc dx                              ; Increase by one for the last character

  inc si                              ; Increase source location, so copy from the next characters location
  mov di, si                          ; Set the destination equal to the source
  dec di                              ; Decrement destination by 1
  call memcpy                         ; Copy the characters one place back

  call getCursorIndex                 ; Get the current cursor location
  dec ax                              ; Decrement it
  push ax                             ; Save the result
  mov di, ax                          ; Set argument for setCursorLocation
  call setCursorIndex                 ; Move the cursor one place back

  pop ax                              ; Restore cursor location
  pop cx                              ; Restore amount of bytes copied
  push ax                             ; Save cursor location

  mov di, [bp - 2]                    ; Get a pointer to the current character in the buffer
.handleBackspace_copyChars:
  push cx                             ; Save amount of characters to copy
  push di                             ; Save current character location
  mov al, es:[di]                     ; Get the current character from the buffer
  mov ah, gs:[trmColor]               ; Set color to the terminals color
  mov di, ax                          ; DI = character and color
  call printChar                      ; Print the character one place back
  pop di                              ; Restore character pointer
  pop cx                              ; Restore amount of characters to copy

  inc di                              ; Increase it
  loop .handleBackspace_copyChars     ; Continue offseting characters

  mov al, ' '                         ; Need to print a space to delete the last character from the screen
  mov ah, gs:[trmColor]               ; Print with the terminals color
  mov di, ax                          ; Character and color to print goes in DI
  call printChar                      ; Print the space

  pop di                              ; Restore cursor location before offseting characters
  call setCursorIndex                 ; Reset the cursors location to it
  jmp .readLoop                       ; Continue reading characters

.handleBackspace_onEnd:

  call getCursorIndex                 ; Get the current character location

  dec ax                              ; Decrement it
  mov di, ax                          ; New cursor location goes in DI
  call setCursorIndex                 ; Move the cursor one place to the left

  mov al, ' '                         ; Need to print a space to delete the last character on the screen
  mov ah, gs:[trmColor]               ; Color to print in, the current terminal color
  mov di, ax                          ; Character and color goes in DI
  call printCharNoAdvance             ; Print the space without advancing the cursor

  jmp .readLoop                       ; Continue reading characters

.handleEnter:
  mov di, [bp - 12]                   ; Get a pointer to the last character in the buffer (to the character after it)
  mov byte es:[di], 0                 ; Null terminate the string

  mov ax, [bp - 6]                    ; Return the amount of bytes read

.end:
  mov gs, [bp - 4]                    ; Restore used segments
  mov ds, [bp - 14]                   ;
  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  ret

%endif