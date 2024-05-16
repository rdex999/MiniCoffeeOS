;
; ---------- [ CHANGE THE CURRENT USER DIRECTORY TO ANOTHER ] ----------
;

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/print.asm"
%include "shared/colors.asm"
%include "shared/ascii.asm"
%include "shared/filesystem.asm"

%define ERR_NOT_ENOUGH_ARGS 1
%define ERR_PATH_DOESNT_EXIST 2

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                                    ; Save stack frame

  cmp cx, 2                                     ; Check if the argument count is currect (that there is one argument, the new directory)
  je .argsOk                                    ; If its correct, dont print an error message

  PUTS_INT 100h, errNotEnoughArgs               ; If not correct, print an error message
  mov di, ERR_NOT_ENOUGH_ARGS                   ; Set exit code
  jmp main_end                                  ; Exit

.argsOk:
  mov gs, ax                                    ; Get a pointer to the arguments array
  mov es, dx                                    ; Segment of each argument, ES
  mov di, gs:[bx + 2]                           ; Get a pointer to the first argument, the requested directory
  mov ax, INT_N_SET_USER_PATH                   ; Interrupt number for setting the current user directory
  int INT_F_KERNEL                              ; Try to set the current user directory to the given path
  test ax, ax                                   ; Check error code
  jz .pathSet                                   ; If there is no error, dont print an error message

  PUTS_INT 100h, errPathDoesntExist             ; If there was an error, print an error message
  mov di, ERR_PATH_DOESNT_EXIST                 ; Set exit code
  jmp main_end                                  ; Exit

.pathSet:

  xor di, di                                    ; Exit with 0 if there was no error
main_end:
  mov sp, bp                                    ; Restore stack frame
  mov ax, INT_N_EXIT                            ; Interrupt number for exiting
  int INT_F_KERNEL                              ; Exit from the process

;
; ---------- [ DATA SEGMENT ] ----------
;

errNotEnoughArgs:             db "[ - cd] Error, invalid usage. Correct usage: cd PATH", NEWLINE, 0
errPathDoesntExist:           db "[ - cd] Error, the given path does not exist.", NEWLINE, 0