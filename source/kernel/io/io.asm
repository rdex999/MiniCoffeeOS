;
; ---------- [ BASIC INPUT/OUTPUT FUNCTIONS ] ----------
;

%ifndef IO_ASM
%define IO_ASM

%include "kernel/macros/macros.asm"
%include "kernel/io/printf.asm"
%include "kernel/io/printSubRoutines.asm"

; Just prints a character, doesnt advance the cursor.
; If its a special character (newline, tab, carriage return) then the function saves AX, DI, SI, DX
; USE ONLY IN PRINT FUNCTIONS (printStr, printStrLen, printChar)
; PARAMS
;   - 0) AL     => The character
;   - 1) AH     => The color
;   - 2) ES:DI  => The VGA and the index in it
; RETURNS
;   -    ES:DI  => The new index in the VGA
printCharRoutine:
  ; Check for special characters, If special than handle it, if not then just print it
  cmp al, NEWLINE                               ; Check for newline character
  je .newline                   ; If newline then handle it

  cmp al, CARRIAGE_RETURN                       ; Check for carriage return character
  je .carriageReturn            ; If carriage return then handle it

  cmp al, TAB                                   ; Check for tab character
  je .tab                       ; If tab then handle it

  cld                                           ; Clear direction flag so STOSW will increase DI
  stosw                                         ; Store AX in the address of ES:DI ( *(ES:DI) ) and increase DI by 2
  jmp .checkScreenEnd

.newline:
  PRINT_SPECIAL_SAVE_REGS printNewlineRoutine         ; Save registers and call printNewlineRoutine
  jmp .checkScreenEnd

.carriageReturn:
  PRINT_SPECIAL_SAVE_REGS printCarriageReturnRoutine  ; Save registers and call printCarriageReturnRoutine
  jmp .checkScreenEnd

.tab:
  PRINT_SPECIAL_SAVE_REGS printTabRoutine             ; Save registers and call printTabnRoutine

.checkScreenEnd:
  cmp di, 2 * (80 * 25)                         ; Check if its the end of the screen (bottom left corner)
  jb .end                                       ; If its not the end, just return

  push ds                                       ; If it is the end, save the registers we promised to save, because changin them
  push si                                       ;
  push dx                                       ;
  push ax                                       ;

  mov bx, es                                    ; Set DS = ES because using MOVSB, and we want to copy lines from VGA to another location in VGA
  mov ds, bx                                    ;

  mov si, 2 * 80                                ; Copy starting from the first character of the second line
  mov cx, 24 * 80                               ; Amount of characters to copy, because starting from the second line, copy one line less
  xor di, di                                    ; The destination, store the characters starting from the first character of the first line
  cld                                           ; Clear direction flag so MOVSB will increment DI and SI
  rep movsw                                     ; Copy the whole screen one line up

  ; Clear the last line
  pop ax                                        ; Get the given color
  push ax                                       ; Save it once again

  xor al, al                                    ; Set the character to null (could use MOV AX, ' ')
  mov di, 2 * (80 * 24)                         ; The destination, where to print the null characters (the last row of the VGA)
  mov cx, 80                                    ; Amount of characters to print
  rep stosw                                     ; Set the last row to spaces (clear it)

  mov di, 2 * (80 * 24)                         ; Set the cursors location (return value) to the beginning of the last row

  pop ax                                        ; Restore registers
  pop dx                                        ;
  pop si                                        ;
  pop ds                                        ;

.end:
  ret


; Prints a null terminated string
; PARAMS
;   - 0) DI       => The color to write (lower 8 bits)
;   - 1) DS:SI    => Null terminated string
; Doesnt return anything
printStr:
  mov ax, di                ; Get color in AX
  mov ah, al                ; Color should be in high 8 bits

  push es                   ; Save segments
  mov bx, VGA_SEGMENT       ; Set ES to VGA segment (0B8000h) so we write to the VGA memory
  mov es, bx                ;

  push ax                   ; Save color
  push si                   ; Save string pointer
  call getCursorIndex
  shl ax, 1
  mov di, ax                ; VGA index in DI
  pop si                    ; Restore string pointer
  pop ax                    ; Restore color

  cld                       ; Clear direction flag so LODSB and STOSW will increment registers (SI and DI, respectively)
