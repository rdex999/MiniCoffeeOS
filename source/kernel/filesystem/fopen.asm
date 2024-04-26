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
  sub sp, 9 + 32                                  ; Allocate memory on the stack, for local stuff and for the file entry

  mov [bp - 9], sp                                ; Store FAT buffer pointer (32 bytes)
  mov [bp - 2], es                                ; Save used segments
  mov [bp - 4], ds                                ;
  mov ax, si                                      ; Save low 8 bits of the requested file access
  mov [bp - 5], al                                ;

  ; Prepare arguments for getFileEntry, and read the file entry into the stack
  mov bx, es                                      ; Set DS:SI = ES:DI
  mov ds, bx                                      ; Because getFileEntry wants the filename in DS:SI
  mov si, di                                      ; SI = DI

  mov bx, ss                                      ; Set ES:DI = SS:SP
  mov es, bx                                      ; Because we will store the entry on the stack, and SP already points
  mov di, sp                                      ; to the allocated memory on the stack

  call getFileEntry                               ; Get the files FAT entry and store it on the stack
  test ax, ax                                     ; Check error code of getFileEntry
  jnz .err                                        ; If there was an error we return null

  mov si, sp                                      ; Entry stored on the stack
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

  mov al, [bp - 5]                                ; Get requested file access
  mov es:[di + FILE_OPEN_ACCESS8], al             ; Set files access
  mov word es:[di + FILE_OPEN_READ_POS16], 0      ; Initialize the files current read position to 0

  add di, FILE_OPEN_ENTRY256                      ; Add to the pointer the offset of the FAT entry, as we want to copy to it
  mov si, [bp - 9]                                ; Get a pointer to the FAT entry (from where to copy DS:SI)
  mov bx, ss                                      ; Set DS:SI => FAT entry
  mov ds, bx                                      ; FAT entry stored on the stack
  mov dx, 32                                      ; Copy 32 bytes, the size of a FAT entry
  call memcpy                                     ; Copy the FAT entry into the empty file slot in openFiles
  mov cx, [bp - 7]                                ; Get the empty slot index

.setAccess:
  mov ax, cx                                                ; Get the files slot index
  inc ax                                                    ; Increase by 1 so we dont return 0 for a valid index (0 indicates error)

.end:
  mov es, [bp - 2]                                ; Restore used segments
  mov ds, [bp - 4]                                ;
  mov sp, bp                                      ; Restore stack frame
  pop bp                                          ;
  ret

.err:
  xor ax, ax                                      ; If there is an error we return null
  jmp .end

%endif