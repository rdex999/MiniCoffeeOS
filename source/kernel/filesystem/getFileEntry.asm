;
; ---------- [ GET THE FILE FAT ENTRY ] ----------
;


; Searches for a file in a given path, and writes its FAT entry into a buffer.
; PARAMS
;   - 0) ES:DI  => Buffer to store entry, at least 32 bytes long.
;   - 1) DS:SI  => The files path. Doesnt need to be formatted correctly.
; RETURNS
;   - 0) In AX, the error code. (0 on success)
;   - 1) In BX, the entries LBA address
;   - 2) In CX, the entries offset in the LBA address (in bytes)
getFileEntry:
  push bp                         ; Save stack frame
  mov bp, sp                      ; 
  sub sp, 27                      ; Allocate memory on the stack

  ; *(bp - 2)     - Buffer segment
  ; *(bp - 4)     - Buffer offset
  ; *(bp - 6)     - File path segment
  ; *(bp - 8)     - File path offset
  ; *(bp - 10)    - Memory from malloc, 1 sector for FAT(segment)
  ; *(bp - 12)    - Memory from malloc, 1 sector for FAT(offset)
  ; *(bp - 14)    - Memory from malloc, the cluster buffer (segment)
  ; *(bp - 16)    - Memory from malloc, the cluster buffer (offset)
  ; *(bp - 17)    - Amount of directories/things in the path
  ; *(bp - 18)    - General counter
  ; *(bp - 20)    - LBA/cluster number
  ; *(bp - 22)    - Old GS segment
  ; *(bp - 24)    - Previous sector offset in FAT
  ; *(bp - 26)    - Offset to the formatted path (which changes) segment is SS
  ; *(bp - 27)    - Amount of directories/things in the path, but this one doesnt change

  mov [bp - 22], gs
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
  mov [bp - 27], al

  mov bx, 11                      ; Multiply by 11
  mul bx                          ; Get the size that the formatted string will have in AX

  add ax, 2                       ; Allocate 2 more bytes, so we wont overwrite local variables (which are on the stack)
  sub sp, ax                      ; Allocate memory for formatted string + 2 bytes
  mov [bp - 26], sp               ; Store beginning of allocated buffer

  ; Allocate memory for 1 sector, thats for reading the FAT
  mov di, gs:[bpb_bytesPerSector] ; Argument for malloc in DI. Allocate soace for 1 sector. Used for storing a sector from FAT
  call malloc                     ; Allocate memory for a sector of FAT

  mov bx, es                      ; Cant perform operations on segments directly, so copy the returned pointers segment to BX
  test bx, bx                     ; Check if the segment is null (malloc will return a null segment if it could not allocate memory)
  jz .err                         ; If null then return an error

  mov [bp - 10], es               ; If not null then store the segment and the offset 
  mov [bp - 12], di               ; Store offset
  
  
  ; Now we call a function that formats the path, and writes the new path to ES:DI
  mov bx, ss                      ; Formatted path buffer segment is SS
  mov es, bx                      ; Get the formatted path buffer segment
  mov di, [bp - 26]               ; Get the formatted path buffer offset

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
  jnz .clusterMallocSuccess       ; If not null then continue

  ; If null, then free the memory we allocated for the formatted path, and then return
  mov es, [bp - 10]               ; Get allocated sector pointer
  mov di, [bp - 12]               ; Get offset
  call free                       ; Free the memory
  jmp .err                        ; Return a general error

.clusterMallocSuccess:
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
  jnz .freeAndRet                     ; If it did then return an error

  ; Load a pointer to the formatted string, and to the file name, then compare 11 bytes
  mov bx, ss
  mov ds, bx                          ; Get pointer to the formatted string
  mov si, [bp - 26]                   ; Get offset

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
  jmp .freeAndRet                     ; Return

.foundFirstEntry:
  ; Will get here when we find the first directory in the root directory
  dec byte [bp - 17]                  ; Decrement the amount of directories to read
  jz .lastDir_copy                    ; If its zero, then copy it to the destination buffer and return 

  ; If not zero, then check if the entry is a directory entry, because we will need to use it as a directory
  test byte es:[di + 11], FAT_F_DIRECTORY   ; Check directory flag
  jnz .isDir                                ; If set then continue

  ; If not a directory then free used memory and return
  mov ax, ERR_NOT_DIRECTORY           ; Error code if not a directory
  jmp .freeAndRet                     ; Free used memory and return

