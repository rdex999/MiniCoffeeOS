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
%include "source/kernel/macros/macros.asm"

;
; ---------- [ DATA SECTION ] ----------
;

%define COMMAND_MAX_LENGTH 65

%define NEWLINE 10, 13
%define TAB 0Bh

welcomeMsg:         db "[*] Welcome to my OS!", NEWLINE, "Enter 'help' for more info.", NEWLINE, 0
shellStr:           db NEWLINE, "[ PC@USER - PATH ]", NEWLINE, "|___/-=> $ ", 0
commandEntered:     times COMMAND_MAX_LENGTH db 0 
errorUnknownCmd:    db "[-] Error, unknown command ", 22h, 0

helpMsg:            db "[*] <OS_NAME (idk)>", NEWLINE, NEWLINE, "Commands:", NEWLINE, TAB
  db "help", TAB, "| prints this help message.", NEWLINE, TAB,
  db "clear", TAB, "| clears the screen", NEWLINE, 
  db 0

helpCmd:            db "help", 0
clearCmd:           db "clear", 0

;
; ---------- [ KERNEL MAIN ] ----------
;

kernelMain:

  ;mov ax, 0800h
  ;mov ds, ax      ; set data segment start at 0800h
 
  call clear
 
  mov ch, 6   ;
  mov cl, 7   ; Show blinking text cursor
  mov ah, 1   ;
  int 10h     ;  
 
  lea di, [welcomeMsg] 
  call printStr

kernel_readCommandsLoop:
 
  PRINT_NEWLINE         ;
  lea di, shellStr    ; Go down a line and print the shell
  call printStr         ; 

  lea di, [commandEntered]    ;
  mov si, COMMAND_MAX_LENGTH  ; Read the command to commandEntered
  call read                   ; 

  test ax, ax                   ; if zero bytes were read then just show a new shell
  jz kernel_readCommandsLoop    ;

  PRINT_NEWLINE

  ; compares two strings, and if their equal then jump to given lable
  CMDCMP_JUMP_EQUAL commandEntered, helpCmd, kernel_printHelp
  CMDCMP_JUMP_EQUAL commandEntered, clearCmd, kernel_clear


  lea di, [errorUnknownCmd]   ; if none of the commands above then print an error message with the entered command
  call printStr
  lea di, [commandEntered]
  call printStr
  PRINT_CHAR 22h            ; 22h is ascii for '"' 

  jmp kernel_readCommandsLoop   ; continue reading commands

  jmp $     ; jump to <this> location. should not get there.
