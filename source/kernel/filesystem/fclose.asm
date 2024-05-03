;
; ---------- [ FUNCTION FOR CLOSING AN OPENED FILE ] ----------
;

%ifndef FCLOSE_ASM
%define FCLOSE_ASM

; Close an opened file
; PARAMETERS
;   - 0) DI   => File handle
; RETURNS
;   - 0) In AX, 0 success and EOF (0FFFFh) on failure
fclose:
  push bp                                         ; Save stack frame
  mov bp, sp                                      ;
  sub sp, 6                                       ; Allocate space for local stuff

  mov [bp - 2], ds                                ; Save used segments
  mov [bp - 4], es                                ;

  mov bx, KERNEL_SEGMENT                          ; Set DS to kernel segment so we can access the openFiles array
  mov ds, bx                                      ;

  ; Here we check if its an invalid handle
  cmp di, FILE_OPEN_LEN                           ; Check if the file handle (an index into openFiles) is greater than its length
  ja .err                                         ; If it is, then its not a valid handle and we return with an error (greater because handle starts from 1)

  test di, di                                     ; Check if the handle is 0 (an invalid handle is null)
  jz .err                                         ; If null then return an error

  ; Here we multiply the handle (an index) by the size of an open file descriptor
  ; to get the offset into the openFiles array
  mov ax, di                                      ; Get file handle in AX
  dec ax                                          ; Decrement handle by 1, because it starts from 1 and an index start from 0

  mov bx, FILE_OPEN_SIZEOF                        ; Get the size of an open file descriptor
  mul bx                                          ; Multiply index by the size of an open file descriptor to get the offset into openFiles

  lea si, [openFiles]                             ; Get pointer to the first element of openFiles
  add si, ax                                      ; Add to the pointer the offset we just calculated
  mov [bp - 6], si
  
  cmp word ds:[si + FILE_OPEN_ENTRY256 + 26], 0   ; Check if the file is open
  je .err                                         ; If the file is not open then return an error

  ; Read the sector of the entry, update the entry, and write the sector back into the hard disk
  sub sp, ds:[bpb_bytesPerSector]                 ; Allocate space for 1 sector
  
  mov di, ds:[si + FILE_OPEN_ENTRY_LBA16]         ; Get the entries LBA

  mov si, 1                                       ; Amount of sectors to read
  
  mov bx, ss                                      ; Set the destination, where to read into (the sector buffer)
  mov es, bx                                      ; Set segment
  mov bx, sp                                      ; Set offset
  call readDisk                                   ; Read the sector containing the entry, into the sector buffer
  test ax, ax                                     ; Check error code
  jnz .err                                        ; If there was an error, return EOF

  mov bx, KERNEL_SEGMENT                          ; Set DS to kernel segment, so we can access the openFiles array
  mov ds, bx                                      ;
  mov si, [bp - 6]                                ; Get a pointer to the file descriptor in the openFiles array (from where to copy)
  
  mov bx, ss                                      ; Set the destination, ES:DI -> the entry in the sector buffer
  mov es, bx                                      ; Set segment
  mov di, sp                                      ; Set offset
  add di, ds:[si + FILE_OPEN_ENTRY_OFFSET16]      ; Offset the buffer into the entry on the sector buffer

  add si, FILE_OPEN_ENTRY256                      ; Increase SI to point to the FAT entry

  mov dx, 32                                      ; Set the amount of bytes to copy
  call memcpy                                     ; Copy the updated entry into the entry in the sector buffer

  mov bx, ss                                      ; Set DS:SI -> sector buffer    // From where to write the data, the source
  mov ds, bx                                      ; Set segment
  mov si, sp                                      ; Set offset

  mov bx, KERNEL_SEGMENT                          ; Set ES to the kernels segment, so we can access the openFiles array
  mov es, bx                                      ;
  mov di, [bp - 6]                                ; Get a pointer to the file descriptor in the openFiles array
  mov di, es:[di + FILE_OPEN_ENTRY_LBA16]         ; Get the LBA of the entry

  mov dx, 1                                       ; Set amount of sectors to write
  call writeDisk                                  ; Write out changes to the entry, to the hard disk
  test ax, ax                                     ; Check error code
  jnz .err                                        ; If there was an error, return with it

  mov bx, KERNEL_SEGMENT                          ; Set DS:SI -> the file descriptor in openFiles
  mov ds, bx                                      ; Set segment
  mov si, [bp - 6]                                ; Set offset

  mov word ds:[si + FILE_OPEN_ENTRY256 + 26], 0   ; Set the files first cluster number to 0, to indicate this slot is empty

  xor ax, ax                                      ; Zero out result, because we return 0 on success

.end:
  mov ds, [bp - 2]                                ; Restore used segments
  mov es, [bp - 4]                                ;
  mov sp, bp                                      ; Restore stack frame
  pop bp                                          ;
  ret

.err:
  mov ax, EOF                                     ; If there was an error, return EOF
  jmp .end                                        ; Return

%endif