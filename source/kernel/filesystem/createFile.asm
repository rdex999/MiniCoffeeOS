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
  sub sp, 22                            ; Allocate memory on the stack for local variables

  ; *(bp - 2)     - Buffer segment
  ; *(bp - 4)     - Buffer offset
  ; *(bp - 6)     - Paths segment
  ; *(bp - 8)     - Paths offset
  ; *(bp - 10)    - Formatted string offset (segment is SS)
  ; *(bp - 11)    - Formatted string length
  ; *(bp - 13)    - Sector buffer offset (segment is SS)
  ; *(bp - 15)    - Current LBA in root directory, or the offset from the first cluster (if the file is not from the root directory)
  ; *(bp - 16)    - Sectors left in root directory, or sectors left in current cluster of directory
  ; *(bp - 17)    - Flags, for the new file
  ; *(bp - 18)    - The first character of the final file name (because changing it to null)    // TODO: GET RID OF THIS
  ; *(bp - 20)    - Unformatted string copy buffer offset (segment in SS)
  ; *(bp - 22)    - Current cluster number in directory

  mov [bp - 2], es                      ; Store buffers segment
  mov [bp - 4], di                      ; Store buffers offset
  mov [bp - 6], ds                      ; Store paths segment
  mov [bp - 8], si                      ; Store paths offset
  mov [bp - 17], dl

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
.searchEmpty:
  cmp byte ss:[di], 0                   ; If the first byte of the entry is 0, then the entry is free. Check if the current entry if free
  je .initEmptyEntry                    ; If it is free then jump
  add di, 32                            ; If not free then increase the sector buffer pointer to point to the next entry
  sub cx, 32                            ; Decrement entries counter (how many are left)
  jnz .searchEmpty                      ; As long as the entry counter is not zero continue searching

  ; If the entry counter has reached 0, then increase the LBA, and decrement the amount of sectors left to read in the root directory
  inc word [bp - 15]                    ; Increase current LBA
  dec byte [bp - 16]                    ; Decrement sectors left to read in the root directory
  jnz .rootDirNextSector                ; If its not zero then jump and load the next sector of the root directory

.errDiskFull:
  mov ax, ERR_DISK_FULL                 ; If the disk is full, we return an error for it
  jmp .end                              ; Return with the error

.initEmptyEntry:
  ; When getting here, the empty entry should be pointed to by SS:DI
  ; Now we want to copy the filename to the files entry
  mov bx, ss                            ; Both the filename and the file entry are on the stack, so both ES and DS are set to SS
  mov es, bx                            ; Set ES = SS
  mov ds, bx                            ; Set DS = SS

  mov al, [bp - 11]                     ; Get the size of the formatted path
  xor ah, ah                            ; Zero out high 8 bits
  mov si, [bp - 10]                     ; Get a pointer to the file name (the source)
  add si, ax                            ; Add the size of the formatted path to the formatted path pointer, to get to the last character
  sub si, 11                            ; Subtract 11 from it so we get to the first byte of the actual file name

  mov dl, [bp - 17]                     ; Get the requested flags for the new file
  push di                               ; Save entry pointer
  call createFile_initEntry             ; Initialize the entry with the current time, clusters and stuff
  pop si                                ; Restore entry pointer
  test ax, ax                           ; Check error code
  jnz .end                              ; If there was an error return with it

  cmp word [bp - 2], 0                  ; If the given buffer segment is null, dont copy the entry into it
  je .afterMemcpy                       ; If null skip copying the entry into it

  mov es, [bp - 2]                      ; If not null, get a pointer to the buffer
  mov di, [bp - 4]                      ; Get offset

  mov dx, 32                            ; Amount of bytes to copy, the size of an entry (which is 32 bytes)
  call memcpy                           ; Copy the entry into the given buffer

.afterMemcpy:
  ; Now we need to write out changes (to the sector) to the disk
  ; so prepare arguments for writeDisk, and write the changes
  mov bx, ss                            ; Set DS:SI to the start of the sector buffer
  mov ds, bx                            ; Set DS to SS because the sector buffer is stored on the stack
  mov si, [bp - 13]                     ; Set SI to the sector buffer offset

  mov di, [bp - 15]                     ; Set DI to the LBA
  mov dx, 1                             ; Amount of sectors to write, write one sector
  call writeDisk                        ; Write out changes to the sector, to the hard disk
  test ax, ax                           ; Check error code of writeDisk
  jnz .end                              ; If there was an error, then return with it

  xor ax, ax                            ; If there was no error, then return 0
  jmp .end                              ; Return

