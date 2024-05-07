bits 16

org 0h

jmp kernelMain    ; skip data and function declaration section

;
; ---------- [ MACROS DECLARATION ] ----------
;

%include "kernel/macros/macros.asm"

%include "kernel/init/init.asm"

;
; ---------- [ DATA SECTION ] ----------
;

%define COMMAND_MAX_LENGTH 80

bpbStart:
%include "bootloader/bpbStruct/bpbStruct.asm"

welcomeMsg:               db "[*] Welcome to MiniCoffeeOS!", NEWLINE, "Enter 'help' for more info.", NEWLINE, 0
currentUserDirPath:       db '/'
                          times (MAX_PATH_FORMATTED_LENGTH - 1) db 0

helpMsg:                  db "---< Mini Coffee OS >---", NEWLINE, NEWLINE, "Commands:", NEWLINE, TAB
  db "help", TAB, "| prints this help message.", NEWLINE, TAB,
  db "clear", TAB, "| clears the screen", NEWLINE, 
  db 0

errPs2CtrlSelfTestFailed: db "[- KERNEL PANIC] Error, one of the PS/2 controller chips has failed the self-test. (Is there a keyboard?)", NEWLINE, 0
errPs2SelfTestFailed:     db "[- KERNEL PANIC] Error, the PS/2 controller has failed the self-test. (Is there a keyboard?)", NEWLINE, 0
printf_errorFormat: db "[ - printf ]: Error, invalid formatting option.", NEWLINE, 0

%ifdef KBD_DRIVER
  kbdKeycodes:
    %include "kernel/drivers/ps2_8042/kbdScanCodes.asm"

  kbdExtendedKeycodes:
    %include "kernel/drivers/ps2_8042/kbdExtendedScanCodes.asm"

  kbdAsciiCodes:
    %include "kernel/drivers/ps2_8042/kbdAsciiCodes.asm"

  kbdAsciiCapCodes:
    %include "kernel/drivers/ps2_8042/kbdAsciiCapsCodes.asm"

  ; Highest keycode is 84
  kbdKeys:                times 104 db 0  ; An array of booleans, which each index is for a keycode. if(kbdKeys[keycode - 1]) { printf("key is pressed"); }

  kbdCurrentKeycode:      db 0            ; The current key that is pressed (if any). Keycode 0 means no key was pressed
  kbdSkipForKey:          db 0            ; Because after a key is released the keyboard sends the same key again. 
                                          ; This variable is used to indicate whether to skip a key event or not. 
                                          ; (This one is used on key codes)
  kbdIsFirst:             db 0
  kbdSkipForScanExt:      db 0            ; The current scan code to skip, same reason as the variable above,
                                          ; but this one is used with scan codes, and only for extended scan codes (The bytes after E0)
%endif

; Low 4 bits are the text color, and the high 4 bits are the background color
trmColor:                 db COLOR(VGA_TXT_WHITE, VGA_TXT_BLACK)

; heapChunks:               times (HEAP_CHUNKS_LEN * HEAP_SIZEOF_HCHUNK) db 0
; processes:                times 

; For the system clock
sysClock_milliseconds:    dw 0
sysClock_seconds:         db 0
sysClock_minutes:         db 0
sysClock_hours:           db 0
sysClock_weekDay:         db 0
sysClock_day:             db 0
sysClock_month:           db 0
sysClock_year:            db 0

; Day-Month-Year Hour:Minute:Second
sysClock_onScreenTime:    db "20%u-%u-%u  %u:%u:%u", 0
sysClock_20spaces:        times 20 db ' '

openFiles:                times (FILE_OPEN_LEN * FILE_OPEN_SIZEOF) db 0

processes:                times (PROCESS_DESC_LEN * PROCESS_DESC_SIZEOF) db 0

shellExec:  db "/bin/shell", 0

;
; ---------- [ KERNEL MAIN ] ----------
;

kernelMain:
  INIT_KERNEL             ; Initialize kernel.

  lea si, [welcomeMsg]
  mov di, COLOR(VGA_TXT_LIGHT_CYAN, VGA_TXT_BLACK)
  call printStr

;   lea di, shellExec
;   xor si, si
;   call createProcess

;   PRINTF_M `createProcess returned %u\n`, ax

;   lea di, shellExec
;   xor si, si
;   call createProcess

;   PRINTF_M `createProcess returned %u\n`, ax

;   lea di, shellExec
;   xor si, si
;   call createProcess

;   PRINTF_M `createProcess returned %u\n`, ax


;   lea si, processes
;   mov cx, PROCESS_DESC_LEN
; .printNext:
;   push si
;   push cx
;   mov ax, ds:[si]
;   PRINTF_M `segment 0x%x\n`, ax
;   pop cx
;   pop si
;   add si, PROCESS_DESC_SIZEOF
;   loop .printNext



.halt:
  ; cli
  hlt
  jmp .halt                             ; jump to <this> location. should not get there.


;
; ---------- [ FUNCITONS DECLARATIONS ] ----------
;

%include "kernel/io/io.asm"
%include "kernel/string/string.asm"
; %include "kernel/trmCommands/trmCommands.asm"
%include "kernel/filesystem/filesystem.asm"
%include "kernel/isr/isr.asm"
%include "kernel/time/time.asm"
%include "kernel/drivers/vga/vga.asm"
%include "kernel/memory/memory.asm"
%include "kernel/process/process.asm"

%ifdef KBD_DRIVER
  %include "kernel/drivers/ps2_8042/ps2_8042.asm"
%endif
kernelEnd: