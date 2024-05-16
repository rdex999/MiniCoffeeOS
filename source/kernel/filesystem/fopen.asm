;
; ---------- [ OPEN A FILE FOR A REQUESTED MODE ] ----------
;

%ifndef FOPEN_ASM
%define FOPEN_ASM

; Open a file from the filesystem in a specific mode.
; FILE ACCESS
;   0 Read ("r")
;   1 Write ("w")
;   2 Append ("a")
;   3 Read write, must exist ("r+")
;   4 Create with read Write ("w+")
;   5 Append read ("a+")
; PARAMETERS
;   - 0) ES:DI    => The path to the file, doesnt have to be formatted. Null terminated string.
;   - 1) SI       => Access for the file, low 8 bits only
; RETURNS
;   - 0) In AX, the file handle. A non-zero value on success. (0 on failure) 
;       // Note for me: returns the INDEX into openFiles (index+1)
fopen:
  push bp                                         ; Save stack frame
  mov bp, sp                                      ;
  sub sp, 15 + 32                                 ; Allocate memory on the stack, for local stuff and for the file entry

  ; *(bp - 2)     - File path segment
  ; *(bp - 4)     - Old DS segment
  ; *(bp - 5)     - Requested file access
  ; *(bp - 7)     - Empty slot index (in the openFiles array)
  ; *(bp - 9)     - Files entry buffer offset (segment is SS)
  ; *(bp - 11)    - File path offset
  ; *(bp - 13)    - The files entry LBA
  ; *(bp - 15)    - The files entry offset in the LBA

  mov [bp - 9], sp                                ; Store FAT buffer pointer (32 bytes)
  mov [bp - 2], es                                ; The files path segment
  mov [bp - 4], ds                                ; Save used segments
  mov ax, si                                      ; Save low 8 bits of the requested file access
  mov [bp - 5], al                                ;
  mov [bp - 11], di                               ; The files path offset

  cmp word es:[di], '/' & 0FFh                    ; Check if the requested file is the root directory
  jne .afterRootDirFlag                           ; If not, process and open the file normaly

  mov bx, KERNEL_SEGMENT                          ; Set DS to the kernels segment so we can access the openFiles array
  mov ds, bx                                      ;
  lea si, openFiles                               ; Get a pointer to openFiles
  mov cx, FILE_OPEN_LEN                           ; Amount of files in openFiles
  mov bx, 0FFFFh                                  ; Empty slot index, initialize as 0FFFFh (as not found)
.searchEmptyForRoot:
  ; if(openFiles[i].fatEntry.cluster == 0 && openFiles[i].entryLBA != 0) { *** file is closed; ***}
  cmp word ds:[si + FILE_OPEN_ENTRY256 + 26], 0   ; Check if the current file descriptor first cluster is 0
  jne .afterFreeCheck                             ; If not, then the file used

  cmp word ds:[si + FILE_OPEN_ENTRY_LBA16], 0     ; If the cluster number is zero, check if the LBA of the files entry is 0
  jne .err                                        ; If its not zero, then the root directory is already open

  cmp bx, 0FFFFh                                  ; Check if we already found a free descriptor
  jne .afterFreeCheck                             ; If a free descriptor was already found, dont set it again

  mov bx, cx                                      ; Set BX to the amount of descriptors left (will be used to calculate the handle)
  mov di, si                                      ; Set DI to point to the free descriptor

.afterFreeCheck:
  add si, FILE_OPEN_SIZEOF                        ; Increase descriptor pointer to point to the next entry
  loop .searchEmptyForRoot                        ; Continue searching

  cmp bx, 0FFFFh                                  ; Check if a free entry was found
  je .err                                         ; If there is no free file descriptor, return null

  mov al, [bp - 5]                                ; Get the requested file access
  mov ds:[di + FILE_OPEN_ACCESS8], al             ; Set it

  mov word ds:[di + FILE_OPEN_POS16], 0           ; Set the position in the file to 0
  mov word ds:[di + FILE_OPEN_ENTRY_LBA16], 1     ; Indicate the file is open as the root directory
  mov ax, FILE_OPEN_LEN + 1                       ; Get the amount of files in openFiles
  sub ax, bx                                      ; Subtract the amount left from the free descriptor, to get the file handle

  jmp .end                                        ; Return the file handle