.notOnRootDir:
  ; Here we need to get the first cluster of the directory of the file. Meaning, if the path is (folder/fld/file.txt)
  ; Then the directory of the file is folder/fld
  ; We need to get its cluster so we search the directory for an empty entry, then initialize a file there.
  ; We get the directory of the file by searching for the last '/' in the files path (then copy it to a seperate buffer, until that '/')
  mov es, [bp - 6]                      ; Get unformatted file path segment
  mov di, [bp - 8]                      ; Get unformatted file path offset
.searchLestFolder:
  cmp byte es:[di], '/'                 ; Check if the current character in the path is a '/'
  jne .notDirSeparator                  ; If not, then skip the next line

  mov si, di                            ; If it is a '/', then save a pointer to it in SI

.notDirSeparator:
  cmp byte es:[di], 0                   ; Check if the current character is a null character
  je .afterFindLastDir                  ; If it is then exit out of the loop

  inc di                                ; If not a null, increment the string pointer to point to the next character
  jmp .searchLestFolder                 ; Continue searching the path for '/'

.afterFindLastDir:
  ; When getting here ES:SI will point to the last '/' in the path
  mov dx, si                            ; Get the pointer in DX
  sub dx, [bp - 8]                      ; Subtract from it the beginning of the string, to get the length of the string until the last '/'

  sub sp, dx                            ; Allocate space for the copy of the path 
  dec sp                                ; Allocate one more byte for the null character
  mov [bp - 20], sp                     ; Store a pointer to the beginning of the buffer

  ; Now we have the length of the path until the last '/' in DX
  ; so we want to copy the path into the new buffer.
  ; Prepare arguments for memcpy.
  mov ds, [bp - 6]                      ; Get a pointer to the beginning of the unformatted path
  mov si, [bp - 8]                      ; Get offset

  mov bx, ss                            ; Get a pointer to the beginning of the allocated buffer
  mov es, bx                            ; Set segment
  mov di, sp                            ; Set offset
  push dx                               ; Save the length of the new path
  call memcpy                           ; Copy the unformatted path to the buffer, until the last '/'
  pop dx                                ; Restore length of new path

  add di, dx                            ; Add the length to the buffer pointer, to get a pointer to the last character +1
  mov byte es:[di], 0                   ; Null terminate the new path

  sub sp, 32                            ; Allocate a buffer for the entry of the directory
  mov di, sp                            ; Get a pointer to the beginning of the buffer

  mov bx, ss                            ; Set both ES and DS to SS, because both the path and the buffer are on the stack
  mov ds, bx                            ; Set DS = SS
  mov es, bx                            ; Set ES = SS
  mov si, [bp - 20]                     ; Get a pointer to the new path
  call getFileEntry                     ; Get the directories entry and store it on the stack (the allocated 32 byte buffer)
  test ax, ax                           ; Check error code
  jnz .end                              ; If there was an error then return with it

  mov si, sp                            ; Get a pointer to the directories entry
  mov di, ss:[si + 26]                  ; Get the directories first cluster number
  add sp, 32                            ; Free the allocated space, we dont need it anymore

  mov [bp - 22], di                     ; Store the first cluster number

  mov bx, KERNEL_SEGMENT                ; Set DS to the kernel segment so we can access stuff
  mov ds, bx                            ;

  sub sp, ds:[bpb_bytesPerSector]       ; Allocate space for 1 sector on the stack
  mov [bp - 13], sp                     ; Store buffer pointer

  mov word [bp - 15], 0                 ; Initialize offset from the cluster to 0
.searchEmptyInDir_readSector:
  mov bx, ss                            ; Reset ES to stack segment, for the buffers
  mov es, bx                            ;

  mov di, [bp - 13]                     ; Get a pointer to the sector buffer
  mov si, [bp - 22]                     ; Get the folders first cluster number
  mov dx, [bp - 15]                     ; Get the offset at which to read from the folder (it grows by sizeof(sector) each time)
  mov cx, ds:[bpb_bytesPerSector]       ; Amount of bytes to read   // 1 sector
  call readClusterBytes                 ; Read 1 sector of the folder into the sector buffer
  test bx, bx                           ; Check error code
  jz .prepSearchEmptySector             ; If there was no error, skip the next few lines

  cmp bx, ERR_EOF_REACHED               ; Check if the error is because we reached the end of the cluster chain
  je .increaseClusterChain              ; If it is, add one more cluster to the folders cluster chain

  mov ax, bx                            ; If its not the case, return with the error code
  jmp .end                              ; Return

