;
; --------- [ DELETE A FILE FROM THE FILESYSTEM ] ---------
;

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/print.asm"
%include "shared/ascii.asm"

%define ERR_NOT_ENOUGH_ARGS 1

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                            ; Save stack frame

  cmp cx, 2                             ; Check arguments count, if there is a file to delete
  je .argsOk                            ; If there is an argument, dont print an error message

  PUTS_INT 100h, errInvalidUsage        ; If there is no argument / too much arguments, print an error message
  mov di, ERR_NOT_ENOUGH_ARGS           ; Set error code
  jmp main_end                          ; Exit

.argsOk:
  mov gs, ax                            ; Get a pointer to the arguments array GS:BX
  mov es, dx                            ; Segment of each argument

  mov di, gs:[bx + 2]                   ; Get the first argument string, the file path
  mov ax, INT_N_REMOVE                  ; Interrupt number for deleting a file
  int INT_F_KERNEL                      ; Delete the given file
  test ax, ax                           ; Check error code
  jz .success                           ; If there was no error, dont print an error message, and return with success

  push ax                               ; Save remove's error code
  PUTS_INT 100h, errFileDoesntExit      ; Print an error message
  pop di                                ; Restore remove's error code
  jmp main_end                          ; Exit with remove's error code

.success:
  xor di, di                            ; On success, return 0

main_end:
  mov sp, bp                            ; Restore stack frame
  mov ax, INT_N_EXIT                    ; Interrupt number for exiting
  int INT_F_KERNEL                      ; Exit


;
; --------- [ DATA SECTION ] ---------
;

errInvalidUsage:              db "[ - delete] Error, invalid usage. Correct usage: delete FILE_PATH", NEWLINE, 0
errFileDoesntExit:            db "[ - delete] Error, the given file does not exist.", NEWLINE, 0