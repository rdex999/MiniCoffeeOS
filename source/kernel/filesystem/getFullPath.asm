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

  ; ES is already at the buffer segment, and DI is already on the buffer offset
  cmp byte ds:[currentUserDirPath + 1], 0
  je getFullPath_afterUserPathCopy

  lea si, [currentUserDirPath]
  call parsePath
  test bx, bx
  jnz getFullPath_end

  mov di, [bp - 4]
  call strlen

  mov di, [bp - 4]
  add di, ax

getFullPath_afterUserPathCopy:
  mov bx, [bp - 6]
  mov ds, bx

  mov si, [bp - 8]
  mov bx, [bp - 6]
  mov ds, bx
  
  mov bx, [bp - 2]
  mov es, bx

  cmp byte ds:[si], '/'
  je getFullPath_isOnFullPath

  call parsePath
  xor bx, bx
  jmp getFullPath_end


getFullPath_isOnFullPath:
  mov di, [bp - 4]
  call parsePath

  xor bx, bx

getFullPath_end:
  mov sp, bp
  pop bp
  ret

getFullPath_errBufferTooSmall:
  mov bx, ERR_BUFFER_LIMIT
  jmp getFullPath_end