.increaseClusterChain:
  mov di, [bp - 22]                     ; Get the first cluster of the directory
  mov si, 1                             ; Set the amount of clusters to add
  call addClusters                      ; Add 1 cluster to the directories cluster chain
  test ax, ax                           ; Check error code of addClusters
  jnz .searchEmptyInDir_readSector      ; If there was no error, read the cluster once again with the offset (and this time it should work)

  mov ax, ERR_DISK_FULL                 ; If there was an error, then return ERR_DISK_FULL as the error code
  jmp .end                              ; Return

.prepSearchEmptySector:
  mov di, [bp - 13]                     ; Get a pointer to the beginning of the sector buffer
  mov cx, ax                            ; Get the size of a sector (returned by readClusterBytes) will be used to determin when to load the next sector
.searchEmptyInSector:
  cmp byte es:[di], 0                   ; Check if the first byte of the entry is 0
  je .foundEmptyInDir                   ; If it is then we found an empty entry (jump)

  add di, 32                            ; If the first byte of the entry wasnt 0, increase the buffer pointer to point to the next entry
  sub cx, 32                            ; Decrement amount of bytes left to read in the current sector
  jnz .searchEmptyInSector              ; As long as its not 0, continue reading the sector

  ; If the current sector of the directory didnt have an empty entry, we want to increase the cluster read offset
  ; so readClusterBytes will read the next sector of the directory
  mov ax, ds:[bpb_bytesPerSector]       ; Get the size of a sector
  add [bp - 15], ax                     ; Increase cluster read offset by the size of a sector

  jmp .searchEmptyInDir_readSector      ; Continue and read another sector of the directory into the sector buffer

.foundEmptyInDir:
  mov bx, ss                            ; Set DS to the stack segment so we can access buffers and stuff
  mov ds, bx                            ;

  mov al, [bp - 11]                     ; Get the size of the formatted path (so we can get to the files name)
  xor ah, ah                            ; Zero out high 8 bits
  mov si, [bp - 10]                     ; Get a pointer to the beginning of the formatted path
  add si, ax                            ; Add to it the size of the path, so we get to the last character of the path
  sub si, 11                            ; Decrement the pointer by 11, so now were at the beginning of the actual file name (like file.txt)

  mov dl, [bp - 17]                     ; Get the requested flags for the file
  push di                               ; Save entry pointer
  call createFile_initEntry             ; Write the date & time of the creation to the files entry, as well as a first cluster and stuff
  pop di                                ; Restore entry pointer
  test ax, ax                           ; Check error code
  jnz .end                              ; If there was an error, return with it

  cmp word [bp - 2], 0                  ; Check if the given buffer segment is null
  je .afterDirMemcpy                    ; If it is, then dont copy the entry into it

  ; After we have initialized the entry, we want to copy it into the requested buffer
  mov si, di                            ; Set the source pointer to the entry pointer (from where to copy the data)

  mov es, [bp - 2]                      ; Get a pointer to the requested buffer (where to copy the entry to)
  mov di, [bp - 4]                      ; Get offset

  mov dx, 32                            ; Amount of bytes to copy, the size of an entry (32 bytes)
  call memcpy                           ; Copy the entry into the given buffer

.afterDirMemcpy:
  push ds                               ; Save DS segment, because we need to change it for a sec
  mov bx, KERNEL_SEGMENT                ; Set DS to the kernels segment
  mov ds, bx                            ;
  mov cx, ds:[bpb_bytesPerSector]       ; Set CX (argument for writeClusterBytes) to the amount of bytes in a sector
  pop ds                                ; Restore DS

  mov di, [bp - 22]                     ; Get the first cluster of the directory
  mov si, [bp - 13]                     ; Get a pointer to the beginning of the sector buffer (the source, from where to write the data)
  mov dx, [bp - 15]                     ; Get the bytes offset (which is a multiple of sizeof(sector)) so we write to the currect sector of the directory
  call writeClusterBytes                ; Write our changes to the directory (only the empty entry), to the hard disk

  xor ax, ax                            ; Return with error code 0 (no error)