.afterRootDirFlag:
  cmp si, FILE_OPEN_ACCESS_WRITE                  ; Check if the requested access is WRITE, in which we delete and create the file again
  je .handleWriteAccess                           ; If it is WRITE then handle it

  cmp si, FILE_OPEN_ACCESS_WRITE_PLUS             ; Check if the requested access is WRITE_PLUS, in which we delete and create the file again 
  je .handleWriteAccess                           ; If it is WRITE_PLUS then handle it

  cmp si, FILE_OPEN_ACCESS_APPEND                 ; Check if the requested access is APPEND, in which we create the file if it doesnt
  je .createIfDoesntExist                         ; exist. If it is APPEND, handle it

  cmp si, FILE_OPEN_ACCESS_APPEND_PLUS            ; Check if the requested access is APPEND_PLUS, in which we delete and create the file again 
  je .createIfDoesntExist                         ; If it is APPEND_PLUS, handle it

.afterHandleAccess:
  ; Prepare arguments for getFileEntry, and read the file entry into the stack
  mov ds, [bp - 2]                                ; Because getFileEntry wants the filename in DS:SI
  mov si, [bp - 11]                               ; SI = DI

  mov bx, ss                                      ; Set ES:DI = SS:SP
  mov es, bx                                      ; Because we will store the entry on the stack, and SP already points
  mov di, [bp - 9]                                ; to the allocated memory on the stack

  call getFileEntry                               ; Get the files FAT entry and store it on the stack
  test ax, ax                                     ; Check error code of getFileEntry
  jnz .err                                        ; If there was an error we return null

  mov [bp - 13], bx                               ; Store the entries LBA address
  mov [bp - 15], cx                               ; Store the entries bytes offset in the LBA address

  mov si, [bp - 9]                                ; Entry stored on the stack
  mov ax, ss:[si + 26]                            ; Get first cluster number


  ; Search the openFiles array for an unused slot for the file.
  ; Also check if there is a file in the array with the same cluster number of this one.
  ; If there is such file then it means that the file is already open
  xor cx, cx                                      ; Zero out current index in openFiles
  mov bx, KERNEL_SEGMENT                          ; Set ES to kernel segment so we can access openFiles
  mov es, bx                                      ;
  lea di, [openFiles]                             ; Get a pointer to the start of the openFiles array
  mov bx, 0FFFFh                                  ; BX will hold the empty slot index. Initialize as an invalid one
.searchEmptySlot:
  cmp es:[di + FILE_OPEN_ENTRY256 + 26], ax       ; Check if the current file has the same cluster number as the requested one
  je .err                                         ; If its the same then return null

  cmp bx, 0FFFFh                                  ; Check if the empty slot index was set
  jne .afterSetIdx                                ; If it was set, then dont check for an empty slot

  ; If the empty slot index wasnt set yet, then check if the current file is empty.
  ; If it is then set the empty slot index, and set a pointer to the empty file slot
  cmp word es:[di + FILE_OPEN_ENTRY256 + 26], 0   ; Check if the files first cluster number is zero.
  jne .afterSetIdx                                ; If not zero then skip setting the found index

  cmp word es:[di + FILE_OPEN_ENTRY_LBA16], 0
  jne .afterSetIdx

  mov bx, cx                                      ; If the slot if empty, then copy its index (CX) to BX
  mov dx , di                                     ; Make DX point to the empty slot

.afterSetIdx:
  add di, FILE_OPEN_SIZEOF                        ; Make current slot pointer point to the next file slot

  inc cx                                          ; Increase slot index
  cmp cx, FILE_OPEN_LEN                           ; Check if there are more slots to check
  jb .searchEmptySlot                             ; If there is, then continue searching

  ; Will get here after we scan the whole array
  cmp bx, 0FFFFh                                  ; Check if an empty slot was found    
  je .err                                         ; If not then return with null

  ; Will get here if we found an empty slot, and the file is not open
.foundEmpty:
  mov [bp - 7], bx                                ; Save empty slot index
  mov di, dx                                      ; Get a pointer to the empty slot

  mov ax, [bp - 13]                               ; Get the entries LBA address
  mov es:[di + FILE_OPEN_ENTRY_LBA16], ax         ; Save it in the file descriptor

  mov ax, [bp - 15]                               ; Get the entries bytes offset in the LBA address
  mov es:[di + FILE_OPEN_ENTRY_OFFSET16], ax      ; Save it in the file descriptor

  mov al, [bp - 5]                                ; Get requested file access
  mov es:[di + FILE_OPEN_ACCESS8], al             ; Set files access

  cmp al, FILE_OPEN_ACCESS_APPEND                 ; Check if the requested access is APPEND (in which, the position is the end of the file)
  je .setPosEnd                                   ; If it is then set the current position to the end of the file

  cmp al, FILE_OPEN_ACCESS_APPEND_PLUS            ; Check if the requested access is APPEND_PLUS
  je .setPosEnd                                   ; If it is then set the current position to the end of the file
  
  mov word es:[di + FILE_OPEN_POS16], 0           ; If its not append, initialize the files current read position to 0
  jmp .afterSetPos                                ; skip APPEND access handler