.isDir:
  add word [bp - 26], 11              ; Increase formatted string pointer to point to next path part (the next directory/file)
  mov di, es:[di + 26]                ; Get the file/directories first cluster number
  mov [bp - 20], di                   ; Store the cluster number
  mov word [bp - 24], 0FFFFh          ; Reset previous FAT offset (So if needed, the first time that we need to read FAT we will read it)
.nextCluster:
  call clusterToLBA                   ; When getting here the cluster number is in DI, convert it to an LBA address
  mov di, ax                          ; Argument goes in DI (the LBA)
  mov al, gs:[bpb_sectorPerCluster]   ; We want a read a cluster (the amount of sectors in a cluster) (8 bits)
  xor ah, ah                          ; Zero out high part
  mov si, ax                          ; Amount of sectors to read goes in SI
  mov es, [bp - 14]                   ; Get pointer to the cluster buffer
  mov bx, [bp - 16]                   ; Get offset
  call readDisk                       ; Read the first cluster of the file/directory into the buffer (ES:DI)
  test ax, ax                         ; Check return value (error code)
  jnz .freeAndRet                     ; If there was an error then return with it

  ; Calculate the amount of bytes in a cluster, then divide it by 32 to get the amount of entries to search in for the file
  mov ax, gs:[bpb_bytesPerSector]     ; Get amount of bytes in a sector
  mov bl, gs:[bpb_sectorPerCluster]   ; Get amount of sectors in a cluster (8 bits)
  xor bh, bh                          ; Zero out high part
  mul bx                              ; res = bytesInSector * sectorsPerCluster
  shr ax, 5                           ; Divide by 32 (log2(32) == 5)
  mov dx, ax                          ; Use counter in DX

  mov es, [bp - 14]                   ; Get cluster buffer pointer (segment)
  mov di, [bp - 16]                   ; Get cluster buffer offset

  mov bx, ss                          ; 
  mov ds, bx                          ; Get formatted file path segment
  mov si, [bp - 26]                   ; Get offset, which changes on every directory (+11 bytes each time)

  ; Here we compare the first 11 bytes of an entry to the formatted file path (the current directory in it), 
  ; to know if its the entry for the file/directory
.nextEntry:
  mov cx, 11                          ; Compare 11 bytes
  cld                                 ; Clear direction flag so CMPSB will increase DI and Si each time
  push si                             ; Save path pointer
  push di                             ; Save cluster buffer pointer
  repe cmpsb                          ; Compare both strings from DS:SI to ES:DI
  pop di                              ; Restore buffer pointer
  pop si                              ; Restore path pointer
  je .foundPathPartEntry              ; If they are equal, continue

  add di, 32                          ; If not equal, increase cluster pointer to point to the next entry
  dec dx                              ; Decrement entries left counter
  jnz .nextEntry                      ; If zero then load the next cluster (Read the next cluster number from FAT, etc..)

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;
  mov ax, [bp - 20]                   ; Get the current CLUSTER number
  mov bx, gs:[bpb_bytesPerSector]     ; Get amount of bytes in 1 sector
  xor dx, dx                          ; Zero out remainder register
  div bx                              ; Divide current cluster number by amount of bytes in a sector

  ; New sector offset will be in AX, check if its the same as the previous one. 
  ; If it is, then there is no need to read the same FAT sector once again
  cmp ax, [bp - 24]                   ; Check if the new FAT offset is the same as the previous one
  je .afterFATread                    ; If it is, then skip reading the FAT again

  ; If the offsets are not the same, prepare for reading a sector of FAT
  mov [bp - 24], ax                   ; Store new FAT offset
  mov di, gs:[bpb_reservedSectors]    ; Get the first sector of FAT
  add di, ax                          ; Add to it the new offset
  mov si, 1                           ; Read one sector

  mov es, [bp - 10]                   ; Get sector buffer segment
  mov bx, [bp - 12]                   ; Get sector buffer offset
  push dx                             ; Store the cluster index
  call readDisk                       ; Read 1 sector of FAT into sector buffer
  pop dx                              ; Restore cluster index
  test ax, ax                         ; Check if readDisk returned an error
  jnz .freeAndRet                     ; If it did, then return with it