.end:
  mov es, [bp - 2]                      ; Restore used segments
  mov ds, [bp - 6]                      ;
  mov sp, bp                            ; Restore stack frame
  pop bp                                ;
  ret



; A sub-funciton of create file.
; PARAMS
;   - 0) ES:DI    => The FAT entry
;   - 1) DS:SI    => The formatted 11 byte file name
;   - 2) DL       => Flags for the file
; RETURNS
;   - 0) The error code in AX, 0 on success
createFile_initEntry:
  push dx
  mov dx, 11                            ; Copy 11 bytes (the size of a file name)
  call memcpy                           ; Copy the file name to the files entry (DI already set)

  pop ax                                ; Get the requested file flags
  mov es:[di + 11], al                  ; Set the files flags in its entry

  ; Note: Skipping byte on offset 12 (some stuff for Windows NT)
  ;       And also byte at offset 13 (creation time in hundredths of a second)
  push ds                               ; Save DS, because were gonna change it
  mov bx, KERNEL_SEGMENT                ; Set DS to kernel segment so we can access sysTime
  mov ds, bx                            ;

  ; Update the files creation time (hours, minutes, seconds) 
  mov al, ds:[sysClock_seconds]         ; Get the current seconds
  shr ax, 1                             ; Divide it by 2 (the seconds are 5 bits, and 5 bits can hold a maximum value of 31)
  and ax, 0001_1111b                    ; Remove all other bits, and leave the first 5 (which are the seconds) (seconds: bits 0-4)

  mov bl, ds:[sysClock_minutes]         ; Get the current minute
  xor bh, bh                            ; Zero out high 8 bits
  shl bx, 5                             ; Shift left by 5 bits because minutes are starting from bit 5 (minuts: bits 5-10)
  or ax, bx                             ; Get minutes starting from bit 5 in the result register (AX will hold the final creation time)

  mov bl, ds:[sysClock_hours]           ; Get the current hour
  xor bh, bh                            ; Zero out high 8 bits
  shl bx, 5 + 6                         ; Shift left by the size of the seconds + the size of minuts (in bits) (hours: bits 11-15)
  or ax, bx                             ; Get current hour in result register

  mov es:[di + 14], ax                  ; Update the creation time of the file (in hours, minutes, and seconds)
  mov es:[di + 22], ax                  ; Set last modification time, same as the creation time

  ; Now we want to update the files creation date (year, month, day)
  mov al, ds:[sysClock_day]             ; Get current day (in month)
  and ax, 0001_1111b                    ; Clear all bits except the bits of the dat (bits 0-4)

  mov bl, ds:[sysClock_month]           ; Get current month number
  xor bh, bh                            ; Zero out high 8 bits
  shl bx, 5                             ; Shift left by 5 bits (month: bits 5-8)
  or ax, bx                             ; Get month in result register

  mov bl, ds:[sysClock_year]            ; Get current year
  xor bh, bh                            ; Zero out high 8 bits
  shl bx, 5 + 4                         ; Shift left by 9 bits (year: bits 9-15)
  or ax, bx                             ; Get current year in result register

  pop ds                                ; Restore DS, we no longer need to kernel segment

  mov es:[di + 16], ax                  ; Write the creation time to the file entry
  mov es:[di + 18], ax                  ; Set last accessed date, same as the creation date
  
  mov word es:[di + 20], 0              ; High 8 bits of the first cluster number are always 0
  mov es:[di + 24], ax                  ; Set last modification date, same as the creation date
  
  push di                               ; Save empty entry pointer
  mov di, 0FFF8h                        ; We want to initialize the first cluster to an end
  call getFreeCluster                   ; Get a free cluster, and initialize the next one to an end of the cluster chain
  pop di                                ; Restore empty entry pointer
  test ax, ax                           ; Check error code of getFreeCluster
  jz .errDiskFull                       ; If there was an error, then return an error of ERR_DISK_FULL

  mov es:[di + 26], ax                  ; Set the files first cluster number

  mov word es:[di + 28], 0              ; Set the files size, low 16 bits
  mov word es:[di + 30], 0              ; Set the files size, high 16 bits

  xor ax, ax                            ; Return 0 on success

.end:
  ret

.errDiskFull:
  mov ax, ERR_DISK_FULL
  ret

%endif