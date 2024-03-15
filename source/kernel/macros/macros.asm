;
; ---------- [ BASIC MACROS ] ----------
;

%ifndef MACROS_ASM
%define MACROS_ASM

%include "source/kernel/macros/errorCodes.asm"

; LC stands for: Line Feed, Carriage Return
%define NEWLINE_LC 0Ah, 0Dh
%define NEWLINE 0Ah
%define TAB 0Bh

%define KERNEL_SEGMENT 7E0h

%define KBD_DRIVER

; 2*20*512  // 2 FATs, 20 sectors per fat, 512 bytes per sector
%define TOTAL_FAT_SIZE 20480

; 512 * 32 = 16384   // 512 => root directory entries // 32 bytes per entry
%define ROOT_DIRECTORY_SIZE 16384


%define MAX_PATH_FORMATTED_LENGTH 256

%define VGA_SEGMENT 0B800h

%define PIC_MASTER_CMD 20h
%define PIC_MASTER_DATA 21h

%define PIC_SLAVE_CMD 0A0h
%define PIC_SLAVE_DATA 0A1h

%define PIC_EOI 20h

%define ICW1_INIT 10h
%define ICW1_ICW4 1
%define ICW4_8086 1

%define PS2_DATA_PORT 60h
%define PS2_COMMAND_PORT 64h
%define PS2_STATUS_REGISTER 64h

%define PS2_CMD_DISABLE_FIRST_PORT 0ADh
%define PS2_CMD_DISABLE_SECOND_PORT 0A7h
%define PS2_CMD_ENABLE_FIRST_PORT 0AEh
%define PS2_CMD_ENABLE_SECOND_PORT 0A8h
%define PS2_CMD_READ_OUTPUT_BUFFER 0D0h
%define PS2_CMD_READ_CONFIGURATION_BYTE 20h
%define PS2_CMD_WRITE_CONFIGURATION_BYTE 60h
%define PS2_CMD_SET_SCAN_CODE_SET 0F0h
%define PS2_CMD_SELF_TEST 0AAh
%define PS2_CMD_TEST_FIRST_PORT 0ABh
%define PS2_CMD_TEST_SECOND_PORT 0A9h

%define PS2_SCAN_CODE_SET_2 2
%define PS2_SELF_TEST_RESULT_OK 55h

%define INT_DIVIBE_ZERO 0
%define INT_KEYBOARD 9

%define IRQ_KEYBOARD 1

%define KBD_SCANCODE_NORM_BREAK 0F0h
%define KBD_SCANCODE_SPECIAL 0E0h


; compares two strings and if equal then jump to given lable
%macro STRCMP_JUMP_EQUAL 3

  lea di, %1
  lea si, %2
  call strcmp
  test ax, ax
  jz %3

%endmacro

%macro CMDCMP_JUMP_EQUAL 3

  lea di, [%1]
  lea si, [%2]
  call cmdcmp
  test ax, ax
  jz %3

%endmacro

; prints 10 and 13 (ascii codes). goes down a line
%macro PRINT_NEWLINE 0

  mov ah, 0Eh
  mov al, 10
  int 10h

  mov ah, 0Eh
  mov al, 13
  int 10h

%endmacro



; sets the cursors position
; PARAMS
; 0) int => row
; 1) int => column
; 2) int => page
%macro SET_CURSOR_POSITION 3

  mov ah, 2h 
  mov dh, %1
  mov dl, %2
  mov bh, %3
  int 10h

%endmacro


; Gets the cursors position
; PARAMS
; 0) int16 => page number
; RETURNS
; 0) DH => row
; 1) DL => column
; 2) CH => cursor start position
; 3) CL => cursor bottom line
%macro GET_CURSOR_POSITION 1

  ; since XOR is more efficient
  %if %1 == 0
    xor bh, bh
  %else
    mov bh, %1
  %endif

  mov ah, 3
  int 10h

%endmacro

; Sends an EOI (End Of Interrupt) signal to the PICs.
%macro PIC8259_SEND_EOI 1

  mov al, PIC_EOI 
  %if %1 >= 8
    out PIC_SLAVE_CMD, al
  %endif

  out PIC_MASTER_CMD, al

%endmacro

; Send a command on the PS/2 8042 micro controller
; PARAMS
;   - 0) int8 => the command code
%macro PS2_SEND_COMMAND 1

  call ps2_8042_waitInput
  ; %if %1 != al
    mov al, %1
  ; %endif
  out PS2_COMMAND_PORT, al

%endmacro

