;
; ---------- [ CREATE A FILE ON A GIVEN PATH ] ----------
;

%ifndef CREATE_FILE_ASM
%define CREATE_FILE_ASM

; Create a file on a given path. basicaly create a directory entry, and get a free cluster
; PARAMS
;   - 0) ES:DI    => The buffer to store the files FAT entry in (If null, then wont write the files entry)
;   - 1) DS:SI    => A string containing the file path. Doesnt have to be formatted.
;   - 2) DL       => Flags
; RETURNS
;   - 0) In AX, the error code.
createFile:
  push bp                               ; Save stack frame
  mov bp, sp                            ;
  sub sp, 16                            ; Allocate memory on the stack for local variables

  ; *(bp - 2)     - Buffer segment
  ; *(bp - 4)     - Buffer offset
  ; *(bp - 6)     - Paths segment
  ; *(bp - 8)     - Paths offset
  ; *(bp - 10)    - Formatted string offset (segment is SS)
  ; *(bp - 11)    - Formatted string length
  ; *(bp - 13)    - Sector buffer offset (segment is SS)
  ; *(bp - 15)    - Current LBA in root directory
  ; *(bp - 16)    - Sectors left in root directory

  mov [bp - 2], es                      ; Store buffers segment
  mov [bp - 4], di                      ; Store buffers offset
  mov [bp - 6], ds                      ; Store paths segment
  mov [bp - 8], si                      ; Store paths offset

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

  mov [bp - 11], al                     ; Store the length of the formatted string
  inc ax                                ; Increase by 1, for the null character
  sub sp, ax                            ; Allocate space for the formatted path on the stack
  mov [bp - 10], sp                     ; Save formatted path offset

  ; DS:SI, the string path, is already set.
  mov bx, ss                            ; Set argument for getFullPath, where to store the new path   // Set it to the buffer
  mov es, bx                            ;
  mov di, sp                            ; SP already set to the buffers offset
  call getFullPath                      ; Get the formatted path and store it in the buffer from ES:DI
  test bx, bx                           ; Check getFullPath's error code
  jz .gotFormatted                      ; If not error, then skip the next 2 lines

  mov ax, bx                            ; If there was an error then set the error code in AX and return
  jmp .end                              ; Return

.gotFormatted:
  ; Will get here if there was no error
  cmp byte [bp - 11], 11                ; Check if the formatted strings length is 11 (if it is then the file in from the root directory) 
  jne .notOnRootDir                     ; If the length is not 11, then the file is not from the root directory. so skip this part

  ; Will be here if the file is from the root directory
  mov bx, KERNEL_SEGMENT                ; Set DS to the kernel segment so we can read correct values
  mov ds, bx                            ;
  
  sub sp, ds:[bpb_bytesPerSector]       ; Allocate space for 1 sector on the stack
  mov [bp - 13], sp                     ; Store the sector buffer offset

  GET_ROOT_DIR_OFFSET                   ; Get the LBA of the root directory
  mov [bp - 15], ax                     ; Store it
  GET_ROOT_DIR_SIZE                     ; Get the size of the root directory 
  mov [bp - 16], al                     ; Store it, it will we used as a counter for how many sectors are left to read

.rootDirNextSector:
  mov bx, ss                            ; Set destination segment, where to read the data to
  mov es, bx                            ; Read into the sector buffer, which is on the stack

  mov bx, [bp - 13]                     ; Set sector buffer offset
  mov di, [bp - 15]                     ; Get the current LBA in the root directory
  mov si, 1                             ; Read 1 sector
  call readDisk                         ; Read 1 sector of the root directory into the sector buffer in ES:BX
  test ax, ax                           ; Check readDisk's error code
  jnz .end                              ; If there was an error then return with the error code

  mov di, [bp - 13]                     ; Get a pointer to the sector buffer in SS:DI
  mov cx, ds:[bpb_bytesPerSector]       ; CX will count how many entries are left to read (decremented by 32 each iteration)
.searchEmtpy:
  cmp byte ss:[di], 0                   ; If the first byte of the entry is 0, then the entry is free. Check if the current entry if free
  je .foundEmptyRootDir                 ; If it is free then jump
  add di, 32                            ; If not free then increase the sector buffer pointer to point to the next entry
  sub cx, 32                            ; Decrement entries counter (how many are left)
  jnz .searchEmtpy                      ; As long as the entry counter is not zero continue searching

  ; If the entry counter has reached 0, then increase the LBA, and decrement the amount of sectors left to read in the root directory
  inc word [bp - 15]                    ; Increase current LBA
  dec byte [bp - 16]                    ; Decrement sectors left to read in the root directory
  jnz .rootDirNextSector                ; If its not zero then jump and load the next sector of the root directory

  mov ax, ERR_DISK_FULL 
  jmp .end

.foundEmptyRootDir:
  ; When getting here, the empty entry should be pointed to by SS:DI

.notOnRootDir:
  ; Will get here if the file is from the rrot directory


.end:
  mov es, [bp - 2]                      ; Restore used segments
  mov ds, [bp - 6]                      ;
  mov sp, bp                            ; Restore stack frame
  pop bp                                ;
  ret


%endif