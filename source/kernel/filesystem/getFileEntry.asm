;
; ---------- [ GET THE FILE FAT ENTRY ] ----------
;


; Searches for a file in a given path, and writes its FAT entry into a buffer.
; PARAMS
;   - 0) ES:DI  => Buffer to store entry, at least 32 bytes long.
;   - 1) DS:SI  => The files path. Doesnt need to be formatted correctly.
getFileEntry:
  push bp                         ; Save stack frame
  mov bp, sp                      ; 
  sub sp, 20                      ; Allocate memory on the stack

  ; *(bp - 2)     - Buffer segment
  ; *(bp - 4)     - Buffer offset
  ; *(bp - 6)     - File path segment
  ; *(bp - 8)     - File path offset
  ; *(bp - 10)    - Memory from malloc, for the formatted file path (segment)
  ; *(bp - 12)    - Memory from malloc, for the formatted file path (offset)
  ; *(bp - 14)    - Memory from malloc, the cluster buffer (segment)
  ; *(bp - 16)    - Memory from malloc, the cluster buffer (offset)
  ; *(bp - 17)    - Amount of directories/things in the path
  ; *(bp - 18)    - General counter
  ; *(bp - 20)    - LBA

  push gs                         ; Save old GS segment
  mov bx, KERNEL_SEGMENT          ; Set GS to kernel segment
  mov gs, bx                      ; 

  mov [bp - 2], es                ; Store buffer segment
  mov [bp - 4], di                ; Store buffer offset
  
  mov [bp - 6], ds                ; Store file path segment
  mov [bp - 8], si                ; Store file path offset

  ; We calculate the amount of memory to allocate for the formatted path
  ; Do it by counting the amount of '/' in the path, then increase the result by 1, and multiply it by 11.
  ; Thats because each path part (dir/test.txt : "dir" is a part and "test.txt" is a part) will be 11 bytes
  mov bx, ds                      ; ES = DS
  mov es, bx                      ; Because the argument for strFindLetterCount is in ES:DI
  mov di, si                      ; Set string offset
  mov si, '/'                     ; What character to count
  call strFindLetterCount         ; Count the amount of '/' in the path

  inc ax                          ; Increase the amount of '/' in the path by 1, because there is always at least one part
  mov [bp - 17], al               ; Store the result, thats for later

  mov bx, 11                      ; Multiply by 11
  mul bx                          ; Get the size that the formatted string will have in AX

  mov di, ax                      ; Argument for malloc in DI (formatted string size)
  call malloc                     ; Allocate memory for the new formatted path

  mov bx, es                      ; Cant perform operations on segments directly, so copy the returned pointers segment to BX
  test bx, bx                     ; Check if the segment is null (malloc will return a null segment if it could not allocate memory)
  jz .err                         ; If null then return an error
  
  mov [bp - 10], es               ; If not null then store the segment and the offset 
  mov [bp - 12], di               ; Store offset

  ; Now we call a function that formats the path, and writes the new path to ES:DI
  mov ds, [bp - 6]                ; Get the paths (the argument) segment
  mov si, [bp - 8]                ; Get the paths (the argument) offset
  call getFullPath                ; Format the path and store result in ES:DI

  ; Here we calculate the amount of bytes in a cluster, then allocate memory for 1 cluster
  mov ax, gs:[bpb_bytesPerSector]     ; Get the amount of bytes in a sector
  mov bx, gs:[bpb_sectorPerCluster]   ; Get the amount of sectors in a cluster
  mul bx                              ; res = bytesPerSector * sectorsPerCluster

  mov di, ax                      ; Argument for malloc goes in DI
  call malloc                     ; Allocate memory for 1 cluster
  
  mov bx, es                      ; Get returned pointers segment in BX
  test bx, bx                     ; Check if malloc returned a null pointer
  jz .err                         ; If null then return an error

  mov [bp - 14], es               ; If not null then store the segment and the offset
  mov [bp - 16], di               ; Store offset

  ; Here we get the LBA of the root directory, and the root directories size in sectors
  push ds                         ; Need to set DS to kernel segment, so the get regions functions read currect values
  mov bx, KERNEL_SEGMENT          ; Set DS tro kernel segment
  mov ds, bx                      ;
  GET_ROOT_DIR_OFFSET             ; Get the root directories offset (LBA) in AX
  mov [bp - 20], ax               ; Store offset
  GET_ROOT_DIR_SIZE               ; Get the root directories length in AL
  mov [bp - 18], al               ; Store it (will be used as a counter)
  pop ds                          ; Restore old DS segment

  ; Now we go through the root directory and search for the first part of the formatted string (the first 11 bytes)
.searchInRootDir: 
  mov di, [bp - 20]                   ; Get current LBA that we will read from

  ; Get the amount of sectors to read. We have a 1 cluster buffer, so read the amount of sectors in a cluster
  mov al, gs:[bpb_sectorPerCluster]   ; sectorsPerCluster is 8 bits
  xor ah, ah                          ; Zero out high part
  mov si, ax                          ; Second argument for readDisk, how many sectors to read

  mov bx, [bp - 16]                   ; Get pointer to buffer, in ES:BX
  mov es, [bp - 14]                   ; Get pointers offset
  push ds                             ; Need to set DS to kernel segemnt so readDisk reads correct values
  mov ax, KERNEL_SEGMENT              ; Set DS to kernel segment
  mov ds, ax                          ;
  call readDisk                       ; Read a cluster of the root directory into buffer
  pop ds                              ; Restore old DS
  test ax, ax                         ; Check if readDisk returned an error
  jnz .err                            ; If it did then return an error

  ; Load a pointer to the formatted string, and to the file name, then compare 11 bytes
  mov ds, [bp - 10]                   ; Get pointer to formatted string
  mov si, [bp - 12]                   ; Get offset

  mov es, [bp - 14]                   ; Get entries pointer
  mov di, [bp - 16]                   ; Get offset

  ; Calculate the amount of bytes in a cluster, then divide it by 32 to get the amount of entries to search in for the file
  mov ax, gs:[bpb_bytesPerSector]     ; Get amount of bytes in a sector
  mov bl, gs:[bpb_sectorPerCluster]   ; Get amount of sectors in a cluster (8 bits)
  xor bh, bh                          ; Zero out high part
  mul bx                              ; res = bytesInSector * sectorsPerCluster
  shr ax, 5                           ; Divide by 32 (log2(32) == 5)
  mov dx, ax                          ; Use DX as the entries counter
.searchFilenameInRootDir: 
  mov cx, 11                          ; Compare 11 bytes
  cld                                 ; Clear direction flag so CMPSB will increase DI and SI
  push si                             ; Save previous string pointer
  push di                             ; Save previous buffer pointer
  repe cmpsb                          ; Compare 11 bytes of both strings
  pop di                              ; Restor buffer pointer
  pop si                              ; Restore string pointer
  je .foundFirstEntry                 ; If the strings are equal, jump

  ; If the strings are not equal, then decrement counters, increase pointers and stuff
  add di, 32                          ; Increase buffer pointer to point to next entry

  dec dx                              ; Decrement entries left to read counter
  jnz .searchFilenameInRootDir        ; While its not zero continue checking entries

  ; If the entries counter has reached zero, then prepare pointers for next cluster
  mov al, gs:[bpb_sectorPerCluster]   ; Get amount of sectors in a cluster (8 bits)
  xor ah, ah                          ; Zero out high part
  add word [bp - 20], ax              ; Increase LBA address for next cluster in root directory
  ; Subtract from the amount of sectors to read, the amount of sectors in a cluster (because reading a cluster each time)
  sub byte [bp - 18], al              ; Amount of sectors in a cluster already in AL
  cmp byte [bp - 18], 0               ; Check if its below/equal to 0
  jg .searchInRootDir                 ; As long as its not zero or negative, continue reading clusters and searching for the file

  ; If negative/zero then error with a file not find error
  mov ax, ERR_FILE_NOT_FOUND          ; Get error code in AX
  jmp .end                            ; Return

.foundFirstEntry:
  PRINT_CHAR 'K', VGA_TXT_YELLOW      ;;;;;;;; DEBUG


;;;;;;; TODO free malloced memory (not doing it for now, but i will)
.err:
  mov ax, ERR_GET_FILE_ENTRY
.end:
  pop gs                              ; Restore old GS segment
  mov es, [bp - 2]                    ; Restore ES segment
  mov ds, [bp - 6]                    ; Restore DS segemnt
  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  ret
