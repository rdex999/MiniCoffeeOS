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
  sub sp, 18

  ; *(bp - 2)   - Old GS segment
  ; *(bp - 4)   - File name segment
  ; *(bp - 6)   - File name offset
  ; *(bp - 8)   - Old DS segment
  ; *(bp - 10)  - Formatted path offset (segment is SS), or the offset of the copy of the path (if the file is not on the root directory)
  ; *(bp - 11)  - Formatted path length
  ; *(bp - 13)  - Current LBA in root directory or the current bytes offset (if the file is not on the root directory)
  ; *(bp - 14)  - Amount of sectors left to read from the root directory
  ; *(bp - 16)  - Sector buffer offset
  ; *(bp - 18)  - The files first cluster number

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

.errInBX:
  mov ax, bx                                  ; Get the error code in AX
  jmp .end                                    ; Return

.filePathSuccess:
  mov bx, KERNEL_SEGMENT                      ; Set both DS and GS to the kernels segment
  mov ds, bx                                  ; Set DS because we need GET_ROOT_DIR_OFFSET to work
  mov gs, bx                                  ; And GS will be used later for variables and shit

  GET_ROOT_DIR_OFFSET                         ; Get the LBA of the root directory
  mov [bp - 13], ax                           ; Store it as the current LBA in the root directory

  GET_ROOT_DIR_SIZE                           ; Get the size of the root directory
  mov [bp - 14], al                           ; Store it as a counter for how many sectors are left to read

  sub sp, ds:[bpb_bytesPerSector]             ; Allocate space for 1 sector
  mov [bp - 16], sp                           ; Store the sector buffer pointer

.searchRootDirLoop:
  mov bx, ss                                  ; Set destination, where to store the data (the sector buffer)
  mov es, bx                                  ; Set segment
  mov bx, [bp - 16]                           ; Set offset

  mov di, [bp - 13]                           ; Get the current LBA in the root directory (from where to read the data)
  mov si, 1                                   ; Amount of sectors to read
  call readDisk                               ; Read 1 sector of the root directory into the sector buffer
  test ax, ax                                 ; Check error code
  jnz .end                                    ; If there was an error return with it

  ; After we read 1 sector of the root directory, we need to search the sector for the file
  mov bx, ss                                  ; Get a pointer to the sector buffer
  mov es, bx                                  ; Get segment
  mov di, [bp - 16]                           ; Get offset
  mov dx, gs:[bpb_bytesPerSector]             ; Get the amount of bytes in a sector, so we know when to stop searching (will be decremented by the size of an entry)
.searchRootSector:
  mov bx, ss                                  ; Get a pointer to the formatted file name
  mov ds, bx                                  ; Get segment
  mov si, [bp - 10]                           ; Get offset
  mov cx, 11                                  ; Set amount of bytes to compare
  cld                                         ; Clear direction flag so CMPSB will increment DI and SI each time
  push di                                     ; Save current sector buffer pointer (current entry pointer)
  repe cmpsb                                  ; Compare the entries filename to the requested file name
  pop di                                      ; Restore buffer pointer
  je .foundInRootDir                          ; If the file names are equal then we found the file, jump to the handler

  add di, 32                                  ; If its not the file, increase the entry pointer to point to the next entry
  sub dx, 32                                  ; Decrement amount of entries left to read
  jnz .searchRootSector                       ; As long as its not zero continue searching the sector

  inc word [bp - 13]                          ; If there are no more entries to read, increase the LBA
  dec byte [bp - 14]                          ; Decrement amount of sectors left to read in the root directory
  jnz .searchRootDirLoop                      ; If its not zero, read the next sector of the root directory into the sector buffer

  mov ax, ERR_FILE_NOT_FOUND                  ; If there are no more sectors to read, then the file doesnt exist
  jmp .end                                    ; Return with an error of ERR_FILE_NOT_FOUND

.foundInRootDir:
  mov ax, es:[di + 26]                        ; Get the files first cluster number
  mov [bp - 18], ax                           ; Store the cluster number, so we can mark the whole chain (later) as free

  xor si, si                                  ; The value to set the entry to, null
  mov dx, 32                                  ; Set 32 bytes
  call memset                                 ; Set the entry to 0

  mov bx, ss                                  ; Set the source, from where to write the data.   // Get a pointer to the sector buffer
  mov ds, bx                                  ; Set segment
  mov si, [bp - 16]                           ; Set offset

  mov di, [bp - 13]                           ; Get the LBA to write to (the destination)
  mov dx, 1                                   ; Amount of sectors to write
  call writeDisk                              ; Write the changes we made to the entry, to the hard disk
  test ax, ax                                 ; Check error code
  jnz .end                                    ; If there was an error, return with it

.freeClusters:
  ; When getting here, the files first cluster number should be at *(bp - 18)
  mov di, [bp - 18]                           ; Get the files first cluster number
  cmp di, FAT_CLUSTER_INVALID                 ; Check if its valid
  jae .success                                ; If not, return with 0 because we finished freeing the clusters

  call getNextCluster                         ; Get the next cluster for the current one
  test bx, bx                                 ; Check error code
  jnz .errInBX                                ; If there was an error, return with it

  mov di, [bp - 18]                           ; Get the current cluster number
  mov [bp - 18], ax                           ; Set the current cluster number to the next one
  xor si, si                                  ; The value to set the current cluster to (0 means free)
  call setCluster                             ; Set the current cluster to 0 (mark it as free)
  test ax, ax                                 ; Check error code
  jnz .end                                    ; If there was an error return with it

  jmp .freeClusters                           ; Continue freeing clusters


.notOnRootDir:
  mov word [bp - 13], 0                       ; Set bytes offset 

  mov es, [bp - 4]
  mov di, [bp - 6]
  mov al, '/'
  cld
.searchLastDirLoop:
  scasb 
  jne .charNotDir

  mov si, di

.charNotDir:
  cmp byte es:[di], 0
  jne .searchLastDirLoop


  sub si, [bp - 6]
  sub sp, si
  mov [bp - 10], sp

  mov dx, si
  dec dx

  mov ds, [bp - 4]
  mov si, [bp - 6]

  mov bx, ss
  mov es, bx
  mov di, sp
  push dx
  call memcpy
  pop dx

  add di, dx
  mov byte es:[di], 0

  mov bx, ss
  mov ds, bx
  mov si, [bp - 10]
  mov di, COLOR(VGA_TXT_YELLOW, VGA_TXT_DARK_GRAY)
  call printStr





.success:
  xor ax, ax                                  ; On success, we return 0

.end:
  mov gs, [bp - 2]                            ; Restore used segments
  mov es, [bp - 4]                            ;
  mov ds, [bp - 8]                            ;
  mov sp, bp                                  ; Restore stack frame
  pop bp                                      ;
  ret

%endif