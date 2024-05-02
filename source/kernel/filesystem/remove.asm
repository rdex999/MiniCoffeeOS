;
; ---------- [ DELETE A FILE ] ----------
;

%ifndef REMOVE_ASM
%define REMOVE_ASM

; Delete a file from the filesystem
; PARAMS
;   - 0) ES:DI  => The file name
; RETURNS
;   - 0) In AX, the error code (0 on success)
remove:
  push bp
  mov bp, sp
  sub sp, 11

  ; *(bp - 2)   - Old GS segment
  ; *(bp - 4)   - File name segment
  ; *(bp - 6)   - File name offset
  ; *(bp - 8)   - Old DS segment
  ; *(bp - 10)  - Formatted path offset (segment is SS), or the offset of the copy of the path (if the file is not on the root directory)
  ; *(bp - 11)  - Formatted path length

  mov [bp - 2], gs                            ; Store GS segment because we will change it
  mov [bp - 4], es                            ; Store file name segment
  mov [bp - 6], di                            ; Store file name offset
  mov [bp - 8], ds                            ; Store DS segment because we will change it

  ; Here we count the amount of path parts in the path (amount of directories + 1)
  ; We do this because we need to know if the file is on the root directory or not, and if it is
  ; then we need to get the formatted paths size (which is, size = pathParts * 11)
  mov si, '/'                                 ; Set letter to count
  call strFindLetterCount                     ; Get the amount of '/' is the file name
  test ax, ax
  jnz .notOnRootDir

  inc ax                                      ; Icrease it by one to get the amount of directories in the file

  mov bx, 11                                  ; Size of a path part
  mul bx                                      ; Multiply amount of directories by the size of a path part

  mov [bp - 11], al                           ; Store it
  inc ax                                      ; Increase by one for the null character

  sub sp, ax                                  ; Allocate space for the formatted path
  mov [bp - 10], sp                           ; Store formatted path pointer

  mov bx, ss                                  ; Set the destination to the allocated buffer
  mov es, bx                                  ; Set segment
  mov di, sp                                  ; Set offset

  mov ds, [bp - 4]                            ; Set source, the unformatted path    // Set segment
  mov si, [bp - 6]                            ; Set offset
  call getFullPath                            ; Format the path and write it into the buffer we created
  test bx, bx                                 ; Check error code
  jz .filePathSuccess                         ; If there was no error, skip the next two lines

  mov ax, bx                                  ; Get the error code in AX
  jmp .end                                    ; Return

.filePathSuccess:
  ;;;; DEBUG
  mov bx, ss
  mov ds, bx
  mov si, sp
  mov di, COLOR(VGA_TXT_YELLOW, VGA_TXT_DARK_GRAY)
  call printStr

  jmp .end

.notOnRootDir:
  ;;;;;; NOT YET IMPLEMENTED
  PRINT_CHAR 'E', VGA_TXT_YELLOW

.end:
  mov gs, [bp - 2]
  mov es, [bp - 4]
  mov ds, [bp - 8]
  mov sp, bp
  pop bp
  ret

%endif