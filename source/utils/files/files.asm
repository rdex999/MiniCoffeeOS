;
; --------- [ LIST FILE/DIRECTORIES ON A DIRECTORY ] ---------
;

%ifndef FILES_ASM
%define FILES_ASM

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/filesystem.asm"
%include "shared/print.asm"
%include "shared/ascii.asm"

%define ERR_TOO_MANY_ARGS 1
%define ERR_PATH_DOESNT_EXIST 2

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp                            ; Save stack frame
  sub sp, 6                             ; Allocate space for the arguments array

  mov [bp - 2], ax                      ; Save arguments array segment
  mov [bp - 4], bx                      ; Save arguments array offset
  mov [bp - 6], dx                      ; Save segment of each argument

  cmp cx, 2                             ; Check if there is more than one argument (two paths)
  jbe .argCntOk                         ; If there is one argument or less, dont print the error message

  ; If there is more than one argument, print an error message
  PUTS_INT 100h, errTooManyArgs         ; Print the error message
  mov di, ERR_TOO_MANY_ARGS             ; Set the exit code
  jmp main_end                          ; Exit

.argCntOk:
  cmp cx, 2                             ; Check if there is an argument, or we should use the current user directory
  je .pathParameter                     ; If there is an argument, set the directory to read to teh argument

  ; If there is no argument, set the directory to read to the current user directory
  lea di, userDir                       ; Get a pointer to the buffer to store the directory in
  mov ax, INT_N_GET_USER_PATH           ; Interrupt number for getting the users directory
  int INT_F_KERNEL                      ; Get the current user directory, and write it to the buffer

  lea di, userDir                       ; Get a pointer to the user directory
  jmp .afterGetPath                     ; Continue and read the directory and stuff

.pathParameter:
  ; If there is an argument, make ES:DI point to it
  mov gs, [bp - 2]                      ; Get a pointer to the arguments array
  mov si, [bp - 4]                      ; Get the arguments array offset
  add si, 2                             ; GS:SI point to the actual argument

  mov es, [bp - 6]                      ; Get a pointer to the first argument (not the files name)
  mov di, gs:[si]                       ; Get the offset of the first argument

.afterGetPath:
  push di                               ; Save the path offset
  PUTS_INT 100h, listFilesOnDirMsg      ; Print listing message
  pop di                                ; Restore path offset

  mov bx, es                            ; Set DS = ES, becuase PUTS uses DS:SI
  mov ds, bx                            ;
  push di                               ; Save path offset
  PUTS_INT 100h, di                     ; Print the directory were listing files on
  PRINT_CHAR_INT 100h, NEWLINE          ; Print a newline
  pop di                                ; Restore the directory

  mov si, FILE_OPEN_ACCESS_READ         ; We only want to read the file, so request read access
  mov ax, INT_N_FOPEN                   ; Interrupt number for openning a file
  int INT_F_KERNEL                      ; Open the file and get a handle to it in AX
  
  mov bx, fs                            ; Reset segments to their original value
  mov es, bx                            ;
  mov ds, bx                            ;
  mov gs, bx                            ;
  
  test ax, ax                           ; Check if the handle in null, in which case the directory doesnt exist
  jnz .fileOpened                       ; If its not null, dont print the error message

  PUTS_INT 100h, errPathDoesntExist     ; If null, print the error message
  mov di, ERR_PATH_DOESNT_EXIST         ; Set exit code
  jmp main_end                          ; Exit

.fileOpened:
  mov gs, ax                            ; Store the handle in GS, because im too lazy to create a variable for it

  lea di, dirBuffer                     ; Get a pointer to the buffer that will store the directory
  mov si, 0FFFFh - PROCESS_LOAD_OFFSET - dirBuffer  ; Set the amount of bytes to read to the amount of space left for this process
  mov dx, ax                            ; Handle in DX
  mov ax, INT_N_FREAD                   ; Interrupt number for reading a file
  int INT_F_KERNEL                      ; Read the directory into the directory buffer

  mov cx, ax                            ; Get the amount of bytes actually read in CX, will be used as a counter

  PUTS_INT 100h, tableStr               ; Print a table indicating what is the file name, size, type, and other stuff

  lea si, dirBuffer                     ; Get a pointer to the directory buffer
