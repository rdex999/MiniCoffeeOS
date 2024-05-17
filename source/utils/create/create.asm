;
; --------- [ CREATE A FILE ] --------
;

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/filesystem.asm"
%include "shared/print.asm"
%include "shared/ascii.asm"

%define ERR_NOT_ENOUGH_ARGS 1
%define ERR_PATH_DOESNT_EXIST 2
%define ERR_FILE_ALREADY_EXISTS 3

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                              ; Save stack frame

  cmp cx, 2                               ; Check if there is an argument, a file to create
  je .argsOk                              ; If there is, dont print an error message

  PUTS_INT 100h, errInvalidUsage          ; If there is no argument \ too much arguments print an error message
  mov di, ERR_NOT_ENOUGH_ARGS             ; Set error code
  jmp main_end                            ; Exit

.argsOk:
  mov gs, ax                              ; Get a pointer to the arguments array, GS:BX
  mov es, dx                              ; Segment of each argument

  ; Check if the given file exists
  mov di, gs:[bx + 2]                     ; Get a pointer to the first argument, the file to create
  mov si, FILE_OPEN_ACCESS_READ           ; Try to read the file, so request read access
  mov ax, INT_N_FOPEN                     ; Interrupt number for opening a file
  int INT_F_KERNEL                        ; Try to open the file
  test ax, ax                             ; Check if the file handle is null
  jz .fileDoesntExist                     ; If it is, then the file doesnt exist, which is good because we want to create it

  mov di, ax                              ; If the handle is not null, close the file. Get the handle in DI
  mov ax, INT_N_FCLOSE                    ; Interrupt number for closing a file
  int INT_F_KERNEL                        ; Interrupt number for closing a file

  PUTS_INT 100h, errFileAlreadyExists     ; Print an error message because the file exists
  mov di, ERR_FILE_ALREADY_EXISTS         ; Set error code
  jmp main_end                            ; Exit

.fileDoesntExist:
  ; Get here if the file doesnt exist (which is good)
  mov ax, INT_N_FOPEN                     ; interrupt number for openning a file
  mov si, FILE_OPEN_ACCESS_WRITE          ; Need to create to file, so request write access
  int INT_F_KERNEL                        ; Create the file
  test ax, ax                             ; Check if the file handle is null
  jnz .fileOpened                         ; If its not null, then just close the file and exit with success

  PUTS_INT 100h, errPathDoesntExist       ; If null, print an error message
  mov di, ERR_PATH_DOESNT_EXIST           ; Set exit code
  jmp main_end                            ; Exit

.fileOpened:
  mov di, ax                              ; If the file handle is not null, get the handle in DI
  mov ax, INT_N_FCLOSE                    ; Interrupt number for closing a file
  int INT_F_KERNEL                        ; Close the file

  mov di, ax                              ; Exit with fclose's exit code
main_end:
  mov sp, bp                              ; Restore stack frame
  mov ax, INT_N_EXIT                      ; Interrupt number for exiting
  int INT_F_KERNEL                        ; Exit

;
; -------- [ DATA SEGMENT ] --------
;

errInvalidUsage:            db "[ - create] Error, invalid usage. Correct usage: create FILE_PATH", NEWLINE, 0
errPathDoesntExist:         db "[ - create] Error, the given path does not exist.", NEWLINE, 0
errFileAlreadyExists:       db "[ - create] Error, the given file already exists.", NEWLINE, 0