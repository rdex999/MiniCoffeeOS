;
; ---------- [ BASIC MACROS ] ----------
;

%ifndef MACROS_ASM
%define MACROS_ASM

%include "shared/errorCodes.asm"
%include "shared/kbdKeyCodes.asm"
%include "shared/colors.asm"
%include "shared/interrupts.asm"
%include "shared/ascii.asm"
%include "shared/filesystem.asm"
%include "shared/cmd.asm"
%include "shared/process.asm"

%define TXT_TAB_SIZE 4

%define KERNEL_SEGMENT 7E0h

%define OSCILLATOR_FREQUENCY 1193182
%define PIT_CHANNEL0_IRQ_PER_SEC 18000
%define SYS_CLOCK_UNTIL_MS_RELOAD (PIT_CHANNEL0_IRQ_PER_SEC / 1000)

; %define IO_NEWLINE_SPACES

%define KBD_DRIVER

%define KBD_HIGH_DELAY 500
%define KBD_LOW_DELAY 10
; %define GET_ASCII_CODES

; 2*20*512  // 2 FATs, 20 sectors per fat, 512 bytes per sector
%define TOTAL_FAT_SIZE 20480

; 512 * 32 = 16384   // 512 => root directory entries // 32 bytes per entry
%define ROOT_DIRECTORY_SIZE 16384

; Each process has exactly one segment, and is loaded on offset 100h
; struct processDesc {
;   uint16_t segment;
; }
%define PROCESS_DESC_LEN 10

%define PROCESS_DESC_FLAGS8 0
%define PROCESS_DESC_EXIT_CODE8 (PROCESS_DESC_FLAGS8 + 1)
%define PROCESS_DESC_SLEEP_MS16 (PROCESS_DESC_EXIT_CODE8 + 1)
%define PROCESS_DESC_REG_AX16 (PROCESS_DESC_SLEEP_MS16 + 2)
%define PROCESS_DESC_REG_BX16 (PROCESS_DESC_REG_AX16 + 2)
%define PROCESS_DESC_REG_CX16 (PROCESS_DESC_REG_BX16 + 2)
%define PROCESS_DESC_REG_DX16 (PROCESS_DESC_REG_CX16 + 2)
%define PROCESS_DESC_REG_SI16 (PROCESS_DESC_REG_DX16 + 2)
%define PROCESS_DESC_REG_DI16 (PROCESS_DESC_REG_SI16 + 2)
%define PROCESS_DESC_REG_SP16 (PROCESS_DESC_REG_DI16 + 2)
%define PROCESS_DESC_REG_BP16 (PROCESS_DESC_REG_SP16 + 2)
%define PROCESS_DESC_REG_IP16 (PROCESS_DESC_REG_BP16 + 2)
%define PROCESS_DESC_REG_DS16 (PROCESS_DESC_REG_IP16 + 2)
%define PROCESS_DESC_REG_ES16 (PROCESS_DESC_REG_DS16 + 2)
%define PROCESS_DESC_REG_FS16 (PROCESS_DESC_REG_ES16 + 2)
%define PROCESS_DESC_REG_GS16 (PROCESS_DESC_REG_FS16 + 2)
%define PROCESS_DESC_REG_CS16 (PROCESS_DESC_REG_GS16 + 2)
%define PROCESS_DESC_REG_SS16 (PROCESS_DESC_REG_CS16 + 2)
%define PROCESS_DESC_REG_FLAGS16 (PROCESS_DESC_REG_SS16 + 2)

%define PROCESS_DESC_SIZEOF (PROCESS_DESC_REG_FLAGS16 + 2)

%define PROCESS_DESC_F_ALIVE 0000_0001b

; ; struct heapChunk {
; ;   uint16_t segment;
; ;   uint16_t offset;
; ;   uint16_t size;
; ; };

; ; The amount heapChunk in the heapFreeChunks array
; %define HEAP_CHUNKS_LEN 32
; %define HEAP_END_SEG 9FC0h

; %define HEAP_MAX_CHUNK_SIZE 0FFF0h

; ; ALC stands for "allocated"

; ; The offset of the segment in the heap allocated chunk struct
; %define HEAP_CHUNK_SEG16 0
; ; The offset of the offset in the heap allocated chunk struct
; %define HEAP_CHUNK_OFF16 (HEAP_CHUNK_SEG16 + 2)
; ; The size of the chunk, in the heap allocated chunk struct
; %define HEAP_CHUNK_SIZE16 (HEAP_CHUNK_OFF16 + 2)
; ; Flags for the chunk
; %define HEAP_CHUNK_FLAGS8 (HEAP_CHUNK_SIZE16 + 2)

; ; The size of the heapChunk struct sizeof(heapChunk)
; %define HEAP_SIZEOF_HCHUNK (HEAP_CHUNK_FLAGS8 + 1)

; ; Flags values for heapChunk

; ; If owned then 1, if free then 0
; %define HEAP_CHUNK_F_OWNED 0000_0001b
; %define HEAP_CHUNK_F_ZERO 0000_00010b

%define EOF 0FFFFh

; To check if the file is open (is openFiles) check if the first cluster number is 0.
; If the first cluster number is zero then the descriptor is empty

; struct file_open {
;   uint8_t access;
;   uint16_t position;
;   struct entryFAT;    // 32 bytes
; };

