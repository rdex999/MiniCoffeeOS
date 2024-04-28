;
; ---------- [ CREATE A FILE ON A GIVEN PATH ] ----------
;

%ifndef CREATE_FILE_ASM
%define CREATE_FILE_ASM

; Create a file on a given path. basicaly create a directory entry, and get a free cluster
; PARAMS
;   - 0) ES:DI    => The buffer to store the files FAT entry in (If null, then wont write the files entry)
;   - 1) DS:SI    => A string containing the file path. Doesnt have to be formatted.
; RETURNS
;   - 0) In AX, the error code.
createFile:
  push bp                               ; Save stack frame
  mov bp, sp                            ;
  sub sp, 8                             ; Allocate memory on the stack for local variables

  ; *(bp - 2)     - Buffer segment
  ; *(bp - 4)     - Buffer offset
  ; *(bp - 6)     - Formatted string offset (segment is SS)
  ; *(bp - 8)     - Old DS segment

  mov [bp - 2], es                      ; Store buffers segment
  mov [bp - 4], di                      ; Store buffers offset
  mov [bp - 8], ds

  mov bx, ds                            ; Set ES:DI = DS:SI   // Set argument for strFindLetterCount, the path to format
  mov es, bx                            ; Set ES = DS

  mov di, si                            ; Set DI = SI, the paths offset
  mov si, '/'                           ; Set second argument for strFindLetterCount, the letter to find ('/')
  push es                               ; Save the original path string pointer
  push di                               ; Save its offset
  call strFindLetterCount               ; Get the amount of '/' in the path in AX
  pop si                                ; Restore the path offset
  pop ds                                ; Restore the paths segment

  inc ax                                ; Increase amount of '/' in the string, so we always allocate at least 11 bytes
  mov bx, 11                            ; Each path part is 11 bytes
  mul bx                                ; Multiply the amount of '/' in the path by 11 to get the amount of memory to allocate

  inc ax                                ; Increase by 1, for the null character
  sub sp, ax                            ; Allocate space for the formatted path on the stack
  mov [bp - 6], sp                      ; Save formatted path offset

  ; DS:SI, the string path, is already set.
  mov bx, ss                            ; Set argument for getFullPath, where to store the new path   // Set it to the buffer
  mov es, bx                            ;
  mov di, sp                            ; SP already set to the buffers offset
  call getFullPath


  ;;;;; DEBUG
  mov bx, ss
  mov ds, bx
  mov si, sp
  mov di, COLOR(VGA_TXT_YELLOW, VGA_TXT_DARK_GRAY)
  call printStr



.end:
  mov es, [bp - 2]                      ; Restore used segments
  mov ds, [bp - 8]                      ;
  mov sp, bp                            ; Restore stack frame
  pop bp                                ;
  ret


%endif