.setPosEnd:
  mov si, [bp - 9]                                ; Get a pointer to the files FAT entry
  mov ax, ss:[si + 28]                            ; Get the files size
  mov es:[di + FILE_OPEN_POS16], ax               ; Initialize the files current read position to the end of the file

.afterSetPos:
  add di, FILE_OPEN_ENTRY256                      ; Add to the pointer the offset of the FAT entry, as we want to copy to it
  mov si, [bp - 9]                                ; Get a pointer to the FAT entry (from where to copy DS:SI)
  mov bx, ss                                      ; Set DS:SI => FAT entry
  mov ds, bx                                      ; FAT entry stored on the stack
  mov dx, 32                                      ; Copy 32 bytes, the size of a FAT entry
  call memcpy                                     ; Copy the FAT entry into the empty file slot in openFiles

  ; Update the files last accessed date 
  mov ax, es:[sysClock_day]                       ; Get day in month
  and ax, 0001_1111b                              ; day is 5 bits

  mov bx, es:[sysClock_month]                     ; Get current month
  and bx, 0000_1111b                              ; Month is 4 bits
  shl bx, 5                                       ; Month starts from bit 5
  or ax, bx                                       ; Get month in result register

  mov bx, es:[sysClock_year]                      ; Get current year
  add bx, 20                                      ; Year starts from 20
  shl bx, 5 + 4                                   ; Year starts from bit 9
  or ax, bx                                       ; Get year in result register

  mov es:[di + 18], ax                            ; Write the current date to the files FAT entry
  
  mov cx, [bp - 7]                                ; Get the empty slot index
  mov ax, cx                                      ; Get the files slot index
  inc ax                                          ; Increase by 1 so we dont return 0 for a valid index (0 indicates error)

.end:
  mov es, [bp - 2]                                ; Restore used segments
  mov ds, [bp - 4]                                ;
  mov sp, bp                                      ; Restore stack frame
  pop bp                                          ;
  ret

.err:
  xor ax, ax                                      ; If there is an error we return null
  jmp .end

.handleWriteAccess:
  ; We need to check if the file exists, if it does, delete it and create it again
  mov ds, [bp - 2]                                ; Get a pointer to the files path (DS:SI)
  mov si, [bp - 11]                               ; Get offset

  mov bx, ss                                      ; Set the destination, where to store the files entry (the entry buffer)
  mov es, bx                                      ; Set segment
  mov di, [bp - 9]                                ; Set offset
  call getFileEntry                               ; Get the files entry
  test ax, ax                                     ; Check error code
  jnz .writeAccess_create                         ; If there was an error (which is not wrong) then the file doesnt exist, just create it

  mov es, [bp - 2]                                ; If the file does exist, delete it.  // Get a pointer to the files path
  mov di, [bp - 11]                               ; Get offset
  call remove                                     ; Delete the file

.writeAccess_create:
  mov ds, [bp - 2]                                ; Get a pointer to the files path
  mov si, [bp - 11]                               ; Get offset

  xor bx, bx 
  mov es, bx                                      ; Get segment
  xor di, di 

  xor dx, dx                                      ; Set flags for the new file    // None
  call createFile                                 ; Create the file and save its entry into the entry buffer
  test ax, ax                                     ; Check error code
  jnz .err                                        ; If there was an error return 0

  jmp .afterHandleAccess                          ; Continue and set flags and shit

.createIfDoesntExist:
  mov ds, [bp - 2]                                ; Get a pointer to the files path (DS:SI)
  mov si, [bp - 11]                               ; Get offset

  mov bx, ss                                      ; Set the destination, where to store the files entry (the entry buffer)
  mov es, bx                                      ; Set segment
  mov di, [bp - 9]                                ; Set offset
  call getFileEntry                               ; Get the files entry
  test ax, ax                                     ; Check error code
  jz .afterHandleAccess                           ; If the file exists, continue and set flags for the opened file

  ; If the file doesnt exist, we create it
  mov ds, [bp - 2]                                ; Get a pointer to the files path
  mov si, [bp - 11]                               ; Get offset

  xor bx, bx 
  mov es, bx                                      ; Get segment
  xor di, di

  xor dx, dx                                      ; Set flags for the new file    // None
  call createFile                                 ; Create the file and save its entry into the entry buffer
  test ax, ax                                     ; Check error code
  jnz .err                                        ; If there was an error return 0

  jmp .afterHandleAccess                          ; Continue and set flags and shit 


%endif