; The length of the openFiles array
%define FILE_OPEN_LEN 10
; Access for the file
%define FILE_OPEN_ACCESS8 0
; The current read position in a file
%define FILE_OPEN_POS16 (FILE_OPEN_ACCESS8 + 1)
; The FAT file entries LBA address
%define FILE_OPEN_ENTRY_LBA16 (FILE_OPEN_POS16 + 2)
; The offset in the LBA for the FAT entry
%define FILE_OPEN_ENTRY_OFFSET16 (FILE_OPEN_ENTRY_LBA16 + 2)
; The FAT entry of the file
%define FILE_OPEN_ENTRY256 (FILE_OPEN_ENTRY_OFFSET16 + 2)
; sizeof(openFile)
%define FILE_OPEN_SIZEOF (FILE_OPEN_ENTRY256 + 32)

%define FAT_CLUSTER_INVALID 0FFF7h
%define FAT_CLUSTER_END 0FFFFh


%define VGA_SEGMENT 0B800h

%define VGA_CRTC_CMD 3D4h
%define VGA_CRTC_DATA 3D5h

%define VGA_CRTC_CURSOR_LOC_HIGH 0Eh
%define VGA_CRTC_CURSOR_LOC_LOW 0Fh
%define VGA_CRTC_CURSOR_START 0Ah
%define VGA_CRTC_CURSOR_END 0Bh

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
%define INT_PIT_CHANNEL0 (0 + 8)
%define INT_CMOS_UPDATE (8 + 8)
%define INT_INVALID_OPCODE 6
%define INT_DOUBLE_FAULT 8
%define INT_STACK_SEG_FAULT 0Ch

%define IRQ_KEYBOARD 1
%define IRQ_PIT_CHANNEL0 0
%define IRQ_RTC 8

; 1 - NMI is disabled
%define NMI_STATUS_BIT_CMOS 1000_0000b
%define CMOS_ACCESS_REG_PORT 70h
%define CMOS_DATA_REG_PORT 71h

%define KBD_SCANCODE_NORM_BREAK 0F0h
%define KBD_SCANCODE_SPECIAL 0E0h
%define GET_CURSOR_INDEX(row, col) (80 * row + col)
%define NORM_SCREEN_START_IDX (GET_CURSOR_INDEX(1, 0))

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
; PARAMS
;   - 0) Flag, if 1, the macro asumes that ES is set to the kernel segment. 
;        If 0 it will save the old value, print the character and restore it to the old value
%macro PRINT_NEWLINE 1

  %if %1 == 0
    push es
    mov bx, KERNEL_SEGMENT
    mov es, bx
  %endif
  mov ah, es:[trmColor]
  PRINT_CHAR NEWLINE, ah
  %if %1 == 0
    pop es
  %endif

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

; Get the state of a key on the keyboard (pressed, or not pressed)
; PARAMS
;   - 0) The key (keycode)
; RETURNS
;   - Zero flag set if the key is being pressed, cleared otherwise (JE - key not pressed, JNE - key being pressed)
%macro GET_KEY_STATE 1

  cmp byte ds:[kbdKeys - 1 + %1], 0

%endmacro

; Gets the current system time
; Takes to parameters
; RETURNS
;   - 0) CX:DX    => Number of clock ticks since midnight (about 18 per second)
;   - 1) AL       => Midnight counter, advanced each time midnight passes
%macro GET_SYS_TIME 0

  xor ah, ah
  int 1Ah

%endmacro

; Sends an EOI (End Of Interrupt) signal to the PICs.
; PARAMS
;   - 0) The IRQ
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
%macro PRINT_REGS 0

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

; Prints a character at the cursor position
; PARAMS
;   0) The character
;   1) The color (optional)
%macro PRINT_CHAR 1-2

  ; If there two arguments, then the first one is the character and the second one is the color
  %if %0 == 2
    %if %1 != al  
      mov al, %1
    %endif

    %if %2 != ah
      mov ah, %2
    %endif
    mov di, ax
  %else
  ; If there is only one arguments, then it must be a 16 bit register/value. 
  ; We assume that the character is in the low 8 bits the color is in the high 8 bits.
    %if %1 != di
      mov di, %1
    %endif
  %endif
  call printChar              ; Print the character with the color at DI(high8) and the character at DI(low8)


%endmacro


; Not the best, but good enough for debugging
%macro PRINT_INT16 1

  pusha                             ; Save all registers
  push es
  mov bx, KERNEL_SEGMENT
  mov es, bx

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
  mov ah, es:[trmColor]
  PRINT_CHAR al, ah
  inc si                            ; Increase buffer pointer
  jmp %%printLoop                   ; Continue printing

%%stopPrint:
  add sp, 6                         ; Free 6 bytes
  pop es 
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

; PARAMS
;   - 0) The function to call (a lable)
;   - 1..) The registers to save
%macro SAVE_BEFORE_CALL 1-*

  %rep %0 - 1
    %rotate 1
    push %1
  %endrep
  
  %rotate 1 
  call %1

  %rep %0 - 1
    %rotate -1
    pop %1
  %endrep

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
  %if %0 * 2 != 0
    add sp, %0 * 2        ; Free stack space
  %endif

%endmacro

%macro PANIC_LM 1-*

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

  mov di, 5 * 1000
  call sleep

%endmacro

%endif