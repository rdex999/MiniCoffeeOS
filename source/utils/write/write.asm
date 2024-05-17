;
; --------- [ WRITE TO A FILE ] ---------
;

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/filesystem.asm"
%include "shared/print.asm"
%include "shared/ascii.asm"

%define ERR_INVALID_USAGE 1

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                          ; Save stack frame

  cmp cx, 4                           ; Check if there are enough / too much arguments
  je .argsOk                          ; If there are 3 arguments, dont print an error message

  PUTS_INT 100h, errInvalidUsage      ; If there are more/less than 3 arguments, print an error message
  mov di, ERR_INVALID_USAGE           ; Set error code
  jmp main_end                        ; Exit

.argsOk:
  mov gs, ax                          ; Get a pointer to the arguments array GS:BX
  mov es, dx                          ;
  mov [argsArrayOff], bx              ; Store the arguments array offset

  mov di, gs:[bx + 4]                 ; Get a pointer to the second argument, the writing mode (write/append)
  lea si, writeStr                    ; String to compare the writing mode to, first check if its the "wirte" mode
  mov ax, INT_N_STRCMP                ; Interrupt number for comparing strings
  int INT_F_KERNEL                    ; Check if the requested mode is write
  test ax, ax                         ; Check
  jz .setWriteAccess                  ; If its write, set the file access to write

  lea si, appendStr                   ; If its not write, check if its append
  mov ax, INT_N_STRCMP                ; Interrupt number for comparing strings
  int INT_F_KERNEL                    ; Check if the requested mode is append
  test ax, ax                         ; Check
  jz .setAppendAccess                 ; If its append, set file access to append

  PUTS_INT 100h, errInvalidUsage      ; If its not append nor write, print an error message
  mov di, ERR_INVALID_USAGE           ; Set error code
  jmp main_end                        ; Exit

.setAppendAccess:
  mov si, FILE_OPEN_ACCESS_APPEND     ; Request append access
  jmp .afterSetAccess                 ; Continue and open the file

.setWriteAccess:
  mov si, FILE_OPEN_ACCESS_WRITE      ; Request write access

.afterSetAccess:
  mov di, [argsArrayOff]              ; Get a pointer to the arguments array, GS:DI
  mov di, gs:[di + 6]                 ; Get a pointer to the therd argument, the filename

  mov ax, INT_N_FOPEN                 ; Interrupt number for opening a file
  int INT_F_KERNEL                    ; Open the file and get a handle to it
  test ax, ax                         ; Check the handle is null
  jnz .fileOpened                     ; If not null, dont print an error message

  PUTS_INT 100h, errFileDoesntExist   ; If the handle is null, then the path to the file must not exist. Print an error message
  mov di, ERR_INVALID_USAGE           ; Set error code
  jmp main_end                        ; Exit

.fileOpened:
  mov dx, ax                          ; File handle goes in DX
  mov di, [argsArrayOff]              ; Get a pointer to the arguments array
  mov di, gs:[di + 2]                 ; Get a pointer to the first argument, the string to write
  mov ax, INT_N_STRLEN                ; Interrupt number for getting a strings length
  int INT_F_KERNEL                    ; Get the length of the string to write to the file

  inc ax                              ; Increase length by 1 for the null character
  mov si, ax                          ; Amount of bytes to write goes in SI
  mov ax, INT_N_FWRITE                ; Interrupt number for writing to a file
  int INT_F_KERNEL                    ; Write to the file

  mov di, dx                          ; File handle goes in DI
  mov ax, INT_N_FCLOSE                ; Interrupt number for closing a file
  int INT_F_KERNEL                    ; Close the file

  xor di, di                          ; Zero out exit code on success
main_end:
  mov sp, bp                          ; Restore stack frame
  mov ax, INT_N_EXIT                  ; Interrupt number for exiting
  int INT_F_KERNEL                    ; Exit

;
; --------- [ DATA SECTION ] ---------
;

errInvalidUsage:              db "[ - write] Error, invalid usage. Correct usage:", NEWLINE, TAB
                              db 'write "STRING" > FILE', TAB, "For deleting everything in the file and then writing", TAB
                              db 'write "STRING" >> FILE', TAB, "For appending to the end of the file.", NEWLINE, 0

errFileDoesntExist:           db "[ - write] Error, the given path does not exist.", NEWLINE, 0

appendStr:                    db ">>", 0
writeStr:                     db ">", 0


argsArrayOff:                 dw 0
argSeg:                       dw 0