.printFilesLoop:
  cmp byte [si], 0                      ; Check if the first byte of the directory is null, in which case its the end of the directory
  je .dirEnd                            ; If its the end, break out of the loop

  test byte [si + 11], FAT_F_DIRECTORY  ; Check if the current file in the directroy is a file or a directory
  mov byte [si + 11], 0                 ; Null terminate the filename
  jz .setTypeFile                       ; If its a file, and not a directory, set the type string (the DIR or FILE) to FILE

  lea di, dirTypeStr                    ; If its a directory, set the type string to DIR
  jmp .afterSetType                     ; Continue and get more file data

.setTypeFile:
  lea di, fileTypeStr                   ; If its a file, set the file time string to FILE

.afterSetType:
  mov ax, [si + 28]                     ; File size in bytes in AX
  mov bx, 1024                          ; We want to divide by the size of 1 kilobyte
  xor dx, dx                            ; Zero out remainder before division
  div bx                                ; Convert file size into kilobytes, while the kilobytes are in AX and the bytes are in DX
  
  push cx                               ; Save amount of files left to read
  push si                               ; Save current file in directory pointer
  PRINTF_INT_LM fileFormatStr, si, di, ax, dx   ; Print the file name, type, and size in Kilibytes

  mov cx, [si + 16]                     ; Get the files creation date in CX
  mov ax, cx                            ; The year will be in AX
  shr ax, 9                             ; Get the year in AX
  add ax, 2000 - 20                     ; Get year, starting from the 2000 (-20 because it starts from 20 idk why)

  mov bx, cx                            ; Month will be in BX
  and bx, 0F0h                          ; Zero out all bits except the month bits
  shr bx, 5                             ; Get month in BX

  and cx, 1Fh                           ; Get day in CX

  mov si, [si + 14]                     ; Get the creation time in SI

  mov dx, si                            ; The hour will be in DX
  shr dx, 11                            ; Get the hour

  mov di, si                            ; The minute will be in DI
  and di, 111_1110_0000b                ; Zero out all bits except the minute bits
  shr di, 5                             ; Get minute

  and si, 1Fh                           ; Zero out all bits except the seconds bits
  shl si, 1                             ; Get seconds

  ; When getting here, registers will have the creation time&date
  ; AX  - year
  ; BX  - month
  ; CX  - day
  ; DX  - hour
  ; DI  - minute
  ; SI  - second
  PRINTF_INT_LM fileFormatDateStr, ax, bx, cx, dx, di, si   ; Print the files creation time
  pop si                                ; Restore current file in directory pointer
  pop cx                                ; Restore amount of files left to read

  add si, 32                            ; Increase file pointer so it points to the next file in the directory
  sub cx, 32                            ; Decreemnt the amount of bytes left to read in the directory
  jg .printFilesLoop                    ; As long as its not zero or negative, continue printing files

.dirEnd:
  mov di, gs                            ; Get the file handle in DI
  mov ax, INT_N_FCLOSE                  ; Interrupt number for closing a file
  int INT_F_KERNEL                      ; Close the directory file

  xor di, di                            ; Exit with 0 on success
main_end:
  mov sp, bp                            ; Restore stack frame
  mov ax, INT_N_EXIT                    ; Interrupts number for exiting from the process
  int INT_F_KERNEL                      ; Exit


;
; ---------- [ DATA SECTION ] ----------
;

errTooManyArgs:       db "[ - files] Error, too many arguments.", NEWLINE, 0
errPathDoesntExist:   db "[ - files] Error, the given path does not exist.", NEWLINE, 0

listFilesOnDirMsg:    db "[ * files] Listing files on ", 0

tableStr:             db NEWLINE, TAB, "FILE NAME  ", TAB, "TYPE ", TAB, "SIZE      ", TAB, "CREATION DATE", NEWLINE, NEWLINE, 0
dirTypeStr:           db "DIR", 0
fileTypeStr:          db "FILE", 0
fileFormatStr:        db TAB, "%s", TAB, "%s ", TAB, "%u.%u kB  ", TAB, 0
fileFormatDateStr:    db "%u-%u-%u  %u:%u:%u", NEWLINE, 0
userDir:              times MAX_PATH_FORMATTED_LENGTH db 0

bytesRead: db "bytes read %u", NEWLINE, 0

dirBuffer:

%endif