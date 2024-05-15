;
; ---------- [ MOVE A FILE FROM ONE DIRECTORY TO ANOTHER ] ----------
;

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/filesystem.asm"
%include "shared/ascii.asm"
%include "shared/print.asm"
%include "shared/colors.asm"

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

  mov si, [bp - 4]                      ; Get a pointer to the arguments array
  mov di, gs:[si + 4]                   ; Get a pointer to the second argument
  mov si, di
  mov cx, 0FFFFh                        ; Amount of bytes to check, set to the maximum amount possible
  xor al, al                            ; The character to search for, we need the null character
  cld                                   ; Clear direction flag so SCASB will increment DI each iteration
  repne scasb                           ; Search for the null character in the second argument, and get a pointer to the character after it

  cmp byte es:[di - 2], '/'             ; Check if the last character of the second argument is '/', in which case need to copy the filename to the end of this path
  xchg si, di 
  jne .afterCopyFilename                ; If its not a '/', dont copy the filename

  ; Copy the second argument into a buffer, then copy the filename to the end of it
  lea dx, [si - 1]                      ; Get a pointer to the null character in the second argument
  mov si, [bp - 4]
  sub dx, gs:[si + 4]                   ; Subtract the beginning of the first argument from it, to get the legnth of the second argument

  mov ax, ds                            ; Need to switch ES and DS, so save current DS in AX

  mov bx, es                            ; Set DS = ES
  mov ds, bx                            ;
  mov si, gs:[si + 4]                   ; Get a pointer to the second argument

  mov es, ax                            ; Set ES to the previous DS
  mov di, fileBuffer                    ; Get a pointer to the destinaiton buffer. Now DS:SI -> second argument, ES:DI -> Destination buffer
  mov ax, INT_N_MEMCPY                  ; Interrupt number for copying a chunk of memory
  push dx                               ; Save amount of bytes to copy
  int INT_F_KERNEL                      ; Copy the second argument into the buffer, and get a pointer to the destination buffer in ES:AX
  pop di                                ; Restore amount of bytes copied in DI

  add di, ax                            ; Increase it by the destination buffer pointer, so it points to the character after the last character
  push di                               ; Save the pointer to the character after the last one

  mov ds, [bp - 6]                      ; Set DS to the segment of each argument
  mov si, [bp - 4]                      ; Get a pointer to the arguments array GS:SI
  mov di, gs:[si + 2]                   ; Get a pointer to the first argument, DS:DI
  mov si, di                            ; SI will point to the first character of the last

  ; Search for the first character of the filename. If the first argument is "/bin/idk" then the filename is "idk"
.searchFileLoop:
  cmp byte ds:[di], 0                   ; Check if its the end of the first argument
  je .endSearchFile                     ; If its the end, break out of the loop

  cmp byte ds:[di], '/'                 ; Check if the character is a '/'
  jne .notSeperator                     ; If its not, dont store a pointer to the character after it

  lea si, [di + 1]                      ; If its a '/', set SI to point to the character after it

.notSeperator:
  inc di                                ; Increase first argument string pointer
  jmp .searchFileLoop                   ; Continue searching

.endSearchFile:
  mov dx, di                            ; Get a pointer to the last character (the null character)
  sub dx, si                            ; Subtract the location of the first character in the filename from it, to get the length of the filename

  pop di                                ; Restore the pointer to the last character of the second argument, in the buffer
  mov ax, INT_N_MEMCPY                  ; Interrupt number for memcpy
  push dx                               ; Save the amount of bytes thats going to ber copied
  int INT_F_KERNEL                      ; Copy the filename
  pop di                                ; Restore amount of bytes copied

  add di, ax                            ; Add the pointer to the last character of the second argument (in the buffer) to it, so it points to the last character
  mov byte es:[di], 0                   ; Null terminate the string

  mov bx, fs                            ; Reset DS to its original value
  mov ds, bx                            ;

  lea di, fileBuffer                    ; Get a pointer to the formatted string


.afterCopyFilename:
  ; Jump here with a pointer to the file to create in ES:DI
  mov bx, es
  mov ds, bx
  PUTS_INT 100h, di             ;;;;;; DEBUG

  mov di, [srcFileHandle]
  mov ax, INT_N_FCLOSE
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