printStr_loop:
  lodsb                     ; Load character from DS:SI to AL, and increment SI

  test al, al                       ; Check if its the null character
  jz printStr_end                   ; If null then return

  call printCharRoutine 
  jmp printStr_loop                 ; Continue printing characters

printStr_end:
  shr di, 1
  call setCursorIndex
  pop es                            ; Restore ES segment
  ret


; Print a string, with fixed length. Meaning it takes the string length as a parameter so no need for a NULL character. (NULL is ignored)
; PARAMS
;   - 0) DI     => The color to print with. Lower 8 bits only
;   - 1) DS:SI  => The string
;   - 2) DX     => String length (The index of the last byte + 1)
; Doesnt return anything
printStrLen:
  push es                         ; Save old segments
  mov bx, VGA_SEGMENT             ; Set ES segment to VGA segment
  mov es, bx                      ;
  
  test dx, dx
  jz printStrLen_end

  mov ax, di                      ; DI is the color (the lower 8 bits)
  mov ah, al                      ; We need to color in AH

  push ax
  push si
  push dx
  call getCursorIndex
  shl ax, 1
  mov di, ax
  pop dx
  pop si
  pop ax

  cld                             ; Clear direction flag, so LODSB will increment SI and STOSW will increment DI
printStrLen_loop:
  lodsb                           ; Get a byte from DS:SI to AL (faster than MOV)

  call printCharRoutine           ; Print the character and perform checks (if its a special character)

  dec dx                          ; Decrement bytes counter
  jnz printStrLen_loop            ; As long as the bytes counter is not zero continue printing characters
  
  shr di, 1
  call setCursorIndex

printStrLen_end:
  pop es                          ; Restore old ES segment
  ret


; Prints a character at the current cursor position, and advances the cursor
; PARAMS
;   - 0) DI   => The character, and the color. (character - low 8 bits, color high 8 bits)
printChar:
  mov ax, di                          ; Get the character and color in AX, as it has a low and a high part

  push es                             ; Save segments
  mov bx, VGA_SEGMENT                 ; Set ES to VGA segment
  mov es, bx                          ;

  push ax
  call getCursorIndex
  shl ax, 1
  mov di, ax
  pop ax

  call printCharRoutine

  shr di, 1
  call setCursorIndex

printChar_end:
  pop es                              ; Restore ES segment
  ret


; Prints a character at the current cursor position, but doesnt advance the cursor
; PARAMS
;   - 0) DI   => The character, and the color. (character - low 8 bits, color high 8 bits)
; Doesnt return anything
printCharNoAdvance:
  mov ax, di

  push es
  mov bx, VGA_SEGMENT
  mov es, bx

  push ax
  call getCursorIndex
  shl ax, 1
  mov di, ax
  pop ax

  call printCharRoutine

printCharNoAdvance_end:
  pop es
  ret


; reads a string into a buffer with echoing. zero terminates the string.
; PARAMS
;   - 0) ES:DI  => buffer
;   - 1) SI     => length to read
; RETURNS
;   - AX  => number of bytes read
read:
  push bp
  mov bp, sp
  sub sp, 4

  mov [bp - 2], gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx

  mov word [bp - 4], 0

read_loop:
  SAVE_BEFORE_CALL kbd_waitForChar, di, si

  cmp al, CARRIAGE_RETURN
  je read_handleEnter

  cmp al, BACKSPACE
  je read_handleBackspace

  cmp al, TAB
  je read_loop

  test si, si
  jz read_loop
  dec si

  cld
  stosb

  inc word [bp - 4]
  push di
  push si
  mov ah, gs:[trmColor]
  mov di, ax
  call printChar
  pop si
  pop di
  jmp read_loop

read_handleBackspace:
  cmp word [bp - 4], 0
  je read_loop
  
  SAVE_BEFORE_CALL getCursorIndex, di, si
  test ax, ax
  jz read_loop

  dec ax
  push di
  push si
  mov di, ax
  call setCursorIndex

  mov ah, gs:[trmColor]
  mov al, ' '
  mov di, ax
  call printCharNoAdvance

  pop si
  pop di

  dec di
  dec word [bp - 4]
  inc si
  jmp read_loop

read_handleEnter:
  mov byte es:[di], 0
  mov ax, [bp - 4]

read_end:
  mov gs, [bp - 2]
  mov sp, bp
  pop bp
  ret
%endif