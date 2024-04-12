bits 16

org 0h

jmp kernelMain    ; skip data and function declaration section

;
; ---------- [ FUNCTIONS DECLARATION ] ----------
;

%include "kernel/macros/macros.asm"
%include "kernel/io/io.asm"
%include "kernel/screen/screen.asm"
%include "kernel/string/string.asm"
%include "kernel/basicCommands/basicCommands.asm"
%include "kernel/filesystem/filesystem.asm"
%include "kernel/isr/isr.asm"
%include "kernel/time/time.asm"

%ifdef KBD_DRIVER
  %include "kernel/drivers/ps2_8042/ps2_8042.asm"
%endif

%include "kernel/init/init.asm"

;
; ---------- [ DATA SECTION ] ----------
;

%define COMMAND_MAX_LENGTH 80

bpbStart:
%include "bootloader/bpbStruct/bpbStruct.asm"

welcomeMsg:               db "[*] Welcome to my OS!", NEWLINE, "Enter 'help' for more info.", TAB, "hey", NEWLINE, TAB, "hey again", NEWLINE, 0
shellStr:                 db NEWLINE, "[ %s ]", NEWLINE, "|___/-=> $ ", 0
commandEntered:           times COMMAND_MAX_LENGTH db 0 
errorUnknownCmd:          db "[-] Error, unknown command ", 22h, "%s", 22h, 0
currentUserDirPath:       db '/folder/idk/'
                          times (MAX_PATH_FORMATTED_LENGTH - 1) db 0

helpMsg:                  db "[*] <OS_NAME (idk)>", NEWLINE, NEWLINE, "Commands:", NEWLINE, TAB
  db "help", TAB, "| prints this help message.", NEWLINE, TAB,
  db "clear", TAB, "| clears the screen", NEWLINE, 
  db 0

errPs2CtrlSelfTestFailed: db "[- KERNEL PANIC] Error, one of the PS/2 controller chips has failed the self-test. (Is there a keyboard?)", NEWLINE, 0
errPs2SelfTestFailed:     db "[- KERNEL PANIC] Error, the PS/2 controller has failed the self-test. (Is there a keyboard?)", NEWLINE, 0


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

; The cursors location as an index in VGA memory
; Get the X, Y (col, row) using the formula:
; row => trmIndex / 80
; col => trmIndex % 80
trmIndex:                 dw 0

; Low 4 bits are the text color, and the high 4 bits are the background color
trmColor:                 db COLOR(VGA_TXT_LIGHT_GRAY, VGA_TXT_BLACK)

helpCmd:                  db "help", 0
clearCmd:                 db "clear", 0

dbgTestTxt:               db "T15     TXT"
; buffer:                   times 512*8 db 97         ;;;;;; DEBUG
pathStf:                  db "fld/teSt.txt", 0

;
; ---------- [ KERNEL MAIN ] ----------
;

kernelMain:
  call clear

  mov ch, 6               ;
  mov cl, 7               ; Show blinking text cursor
  mov ah, 1               ;
  int 10h                 ;

  PRINTF_M "heyy %u %d", 6666, -1


  mov di, COLOR_CHR('a', VGA_TXT_DARK_BLUE, VGA_TXT_LIGHT_CYAN)
  call printChar
  
  INIT_KERNEL             ; Initialize kernel.
  
  lea si, [welcomeMsg]
  mov di, COLOR(VGA_TXT_DARK_CYAN, VGA_TXT_YELLOW)
  call printStr


  PRINT_NEWLINE
  ;;;;;;;;; DEBUG
  ; lea di, [buffer]
  ; lea si, [pathStf]
  ; call getFullPath

  ; lea di, [buffer]
  ; call printStr

kernel_readCommandsLoop:
  PRINT_NEWLINE                     ;
  PRINTF_LM shellStr, currentUserDirPath   ; Go down a line and print the shell
  ; lea si, [shellStr]
  ; mov di, [trmColor]
  ; call printStr

%ifdef GET_ASCII_CODES
  xor ah, ah
  int 16h
  xor ah, ah
  PRINT_HEX16 ax
  PRINT_NEWLINE
%endif

%ifndef GET_ASCII_CODES
  lea di, [commandEntered]          ;
  mov si, COMMAND_MAX_LENGTH        ; Read the command to commandEntered
  call read                         ; 

  test ax, ax                       ; if zero bytes were read then just show a new shell
  jz kernel_readCommandsLoop        ;

  PRINT_NEWLINE

  ;;;;; FOR DEBUG
  ; lea di, dbgTestTxt
  ; lea bx, buffer
  ; call readFile
  ; test ax, ax
  ; jnz kernel_dontPrintFileContent

  ; lea di, buffer                ;;;;;;;; FOR DEBUG
  ; call printStr
  
  kernel_dontPrintFileContent:
  PRINT_NEWLINE

  ; compares two strings, and if their equal then jump to given lable
  CMDCMP_JUMP_EQUAL commandEntered, helpCmd, kernel_printHelp
  CMDCMP_JUMP_EQUAL commandEntered, clearCmd, kernel_clear

  PRINTF_LM errorUnknownCmd, commandEntered
%endif


  jmp kernel_readCommandsLoop       ; continue reading commands

  jmp $                             ; jump to <this> location. should not get there.