; Send a command on the PS/2 8042 micro controller, then send data on its data port.
; PARAMS
;   - 0) int8 => The command to send
;   - 1) int8 => The data to send
%macro PS2_SEND_COMMAND_DATA 2

  PS2_SEND_COMMAND %1

  call ps2_8042_waitInput
  %if %2 != al
    mov al, %2
  %endif
  out PS2_DATA_PORT, al

%endmacro

; Read data from a result of a command on the ps/2.
; Executes a commands (OUT) and then reads data into AL (IN)
; PARAMS
;   - 0) int8 => Data command
; RETURNS
;   - 0) int8 [ AL ] => The data.
%macro PS2_READ_DATA 1

  PS2_SEND_COMMAND %1

  call ps2_8042_waitOutput
  in al, PS2_DATA_PORT

%endmacro

; USE THIS CRAP ONLY FOR DEBUGGING
%macro PRINT_REGISTERS 0

  pusha
  PRINTF_M `AX: %x\n`, ax
  popa
  pusha 
  PRINTF_M `BX: %x\n`, bx
  popa
  pusha
  PRINTF_M `CX: %x\n`, cx
  popa
  pusha
  PRINTF_M `DX: %x\n`, dx
  popa
  pusha
  PRINTF_M `SI: %x\n`, si
  popa
  pusha
  PRINTF_M `DI: %x\n`, di
  popa
  pusha
  PRINTF_M `SP: %x\n`, sp
  popa
  pusha
  PRINTF_M `SS: %x\n`, ss
  popa
  pusha
  PRINTF_M `DS: %x\n`, ds
  popa
  pusha
  PRINTF_M `ES: %x\n`, es
  popa

%endmacro

%macro PRINT_STR11 1

  lea di, [%1]
  mov cx, 11
%%printAgain:
  mov al, es:[di]
  mov ah, 0Eh
  int 10h
  inc di
  loop %%printAgain

%endmacro

; Prints a string, example: PRINT_STR "Hello world!"
%macro PRINT_STR 1

  pusha                       ; Save all registers. I know pusha sucks, but its good enough for debugging
  jmp %%skipStrBuffer         ; Skip string buffer declaration 
%%strBuffer: db %1, 0         ; Declare the string, as %1 is replaced with its content

%%skipStrBuffer:
  lea si, %%strBuffer         ; Get a pointer to the first byte of the string
%%printAgain:
  cmp byte [si], 0            ; Check for null character
  je %%stopPrint              ; If null then stop printing
  mov ah, 0Eh                 ; int10h/AH-0Eh print character and advance cursor
  mov al, [si]                ; Get next character from string
  int 10h                     ; Print character from AL
  inc si                      ; Increase string pointer
  jmp %%printAgain            ; Continue printing characters

%%stopPrint:
  popa                        ; Restore all registers. (Again IK popa sucks, but its ok for debug)

%endmacro

; prints a single character
%macro PRINT_CHAR 1

  mov ah, 0Eh
%if %1 != al 
  mov al, %1
%endif
  int 10h

%endmacro

; Not the best, but good enough for debugging
%macro PRINT_INT16 1

  pusha                             ; Save all registers

  mov si, sp
  sub sp, 6                         ; Allocate 6 bytes on stack
  mov byte ss:[si], 0               ; Zero terminate the string

  %if %1 != ax
    mov ax, %1                      ; AX will be divided by 10 each time to get the last digit of the number
  %endif

  ; Each time, divibe the nunber by 10 and get the remainder. 1234 % 10 = 4 // 123 % 10 = 3 // ...... // 1 % 10 = 1 ; AX = 0
%%nextDigit:
  push ax                           ; Save AX (for some reason AX cant survive 3 instructions)
  dec si                            ; Decrement buffer pointer
  xor dx, dx                        ; Zero out division remainder
  mov bx, 10                        ; Divibe by 10 to get last digit in DL/DX
  pop ax                            ; Restore AX, for divibing it
  div bx                            ; AX /= BX // Get last digit in DL
  add dl, 48                        ; Convert to ascii
  mov ss:[si], dl                   ; Store digit in buffer
  test ax, ax                       ; If the result of the division is not zero then continue
  jnz %%nextDigit

%%printLoop:
  cmp byte ss:[si], 0               ; Check for null character, so dont print it
  je %%stopPrint                    ; If null the stop printing
  mov al, ss:[si]                   ; Get character in AL
  PRINT_CHAR al 
  inc si                            ; Increase buffer pointer
  jmp %%printLoop                   ; Continue printing

%%stopPrint:
  add sp, 6                         ; Free 6 bytes
  popa                              ; Restore registers

%endmacro

; THIS MACRO IS TEMPORARY
%macro PRINT_INT16_VGA 1

  pusha

  %if %1 != ax
    mov ax, %1
  %endif

  push es
  push gs

  mov bx, ss
  mov es, bx

  mov si, sp
  sub si, 6
  mov byte es:[si], 0

%%print_int16_vga_loop:
  mov bx, 10
  xor dx, dx
  div bx

  add dl, 48
  dec si 
  mov es:[si], dl

  test ax, ax
  jnz %%print_int16_vga_loop

  mov bx, VGA_SEGMENT
  mov gs, bx
  xor di, di
  mov ah, 00Eh

%%print_int16_vga_loopPrint:
  mov al, es:[si]
  test al, al
  jz %%print_int16_vga_end
  mov gs:[di], ax
  inc si
  add di, 2
  jmp %%print_int16_vga_loopPrint

%%print_int16_vga_end:
  pop gs
  pop es
  popa

%endmacro



%macro PRINT_HEX16 1

  pusha
  push bp
  mov bp, sp
  sub sp, 2

  mov di, sp
  mov byte ss:[di + 1], 0

  %if %1 != si
    mov si, %1
  %endif

%%printHex16_hexDigitsLoop:
  mov ax, si
  and ax, 0Fh                         ; Remove upper bytes, and leave the 4 LSBs
  cmp al, 0Ah
  jl %%printHex16_hexLetter

  add al, 37h                         ; Convert digit to ascii letter
  jmp %%printHex16_hexSkipLetter

%%printHex16_hexLetter:
  add al, 30h                         ; Convert digit to ascii number

%%printHex16_hexSkipLetter:
  mov ss:[di], al                        ; Store letter/number in buffer
  dec di
  shr si, 4                           ; Remove last hex digit from number
  test si, si
  jnz %%printHex16_hexDigitsLoop

%%printHex16_hexPrintLoop:
  inc di
  mov al, ss:[di]
  test al, al
  jz %%printHex16_end
  PRINT_CHAR al
  jmp %%printHex16_hexPrintLoop

%%printHex16_end:
  mov sp, bp
  pop bp
  popa

%endmacro

; Printf macro ( _M is for macro)
; First argument is a string, and after that are the arguemnts from printf
; EXAMPLE: PRINTF_M "Heyyyy AX is: %d hey again", AX
%macro PRINTF_M 1-*

  jmp %%skipStrBuffer           ; Skip the declaration of the string, so it wont execute thos bytes
%%strBuffer: db %1, 0           ; Declare the string bytes, and null terminate the string

%%skipStrBuffer:

  ; %0 gives the number of parameters passed to the macro.
  ; %rep is a NASM preprocessor command, which will repeate the following block of code N times.
  ; Basicaly push all the arguments from right to left, and dont push the string.
  %rep %0 - 1
    ; Rotate will rotate the macros arguments, (just like the ROR instruction)
    ; Say the arguments are 1, 2, 3, 4
    ; %rotate -1 ; ARGS: 4, 1, 2, 3     ; meaning %1 is 4
    %rotate -1
    push word %1             ; Push the currently first arguemnts (as they rotate)
  %endrep
  push %%strBuffer      ; Push the string buffer, as its the first argument for printf
  call printf           ; Call printf and print the formatted string
  add sp, %0 * 2        ; Free stack space

%endmacro


; Printf lable macro ( _LM is for lable, macro)
; First argument is a pointer to the string (null terminated), and after that are the arguemnts from printf
; EXAMPLE: PRINTF_LM str, AX  // str: db "Hello world! AX is %d.", 0
%macro PRINTF_LM 1-*

  ; %0 gives the number of parameters passed to the macro.
  ; %rep is a NASM preprocessor command, which will repeate the following block of code N times.
  ; Basicaly push all the arguments from right to left, and dont push the string.
  %rep %0 - 1
    ; Rotate will rotate the macros arguments, (just like the ROR instruction)
    ; Say the arguments are 1, 2, 3, 4
    ; %rotate -1 ; ARGS: 4, 1, 2, 3     ; meaning %1 is 4
    %rotate -1
    push %1             ; Push the currently first arguemnts (as they rotate)
  %endrep
  push %{-1:-1}      ; Push the string buffer, as its the first argument for printf
  call printf           ; Call printf and print the formatted string
  add sp, %0 * 2        ; Free stack space

%endmacro

%endif