bits 16

org 0h

jmp kernelMain    ; skip data and function declaration section

;
; ---------- [ FUNCTIONS DECLARATION ] ----------
;

%include "source/kernel/io/io.asm"
%include "source/kernel/screen/screen.asm"
%include "source/kernel/string/string.asm"
%include "source/kernel/basicCommands/basicCommands.asm"
%include "source/kernel/filesystem/filesystem.asm"
%include "source/kernel/macros/macros.asm"
%include "source/kernel/init/init.asm"

;
; ---------- [ DATA SECTION ] ----------
;

%define COMMAND_MAX_LENGTH 80

bpbStart:
%include "source/bootloader/bpbStruct/bpbStruct.asm"

welcomeMsg:               db "[*] Welcome to my OS!", NEWLINE, "Enter 'help' for more info.", NEWLINE, 0
shellStr:                 db NEWLINE, "[ PC@USER - PATH ]", NEWLINE, "|___/-=> $ ", 0
commandEntered:           times COMMAND_MAX_LENGTH db 0 
errorUnknownCmd:          db "[-] Error, unknown command ", 22h, 0

; I will change this method of allocating memory in the future, I dont like this at all.
FATs:                     times TOTAL_FAT_SIZE db 0           ; Allocate space for storing FATs

helpMsg:                  db "[*] <OS_NAME (idk)>", NEWLINE, NEWLINE, "Commands:", NEWLINE, TAB
  db "help", TAB, "| prints this help message.", NEWLINE, TAB,
  db "clear", TAB, "| clears the screen", NEWLINE, 
  db 0

helpCmd:                  db "help", 0
clearCmd:                 db "clear", 0

dbgTestTxt:               db "TEST    TXT"
buffer:                   times 3000 db 0

;
; ---------- [ KERNEL MAIN ] ----------
;

kernelMain:

  call clear
 
  mov ch, 6               ;
  mov cl, 7               ; Show blinking text cursor
  mov ah, 1               ;
  int 10h                 ;

  INIT_KERNEL             ; Initialize kernel.

  lea di, [welcomeMsg] 
  call printStr

kernel_readCommandsLoop:
 
  PRINT_NEWLINE                     ;
  lea di, shellStr                  ; Go down a line and print the shell
  call printStr                     ; 

  lea di, [commandEntered]          ;
  mov si, COMMAND_MAX_LENGTH        ; Read the command to commandEntered
  call read                         ; 

  test ax, ax                       ; if zero bytes were read then just show a new shell
  jz kernel_readCommandsLoop        ;

  PRINT_NEWLINE
  PRINT_NEWLINE

  ;;;;; FOR DEBUG
  lea di, dbgTestTxt
  lea bx, buffer
  call readFile
  lea di, buffer                ;;;;;;;; FOR DEBUG
  call printStr
  
  PRINT_NEWLINE

  ; compares two strings, and if their equal then jump to given lable
  CMDCMP_JUMP_EQUAL commandEntered, helpCmd, kernel_printHelp
  CMDCMP_JUMP_EQUAL commandEntered, clearCmd, kernel_clear

  lea di, [errorUnknownCmd]         ; if none of the commands above then print an error message with the entered command
  call printStr
  lea di, [commandEntered]
  call printStr
  PRINT_CHAR 22h                    ; 22h is ascii for '"' 

  jmp kernel_readCommandsLoop       ; continue reading commands

  jmp $                             ; jump to <this> location. should not get there.