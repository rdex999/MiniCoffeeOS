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
  push bp
  mov bp, sp
  sub sp, 14

  ; *(bp - 2)       - Current location in given buffer
  ; *(bp - 4)       - Old GS segment
  ; *(bp - 6)       - Amount of bytes read so far
  ; *(bp - 8)       - Cursor offset (not its location)
  ; *(bp - 10)      - Amount of bytes left to read
  ; *(bp - 12)      - Last character in buffer pointer
  ; *(bp - 14)      - Old DS segment

  mov [bp - 2], di
  mov [bp - 12], di
  mov [bp - 4], gs
  mov [bp - 10], si
  mov word [bp - 6], 0
  mov [bp - 14], ds

  mov word [bp - 8], 0

  mov bx, es
  mov ds, bx

  mov bx, KERNEL_SEGMENT
  mov gs, bx

.readLoop:
  call kbd_waitForChar

  cmp al, BACKSPACE
  je .handleBackspace

  cmp al, CARRIAGE_RETURN
  je .handleEnter

  cmp word [bp - 10], 0
  je .readLoop

  cmp al, TAB
  je .readLoop

  cmp bl, KBD_KEY_LEFT_ARROW
  je .handleLeftArrow

  cmp bl, KBD_KEY_RIGHT_ARROW
  je .handleRightArrow

  test al, al
  jz .readLoop

  inc word [bp - 6]
  inc word [bp - 8]

  mov bx, [bp - 2]
  cmp bx, [bp - 12]
  je .storeCharNoOffset

  push ax
  mov si, [bp - 2]

  mov dx, [bp - 12]
  sub dx, si
  inc dx

  mov di, si
  dec si
  push dx
  call memcpy

  call getCursorIndex
  pop cx
  push ax

  mov di, [bp - 2]
.copyScreenChars
  mov al, es:[di]
  mov ah, gs:[trmColor]
  push di
  push cx
  mov di, ax
  call printChar
  pop cx
  pop di

  inc di
  loop .copyScreenChars

  pop di
  call setCursorIndex

  pop ax

.storeCharNoOffset:
  push ax
  mov ah, gs:[trmColor]
  PRINT_CHAR ax
  pop ax

  mov di, [bp - 2]
  stosb
  inc word [bp - 2]
  inc word [bp - 12]

  dec word [bp - 10]
  jmp .readLoop

.handleLeftArrow:
  cmp word [bp - 8], 0
  je .readLoop

  dec word [bp - 2]
  dec word [bp - 8]

  call getCursorIndex

  dec ax
  mov di, ax
  call setCursorIndex

  jmp .readLoop

.handleRightArrow:
  mov bx, [bp - 2]
  cmp bx, [bp - 12]
  je .readLoop

  inc word [bp - 2]
  inc word [bp - 8]

  call getCursorIndex

  inc ax
  mov di, ax
  call setCursorIndex

  jmp .readLoop

.handleBackspace:
  cmp word [bp - 8], 0
  je .readLoop

  mov di, [bp - 2]
  inc word [bp - 10]
  dec word [bp - 8]
  dec word [bp - 6]

  mov bx, [bp - 2]
  cmp bx, [bp - 12]
  jne .handleBackspace_notOnEnd

  dec word [bp - 12]

.handleBackspace_notOnEnd:
  dec word [bp - 2]

  call getCursorIndex

  dec ax
  mov di, ax
  call setCursorIndex

  mov ah, gs:[trmColor]
  mov al, ' '
  mov di, ax
  call printCharNoAdvance

  jmp .readLoop

.handleEnter:
  mov di, [bp - 12]
  mov byte es:[di], 0

  mov ax, [bp - 6]

.end:
  mov gs, [bp - 4]
  mov ds, [bp - 14]
  mov sp, bp
  pop bp
  ret

%endif