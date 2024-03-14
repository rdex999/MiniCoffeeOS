;
; ---------- [ PARSE A FILES PATH INTO 11 BYTE STRINGS ] ----------
;


; Converts a normal path into an array of 11 byte strings all capital
; PARAMS
;   - 0) ES:DI    => Buffer to store new path in
;   - 1) DS:SI    => File path (string, null terminated)
; RETURNS
;   - In BX, the error code. 0 for no error, 1 for one of the names is too long
;   - In AL, the number of directories in path. (count '/')
;   - In AH, a flag for determining if the path is from the root directory or not (0, not from root dir. 1, from root dir)
parsePath:
  push bp
  mov bp, sp
  sub sp, 5                       ; Allocate 6 bytes

  mov byte [bp - 1], 11+2         ; Characters left to read
  mov [bp - 3], di                ; Beginning of currect name (formatted)
  mov byte [bp - 4], 0            ; Zero count of directories (count '/')
  mov byte [bp - 5], 0            ; Flag for if the path is from the root directory

  cmp byte ds:[si], '/'           ; Check if the path is from the root dir
  jne parsePath_parseName         ; If not the root directory then leave the flag on, otherwise (if root dir) make the flag 1

  mov byte [bp - 5], 1            ; Turn flag on if the path starts from the root directory
  inc si                          ; Increase source file path pointer, so wont process the '/'

  cld                             ; Clear direction flag so MOVSB will increment both SI and DI

; Main processing loop, checks for '/', makes letters capital if needed and stuff
parsePath_parseName:
  dec byte [bp - 1]               ; Decrement counter of bytes left in current name. Name is like the current directory,
                                  ; for example "/idk/test.txt" then "idk", and "test.txt" are names
  jz parsePath_nameTooLong        ; If the bytes left in current name is 0 then return an error of 1 in BX

  mov al, ds:[si]                 ; AL = next character in source path, its more efficient to compare registers instead of pointer
  
  test al, al                     ; Check for null character
  jz parsePath_foundNull          ; If null then stop processing, and finish up.

  cmp al, '/'                     ; Check for directories
  je parsePath_fSlash

; Because everything under 'a' (in ascii table) can be treated as a symbol, no need to even check for it/
; For exampla there is no need to format an 'A' or an '$'
  cmp al, 'a'
  jb parsePath_symbol

  ; If it is not below 'a' and is below 'z'+1 then its a lower case letter.
  ;+1 because more efficient to JB instead of JBE
  cmp al, 'z'+1                   
  jb parsePath_lowerCaseLetter      ; If lower case letter then make it capital (jump)

  movsb                             ; If its above 'z' then its a symbol, and just process it as one
  jmp parsePath_parseName           ; Continue parsing name

parsePath_lowerCaseLetter:
  movsb                             ; Copy the byte to buffer
  sub byte es:[di-1], 32            ; Make it capital
  jmp parsePath_parseName           ; Continue parsing name

parsePath_symbol:
  movsb                             ; Copy byte into buffer
  jmp parsePath_parseName           ; Continue parsing name

parsePath_fSlash:
  inc si                            ; Increase source path pointer
  mov byte [bp - 1], 11+2           ; Reset bytes left for current name
  inc byte [bp - 4]                 ; Increase counter of directories (count of '/')

  ; Get legnth of string
  mov ax, di                        ; AX = buffer pointer
  sub ax, [bp - 3]                  ; Subtract the pointer of the beginning of the buffer to get length of processed string so fat
  mov cx, 11                        ; Set CX to the max bytes of name
  sub cx, ax                        ; Subtract from CX the length of the processed string to get number of spaces to fill
  jz parsePath_parseName            ; If zero and try to decrement will be 0FFFFh, which is not what we want

  ; Will the rest of the name with spaces
