;
; --------- [ PRINT THE FILES BYTES AS ASCII CHARACTERS ] ----------
;

%ifndef TEXT_ASM
%define TEXT_ASM

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/ascii.asm"
%include "shared/print.asm"
%include "shared/filesystem.asm"

%define ERR_NOT_ENOUGH_ARGS 1
%define ERR_FILE_DOESNT_EXIST 2

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                              ; Save stack frame
  sub sp, 6                               ; Allocate space for the arguments pointers

  add bx, 2                               ; Increase arguments array pointer so it points to the second argument (the one after the command)

  mov [bp - 2], ax                        ; Store arguments array segment
  mov [bp - 4], bx                        ; Store arguments array offset
  mov [bp - 6], dx                        ; Store segment of each argument

  cmp cx, 1                               ; Check if the amount of arguments is less than 1
  ja .argsOk                              ; If its above 1, dont print an error message

  PUTS_INT 100h, errNotEnoughArgs         ; If its 1, (which means, no actual arguments) print an error message.
  mov di, ERR_NOT_ENOUGH_ARGS             ; Set exit code to the not enough args code
  jmp main_end                            ; Exit

.argsOk:
  mov gs, [bp - 2]                        ; Get arguments array pointer at GS:DI
  mov di, [bp - 4]                        ; offset

  mov es, [bp - 6]                        ; Set ES to the segment of each argument
  mov di, gs:[di]                         ; Set ES:DI to point to the argument

  mov si, FILE_OPEN_ACCESS_READ           ; We want to just read the file, so request read permission
  mov ax, INT_N_FOPEN                     ; Interrupt number for openning a file
  int INT_F_KERNEL                        ; Open the file and get a handle to it (AX will be the handle, and null if the file doesnt exist)

  test ax, ax                             ; Check if fopen returned null
  jnz .fileOpened                         ; If it didnt, dont print an error message

  PUTS_INT 100h, errFileDoesntExit        ; If its null, then the file doesnt exist. Print an error message for that
  mov di, ERR_FILE_DOESNT_EXIST           ; Set the exit code to hte file doesnt exit code
  jmp main_end                            ; Exit

.fileOpened:
  ; Will get here if the file opened successfully, and the handle will be in AX
  mov bx, ds                                      ; We changed ES before, so reset to its original value. (Which is in DS)
  mov es, bx                                      ;
  lea di, dataEnd                                 ; Get a pointer to the end of this executable, which will bne used as a buffer to store the file.
  mov si, 0FFFFh - PROCESS_LOAD_OFFSET - dataEnd  ; Set the amount of bytes to read to rest of the executables space
  mov dx, ax                                      ; File handle in DX

  mov bx, ax                                      ; Store the file handle in BX, which wont change after the interrupts

  mov ax, INT_N_FREAD                             ; Interrupts number for reading a file
  int INT_F_KERNEL                                ; Read the file into the buffer

  PUTS_INT 100h, dataEnd                  ; Print the files content from the buffer

  mov di, bx                              ; Get file handle in DI

  mov ax, INT_N_FCLOSE                    ; Interrupt number for closing a file
  int INT_F_KERNEL                        ; Close the file

  xor di, di                              ; Zero out exit code
main_end:
  mov sp, bp                              ; Restore stack frame
  mov ax, INT_N_EXIT                      ; Interrupt number for quiting
  int INT_F_KERNEL                        ; Exit

;
; --------- [ DATA SEGMENT ] ---------
;

errFileDoesntExit:    db "[ - text] Error, the given file does not exist.", NEWLINE, 0
errNotEnoughArgs:     db "[ - text] Error, not enough arguments.", NEWLINE, 0

dataEnd:

%endif