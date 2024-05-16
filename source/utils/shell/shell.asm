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
  mov bp, sp                                        ; Save stack frame

readCommandsLoop:
  ; We want to first get the current directory that the user is in, and then print the shell with the directory
  lea di, userDir                                   ; Set the destination, where to write the data to
  mov ax, INT_N_GET_USER_PATH                       ; Interrupt number for getting the user directory
  int INT_F_KERNEL                                  ; Get the current user directory
  
  PRINTF_INT_LM shellHighHalf, userDir              ; Print the high half of the shell, which has the current user directory in it

  cmp byte [lastReadCnt], 0                         ; Check if the amount of bytes read in the last command is 0
  jne .printExitStatus                              ; If its not 0, then a command has actualy been issued, so get the last exit code and print a symbol for it

  mov di, VGA_TXT_LIGHT_CYAN                        ; If there was no command in the last read, print a light blue star, indicating a natural exit code (for no command)
  mov si, '*'                                       ; Character to print
  jmp .afterSetPrintData                            ; Print the character and continue 

.printExitStatus:
  mov ax, INT_N_GET_EXIT_CODE                       ; Interrupt number for getting the last exit code
  int INT_F_KERNEL                                  ; Get the last exit code

  test al, al                                       ; Check if its zero
  jz .printGreen                                    ; If its zero, then the last command exited successfully. Print a green +

  mov di, VGA_TXT_RED                               ; If its not 0, then the last command exited with and error. Print a red -
  mov si, '-'                                       ; Character to print
  jmp .afterSetPrintData                            ; Print the character and continue

.printGreen:
  mov di, VGA_TXT_LIGHT_GREEN                       ; If the last exit code is zero, then the last command exited successfully. Print a green +
  mov si, '+'                                       ; Character to print

.afterSetPrintData:
  mov ax, INT_N_PUTCHAR                             ; Interrupt number for printing a character
  int INT_F_KERNEL                                  ; Print the character

  PUTS_INT 100h, shellLowHalf                       ; Print the lower half of the shell

  ; Wait for command input (wait for a string)
  lea di, enteredCommand                            ; Set the destination, where to store the command in
  mov si, MAX_COMMAND_LENGTH                        ; Set the maximum amount of characters to read
  mov ax, INT_N_WAIT_INPUT                          ; Interrupt number for reading a string
  int INT_F_KERNEL                                  ; Read a string from the keyboard into the specified buffer

  mov [lastReadCnt], ax                             ; Update the last read count to the amount of bytes just read

  PRINT_CHAR_INT 100h, NEWLINE                      ; Print a newline

  lea di, enteredCommand                            ; Get a pointer to the entered command
  mov ax, INT_N_SYSTEM                              ; Interrupt number for executing a terminal command
  int INT_F_KERNEL                                  ; Execute the requested command

  jmp readCommandsLoop                              ; Continue reading commands and executing them

main_end:
  mov sp, bp                                        ; Restore stack frame

  xor di, di                                        ; Zero out exit code
  mov ax, INT_N_EXIT                                ; Interrupt number for exiting
  int INT_F_KERNEL                                  ; End this process



;
; --------- [ DATA SECTION ] ---------
;

helpMsg:                  
  db "---< Mini Coffee OS >---", NEWLINE, NEWLINE, "Commands:", NEWLINE, TAB
  db "help", TAB, "| prints this help message.", NEWLINE, TAB,
  db "clear", TAB, "| clears the screen", NEWLINE, 
  db 0

shellHighHalf:        db NEWLINE, "[ %s ] | ", 0

shellLowHalf:         db NEWLINE, "|___/-=> $ ", 0

lastReadCnt:          db 1


userDir:              times MAX_PATH_FORMATTED_LENGTH db 0
enteredCommand:       times MAX_COMMAND_LENGTH db 0