.afterFATread:
  mov es, [bp - 10]                   ; Get sector buffer segment
  mov di, [bp - 12]                   ; Get sector buffer offset

  shl dx, 1                           ; Multiply cluster index by 2, because each cluster number in FAT is 2 bytes
  add di, dx                          ; Add the cluster index to the buffer, so ES:DI points to the next cluster number (FAT[idx])
  
  mov di, es:[di]                     ; Get the new cluster number

  mov [bp - 20], di                   ; Store the cluster number
  
  cmp di, 0FFF8h                      ; Check if its the end of the cluster chain
  jb .nextCluster                     ; If not, go and process the new cluster and continue searching for files/directories

  ; If its the end of the cluster chain then return an error of "file not found"
  mov ax, ERR_FILE_NOT_FOUND          ; Return with an error code of file not found
  jmp .freeAndRet                     ; Free used memory and return

.foundPathPartEntry:
  dec byte [bp - 17]                  ; Decrement the amount of directories to read
  jz .lastDir_copy                    ; If its zero, then copy it to the destination buffer and return 

  ; If not zero, then check if the entry is a directory entry, because we will need to use it as a directory
  test byte es:[di + 11], FAT_F_DIRECTORY   ; Check directory flag
  jnz .isDir                                ; If set then continue

  ; If not a directory then free used memory and return
  mov ax, ERR_NOT_DIRECTORY           ; Error code if not a directory
  jmp .freeAndRet                     ; Free used memory and return 

.lastDir_copy:
  ; When getting here, a pointer to the directory entry should be in ES:DI
  ; Copy the entry to the given buffer (the parameter), and return with no error

  mov ax, di                          ; Get a pointer to the entry in AX (the offset)
  sub ax, [bp - 16]                   ; Subtract from it the cluster buffer offset, to get the offset into the LBA
  push ax                             ; Save the offset in the LBA

  mov bx, es                          ; Set DS to ES, because copying from DS to ES
  mov ds, bx                          ;
  mov si, di                          ; Set SI to DI (same reason)

  mov es, [bp - 2]                    ; Get the requested buffer pointer
  mov di, [bp - 4]                    ; Get offset
  mov dx, 32                          ; Copy 32 bytes (the size of a directory entry)
  call memcpy                         ; Copy

  xor ax, ax                          ; Return with error 0 (no error)
  mov bx, [bp - 20]                   ; Get the LBA/cluster number
  pop cx                              ; Restore offset in LBA
  jmp .freeAndRet                     ; Free allocated memory and return

;;;;;;; TODO free malloced memory (not doing it for now, but i will)
.err:
  mov ax, ERR_GET_FILE_ENTRY          ; Give a general error
  jmp .end                            ; Return

  ; Jump here with the error code in AX, the LBA of the entry in BX, and the offset in the LBA for the entry in CX
.freeAndRet:
  push ax                             ; Save error code
  push cx                             ; Save byte offset in LBA
  push bx                             ; Save cluster/LBA
  
  mov es, [bp - 10]                   ; Get pointer to the allocated sector
  mov di, [bp - 12]                   ; Get offset
  call free                           ; Free memory

  mov es, [bp - 14]                   ; Get pointer to cluster buffer
  mov di, [bp - 16]                   ; Get offset
  call free                           ; Free memory

  cmp byte [bp - 27], 1               ; Check the amount of path parts (if its one, then BX was an LBA and there is no need to convert it)
  je .getLBA                          ; If it is 1 then skip converting to LBA

  pop di                              ; If there is more than one path parts, then BX was the cluster number. Get the cluster number
  call clusterToLBA                   ; Convert it into an LBA address
  push ax                             ; Save the result

.getLBA:
  pop bx                              ; Restore LBA
  pop cx                              ; Restore byte offset in the LBA
  pop ax                              ; Restore error code

.end:
  mov gs, [bp - 22]                   ; Restore old GS segment
  mov es, [bp - 2]                    ; Restore ES segment
  mov ds, [bp - 6]                    ; Restore DS segemnt
  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  ret