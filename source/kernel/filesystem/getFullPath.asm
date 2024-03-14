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
  mov [bp - 2], es          ; Store buffer segment
  mov [bp - 4], di          ; Store buffer offset
  
  mov [bp - 6], ds          ; Store path segment
  mov [bp - 8], si          ; Store path offset
  
  mov bx, KERNEL_SEGMENT    ; Set the kernel segment because currentUserDirPath is in it
  mov ds, bx                ; 

  ; Search how many directories are in currentUserDirPath
  ; to find the minimum size of the buffer needed.
  lea di, [currentUserDirPath]
  mov si, '/'
  call strFindLetterCount

  test ax, ax
  jz getFullPath_afterCalcLength

  mov bx, 11
  mul bx

  PRINTF_M "Count: %u", ax


getFullPath_afterCalcLength:

getFullPath_end:
  mov sp, bp
  pop bp
  ret

getFullPath_errBufferTooSmall:
  mov bx, ERR_BUFFER_LIMIT
  jmp getFullPath_end