;
; ---------- [ MOVE A FILE FROM ONE DIRECTORY TO ANOTHER ] ----------
;

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/filesystem.asm"
%include "shared/ascii.asm"
%include "shared/print.asm"

%define ERR_INVALID_USAGE 1
%define ERR_FILE_DOESNT_EXIST 2

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                            ; Save stack frame
  sub sp, 6                             ; Allocate space for the arguments array

  mov [bp - 2], ax                      ; Store arguments array segment
  mov [bp - 4], bx                      ; Store arguments array offset
  mov [bp - 6], dx                      ; Store the segment of each argument

  cmp cx, 3                             ; Check if the amount of arguments is 2 (not counting the command name)
  je .argsCorrect                       ; If its 2, dont print the error message

  PUTS_INT 100h, errInvalidUsage        ; If its not 2, print an error message
  mov di, ERR_INVALID_USAGE             ; Set error code
  jmp main_end                          ; Exit

.argsCorrect:
  mov gs, ax                            ; Get a pointer to the arguments array
  mov si, bx                            ;

  mov es, dx                            ; ES:DI will point to the first argument
  mov di, gs:[si + 2]                   ; Get offset of the first argument
  mov si, FILE_OPEN_ACCESS_READ         ; Only need to read the file, so request read access
  mov ax, INT_N_FOPEN                   ; Interrupt number for openning a file
  int INT_F_KERNEL                      ; Open the source file
  test ax, ax                           ; Check if the handle in null
  jnz .fileOpened                       ; If not null, dont print an error message

  PUTS_INT 100h, errFileDoesntExit      ; If null, then the file doesnt exist. Print an error message for that
  mov di, ERR_FILE_DOESNT_EXIST         ; Set error code
  jmp main_end                          ; Return

.fileOpened:
  mov [srcFileHandle], al               ; Store a handle to the first file

  mov di, gs:[si + 4]                   ; Get a pointer to the second argument
  mov ax, INT_N_STRLEN
  int INT_F_KERNEL




  xor di, di
main_end:
  mov ax, INT_N_EXIT
  int INT_F_KERNEL

;
; ---------- [ DATA SEGMENT ] ----------
;

errInvalidUsage:              db "[ - move] Error, invalid usage. Correct usage: move SOURCE_PATH DESTINATION_PATH", 0
errFileDoesntExit:            db "[ - move] Error, one of the given files does not exist.", NEWLINE, 0

srcFileHandle:                db 0
dstFileHandle:                db 0

fileBuffer: