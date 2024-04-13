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
  je printCharRoutine_newline                   ; If newline then handle it

  cmp al, CARRIAGE_RETURN                       ; Check for carriage return character
  je printCharRoutine_carriageReturn            ; If carriage return then handle it

  cmp al, TAB                                   ; Check for tab character
  je printCharRoutine_tab                       ; If tab then handle it

  cld                                           ; Clear direction flag so STOSW will increase DI
  stosw                                         ; Store AX in the address of ES:DI ( *(ES:DI) ) and increase DI by 2
  ret

printCharRoutine_newline:
  PRINT_SPECIAL_SAVE_REGS printNewlineRoutine         ; Save registers and call printNewlineRoutine
  ret

printCharRoutine_carriageReturn:
  PRINT_SPECIAL_SAVE_REGS printCarriageReturnRoutine  ; Save registers and call printCarriageReturnRoutine
  ret

printCharRoutine_tab:
  PRINT_SPECIAL_SAVE_REGS printTabRoutine             ; Save registers and call printTabnRoutine
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
  push gs                   ;
  mov bx, VGA_SEGMENT       ; Set ES to VGA segment (0B8000h) so we write to the VGA memory
  mov es, bx                ;
  mov bx, KERNEL_SEGMENT    ; Set GS to kernel segment to read corect trmIndex
  mov gs, bx                ;

  mov di, gs:[trmIndex]     ; Get the index of the VGA in DI, as we use ES:DI to write to the VGA
  cld                       ; Clear direction flag so LODSB and STOSW will increment registers (SI and DI, respectively)
printStr_loop:
  lodsb                     ; Load character from DS:SI to AL, and increment SI

  test al, al                       ; Check if its the null character
  jz printStr_end                   ; If null then return

  call printCharRoutine 
  jmp printStr_loop                 ; Continue printing characters

printStr_end:
  mov gs:[trmIndex], di             ; Update the cursor location

  pop gs                            ; Restore GS segment
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
  push gs                         ; 
  mov bx, VGA_SEGMENT             ; Set ES segment to VGA segment
  mov es, bx                      ;
  mov bx, KERNEL_SEGMENT          ; Set GS segment to kernel segment
  mov gs, bx                      ;

  mov ax, di                      ; DI is the color (the lower 8 bits)
  mov ah, al                      ; We need to color in AH

  mov di, gs:[trmIndex]           ; Get the current cursor location

  cld                             ; Clear direction flag, so LODSB will increment SI and STOSW will increment DI
printStrLen_loop:
  lodsb                           ; Get a byte from DS:SI to AL (faster than MOV)

  call printCharRoutine           ; Print the character and perform checks (if its a special character)

  dec dx                          ; Decrement bytes counter
  jnz printStrLen_loop            ; As long as the bytes counter is not zero continue printing characters

printStrLen_end:
  mov gs:[trmIndex], di           ; Update the cursor location

  pop gs                          ; Restore old GS segment
  pop es                          ; Restore old ES segment
  ret


; Prints a character at the current cursor position
; PARAMS
;   - 0) DI   => The character, and the color. (character - low 8 bits, color high 8 bits)
printChar:
  mov ax, di                          ; Get the character and color in AX, as it has a low and a high part

  push es                             ; Save segments
  push gs                             ;
  mov bx, VGA_SEGMENT                 ; Set ES to VGA segment
  mov es, bx                          ;
  mov bx, KERNEL_SEGMENT              ; Set GS to kernel segment
  mov gs, bx                          ;
  mov di, gs:[trmIndex]               ; Get the current index in VGA (the cursor location) in DI

  call printCharRoutine

printChar_end:
  mov gs:[trmIndex], di               ; Update to new VGA index
  pop gs                              ; Restore GS segment
  pop es                              ; Restore ES segment
  ret

; reads a string into a buffer with echoing. zero terminates the string.
; PARAMS
; 0) char* (DI) => buffer
; 1) int16 (SI) => length to read
; RETURNS
; int16 => number of bytes read
read:
  push bp
  mov bp, sp
  sub sp, 6                   ; Allocate 4 bytes

  mov [bp - 2], si            ; Store bytes left to read
  mov word [bp - 4], 0        ; Store amount of bytes read
  mov [bp - 6], gs            ; Store old GS segment
  mov bx, KERNEL_SEGMENT
  mov gs, bx

read_loop:

%ifndef KBD_DRIVER
  xor ah, ah                  ;
  int 16h                     ; int16h/AH=0   // Get character input 
%else
  push di                     ; Save buffer pointer
  call kbd_waitForChar        ; Wait for a character input
  pop di                      ; Restor buffer pointer
%endif
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

  mov ah, gs:[trmColor]
  PRINT_CHAR al, ah           ; Write character and advance the cursor

  pop di                      ; Restore buffer pointer

  inc word [bp - 4]           ; Increase the amount of bytes read
  dec word [bp - 2]           ; Decrement the amount of bytes left to read
  jmp read_loop               ; Continue reading characters

read_handleEnter:
  mov byte [di], 0            ; zero terminate the string
  mov ax, [bp - 4]            ; Return the amount of bytes read

  mov gs, [bp - 6]            ; Rstore old GS
  mov sp, bp                  ;
  pop bp                      ; Restore stack frame
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