parsePath_fSlash_fillSpace:
  mov byte es:[di], ' '             ; Set byte in buffer to space
  inc di                            ; Increment buffer pointer
  loop parsePath_fSlash_fillSpace   ; Continue filling with spaces until number of spaces to fill is zero

  mov [bp - 3], di                  ; Set beginning of current string buffer to buffer pointer
  jmp parsePath_parseName           ; Continue parsing name

parsePath_foundNull:
  push di                               ; Save current position in buffer

  ; Get the amount of bytes to fill with spaces 
  mov ax, di                            ; CX = buffer pointer
  sub ax, [bp - 3]                      ; Subract the beginning of the buffer to get current name length in CX
  mov cx, 11                            ; CX = length of path part (11)
  sub cx, ax                            ; CX = 11 - currentNameLength   => How many spaces to fill

  ; Fill rest of the buffer with spaces
parsePath_foundNull_fillSpaceAfterExt:
  mov byte es:[di], ' '                       ; Make current byte a space
  inc di                                      ; Increase buffer pointer
  loop parsePath_foundNull_fillSpaceAfterExt  ; Continue until there are no more bytes to fill (until CX == 0)

  ; Null terminate buffer and get the length of the name in CX (length not including the spaces that were just filled)
  mov byte es:[di], 0                   ; Null terminate the buffer
  pop di                                ; Restore the location of the last character in the buffer (which is not a space)
  mov cx, di                            ; Set CX to it to get the length of the path part without the spaces
  sub cx, [bp - 3]                      ; Subtract from the location the location of the first byte in the name. (lastChar - firstChar)

  ; Search for the file extension, and if not found then just return
parsePath_foundNull_searchExt:          ; Loop from the end of the buffer and search for '.'
  cmp byte es:[di - 1], '.'             ; Check for '.'
  je parsePath_foundNull_foundExt       ; If is a '.' then return a pointer (DI) to the byte after it
  dec di                                ; Decrement buffer pointer
  loop parsePath_foundNull_searchExt    ; Continue searching for '.' until name length (CX) is zero

  jmp parsePath_success                 ; If we get here then it means there is no '.'. Just return with counters

  ; Copy the extension to the end of the string - 3. for example "file.txt" => "FILE    TXT"
parsePath_foundNull_foundExt:
  mov si, [bp - 3]                      ; SI = pointer to the beginning of name buffer
  mov cx, 3                             ; Copy 3 bytes after the '.'
parsePath_foundNull_copyExt:
  mov al, es:[di]                       ; Set al to current extension byte
  mov es:[si + 11 - 3], al              ; Copy the current extension byte to the end of the string."file.txt" => "FILE    TXT"
  inc si                                ; Increase destenation pointer, end of the string
  inc di                                ; Increase extension pointer
  loop parsePath_foundNull_copyExt      ; Continue copying the extension, 3 times. (1 byte at a time)

  ; Fill whats after the dot and before the copied extension with spaces
  mov si, [bp - 3]                      ; Set SI to the beginning of the name buffer
  add si, 11-3                          ; Set SI to the first byte of the copied extension (three bytes from the end)
  sub di, 4                             ; Subtract 4 from extension pointer (old extension) to point to the '.'
parsePath_foundNull_fillSpace:
  mov byte es:[di], ' '                 ; Make current byte a space
  inc di                                ; Increase pointer
  cmp di, si                            ; Comapre the pointer to the beginning of the extension.
  jb parsePath_foundNull_fillSpace      ; As long as the pointer is smaller then the extension pointer continue filling spaces

  ; Return with counters
parsePath_success:
  mov al, [bp - 4]                      ; Amount of directories (count '/')
  mov ah, [bp - 5]                      ; If the path is from the root directory
  xor bx, bx                            ; No error occurred, return error code 0
parsePath_end:
  mov sp, bp
  pop bp
  ret

parsePath_nameTooLong:
  xor ax, ax                              ; Zero out result
  mov bx, ERR_PATH_PART_LIMIT             ; Return an error if one of the directories is too long 
  jmp parsePath_end