;
; ---------- [ GET THE FULL PATH, FROM A RELATIVE PATH TO THE CURRENT DIRECTORY ] ----------
;

; Takes a normal path, (like "dir/file.txt" for example) 
; and returns the full path for it, correctly formated (capital, 11 byte names) and adds currentUserDirPath to the beginning
; PARAMS
;   - 0) ES:DI    => Buffer to store new path in.
;   - 1) DS:SI    => Normal path string, null terminated.
; RETURNS
;   - In BX, the error code. 0 for no error, an error code otherwise.
;   - In AL, the number of directories in path. (count '/')
getFullPath:
  push bp
  mov bp, sp

  sub sp, 4*2
  mov [bp - 2], es                          ; Store buffer segment
  mov [bp - 4], di                          ; Store buffer offset
  
  mov [bp - 6], ds                          ; Store path segment
  mov [bp - 8], si                          ; Store path offset
  
  mov bx, KERNEL_SEGMENT                    ; Set the kernel segment because currentUserDirPath is in it
  mov ds, bx                                ; 

  ; ES is already at the buffer segment, and DI is already on the buffer offset
  cmp byte ds:[currentUserDirPath + 1], 0   ; Check if current user path is on the root directory
  je getFullPath_afterUserPathCopy          ; If it is, then there is no need to parse it

  ; If currentUserDirPath is not on the root directory then parse it
  lea si, [currentUserDirPath]              ; Get pointer to currentUserDirPath in SI
  call parsePath                            ; Parse it, as the buffer is already set at ES:DI
  test bx, bx                               ; Check if there was an error
  jnz getFullPath_end                       ; If there was an error then return with it as the error code in BX

  ; Get the length of the new parsed path, and add it to the buffer pointer to get the location of the last character there.
  mov di, [bp - 4]                          ; Pointer to the beginning of the buffer, which is the parsed path
  call strlen                               ; Get its length in AX

  mov di, [bp - 4]                          ; Get pointer to the beginning of the parsed path in DI
  add di, ax                                ; Add to the its length and get a pointer to its last character in DI

getFullPath_afterUserPathCopy:
  ; Set pointers to buffer and path. ES:DI => buffer, DS:SI => path
  mov ds, [bp - 6]                    ; Set path segemnt in DS
  mov si, [bp - 8]                    ; Set path offset in SI
  
  mov es, [bp - 2]                    ; Set buffer segment in ES

  cmp byte ds:[si], '/'               ; Check if the path (parameter) starts with '/' to determin if its from the root dir
  je getFullPath_isOnFullPath         ; If its from the root dir then just parse it and write it to the beginning of the buffer

  ; If the path (parameter) is not from the root directory then parse it and
  ; write the new path to the current position in the buffer. (After the parsed currentUserDirPath)
  ; ES:DI buffer (already set)
  ; DS:SI path offset (already set)
  call parsePath
  jmp getFullPath_end                 ; If there was an error, BX will be the error code and we will return with this error code

getFullPath_isOnFullPath:
  ; If the path (parameter) is from the root directory then parse it and write it after the parsed currentUserDirPath
  mov di, [bp - 4]                    ; Get buffer offset in DI
  ; DS:SI path is already set
  call parsePath
  ; If there was an error then return with the error code which is in BX

getFullPath_end:
  mov ds, [bp - 2]
  mov si, [bp - 6]

  mov sp, bp                          ; Restore stack frame
  pop bp                              ; 
  ret