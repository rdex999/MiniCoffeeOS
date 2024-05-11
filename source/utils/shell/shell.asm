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

readCommandsLoop:
  ; We want to first get the current directory that the user is in, and then print the shell with the directory
  lea di, userDir                                   ; Set the destination, where to write the data to
  mov ax, INT_N_GET_USER_PATH                       ; Interrupt number for getting the user directory
  int INT_F_KERNEL                                  ; Get the current user directory
  
  PRINTF_INT_LM shellHighHalf, userDir

  mov ax, INT_N_GET_EXIT_CODE
  int INT_F_KERNEL

  test al, al
  jz .printGreen

  mov di, VGA_TXT_RED
  mov si, '-'
  jmp .afterSetPrintData

.printGreen:
  mov di, VGA_TXT_LIGHT_GREEN
  mov si, '+'

.afterSetPrintData:
  mov ax, INT_N_PUTCHAR
  int INT_F_KERNEL

  PUTS_INT 100h, shellLowHalf

  ; Wait for command input (wait for a string)
  lea di, enteredCommand                            ; Set the destination, where to store the command in
  mov si, MAX_COMMAND_LENGTH                        ; Set the maximum amount of characters to read
  mov ax, INT_N_WAIT_INPUT                          ; Interrupt number for reading a string
  int INT_F_KERNEL                                  ; Read a string from the keyboard into the specified buffer

  PRINT_CHAR_INT 100h, NEWLINE

  lea di, enteredCommand
  mov ax, INT_N_SYSTEM
  int INT_F_KERNEL

  jmp readCommandsLoop

main_end:
  mov sp, bp
  pop bp

  xor di, di
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

shellHighHalf:        db NEWLINE, "[ %s ] | ", 0
shellLowHalf:           db NEWLINE, "|___/-=> $ ", 0


enteredCommand:       times MAX_COMMAND_LENGTH db 0