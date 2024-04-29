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
  sub sp, 17                            ; Allocate memory on the stack for local variables

  ; *(bp - 2)     - Buffer segment
  ; *(bp - 4)     - Buffer offset
  ; *(bp - 6)     - Paths segment
  ; *(bp - 8)     - Paths offset
  ; *(bp - 10)    - Formatted string offset (segment is SS)
  ; *(bp - 11)    - Formatted string length
  ; *(bp - 13)    - Sector buffer offset (segment is SS)
  ; *(bp - 15)    - Current LBA in root directory
  ; *(bp - 16)    - Sectors left in root directory
  ; *(bp - 17)    - Flags, for the new file

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
  ; Now we want to copy the filename to the files entry
  mov bx, ss                            ; Both the filename and the file entry are on the stack, so both ES and DS are set to SS
  mov es, bx                            ; Set ES = SS
  mov ds, bx                            ; Set DS = SS

  mov si, [bp - 10]                     ; Get a pointer to the file name (the source)
  mov dx, 11                            ; Copy 11 bytes (the size of a file name)
  call memcpy                           ; Copy the file name to the files entry (DI already set)

  mov al, [bp - 17]                     ; Get the requested file flags
  mov es:[di + 11], al                  ; Set the files flags in its entry

  ; Note: Skipping byte on offset 12 (some stuff for Windows NT)
  ;       And also byte at offset 13 (creation time in hundredths of a second)
  mov bx, KERNEL_SEGMENT                ; Set DS to kernel segment so we can access sysTime
  mov ds, bx                            ;

  ; Update the files creation date (hours, minutes, seconds) 
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

  mov es:[di + 16], ax                  ; Write the creation time to the file entry


.notOnRootDir:
  ; Will get here if the file is from the rrot directory


.end:
  mov es, [bp - 2]                      ; Restore used segments
  mov ds, [bp - 6]                      ;
  mov sp, bp                            ; Restore stack frame
  pop bp                                ;
  ret


%endif