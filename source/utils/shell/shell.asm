;
; --------- [ HANDLE USER COMMANDS ] ----------
;

%include "shared/interrupts.asm"
%include "shared/ascii.asm"
%include "shared/filesystem.asm"
%include "shared/colors.asm"
%include "shared/print.asm"
%include "shared/cmd.asm"
%include "shared/process.asm"

org PROCESS_LOAD_OFFSET

main:
  push bp
  mov bp, sp

  mov ds, ax
  mov si, bx
  
  push word ds:[si + 2] 
  mov ds, ds:[si]
  pop si
  
  mov di, 100h
  mov ax, INT_N_PUTS
  int INT_F_KERNEL

  mov bx, es
  mov ds, bx


readCommandsLoop:
  ; We want to first get the current directory that the user is in, and then print the shell with the directory
  lea di, userDir                                   ; Set the destination, where to write the data to
  mov ax, INT_N_GET_USER_PATH                       ; Interrupt number for getting the user directory
  int INT_F_KERNEL                                  ; Get the current user directory

  ; Print the shell with the user directory
  PRINTF_INT_LM shellStr, userDir

  ; Wait for command input (wait for a string)
  lea di, enteredCommand                            ; Set the destination, where to store the command in
  mov si, MAX_COMMAND_LENGTH                        ; Set the maximum amount of characters to read
  mov ax, INT_N_WAIT_INPUT                          ; Interrupt number for reading a string
  int INT_F_KERNEL                                  ; Read a string from the keyboard into the specified buffer

  mov di, 100h
  mov si, NEWLINE
  mov ax, INT_N_PUTCHAR
  int INT_F_KERNEL

  lea di, enteredCommand
  mov ax, INT_N_SYSTEM
  int INT_F_KERNEL

  jmp readCommandsLoop


main_end:
  mov sp, bp
  pop bp

  mov ax, INT_N_EXIT
  int INT_F_KERNEL



;
; --------- [ DATA SECTION ] ---------
;

helpMsg:                  
  db "---< Mini Coffee OS >---", NEWLINE, NEWLINE, "Commands:", NEWLINE, TAB
  db "help", TAB, "| prints this help message.", NEWLINE, TAB,
  db "clear", TAB, "| clears the screen", NEWLINE, 
  db 0


userDir:              times MAX_PATH_FORMATTED_LENGTH db 0

shellStr:             db NEWLINE
                      db "[ %s ]", NEWLINE
                      db "|___/-=> $ ", 0

enteredCommand:       times MAX_COMMAND_LENGTH db 0
stack: db "ss: 0x%X", NEWLINE, "sp: 0x%X", NEWLINE, 0