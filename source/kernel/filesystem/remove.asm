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
  push bp                                     ; Save stack frame
  mov bp, sp                                  ;
  sub sp, 10 + 32                             ; Allocate space for local shit, and a 32 byte buffer for the files entry

  ; *(bp - 2)   - Old DS segment
  ; *(bp - 4)   - Old ES segment
  ; *(bp - 6)   - Files cluster number
  ; *(bp - 8)   - The entries LBA
  ; *(bp - 10)  - The byte offset in the LBA
  ; *(bp - 42)  - 32 bytes long, the files entry
  
  mov [bp - 2], ds                            ; Save used segments
  mov [bp - 4], es                            ;
  
  mov bx, es                                  ; Set DS:SI to point to the file name
  mov ds, bx                                  ; Set segment, DS = ES
  mov si, di                                  ; Set offset

  mov bx, ss                                  ; Set ES:DI to the entry buffer (the 32 bytes that were allocated on the stack)
  mov es, bx                                  ; Set segment
  mov di, sp                                  ; Set offset
  call getFileEntry                           ; Read the files entry into the entry buffer
  test ax, ax                                 ; Check error code
  jnz .end                                    ; If there was an error, return with it

  mov [bp - 8], bx                            ; Save the entries LBA address
  mov [bp - 10], cx                           ; Save the byte offset in the LBA, for the entry

  mov di, sp                                  ; Get a pointer to the entry
  mov ax, ss:[di + 26]                        ; Get the files first cluster number
  mov [bp - 6], ax                            ; Store it, because later we set all clusters of the files to 0 (mark them as free)

  add sp, 32                                  ; Free the allocated space for the files entry

  mov dx, KERNEL_SEGMENT                      ; Set DS to the kernels segment so we can access bpb_bytesPerSector
  mov ds, dx

  sub sp, ds:[bpb_bytesPerSector]             ; Allocate space for 1 sector on the stack

  mov di, bx                                  ; Get the LBA of the entry
  mov si, 1                                   ; Set the amount of sectors to read

  mov bx, ss                                  ; Set the destination, where to write the data into (the sector buffer)
  mov es, bx                                  ; Set segment
  mov bx, sp                                  ; Set offset
  call readDisk                               ; Read the sector which containes the files entry
  test ax, ax                                 ; Check error code
  jnz .end                                    ; If there was an error, return with it as the error code
  
  mov bx, ss                                  ; Set the destination, where to write the data to (the files entry which is in the sector buffer)
  mov es, bx                                  ; Set segment
  mov di, [bp - 10]                           ; Set offset of the entry in the sector
  add di, sp                                  ; Add the beginning of the buffer to the offset, so it points to the entry

  xor si, si                                  ; The value to set the entry to (0)
  mov dx, 32                                  ; Amount of bytes to set, the size of an entry
  call memset                                 ; Set the whole entry to 0

  mov bx, ss                                  ; Set the source, from where to write the data (the sector buffer)
  mov ds, bx                                  ; Set segment
  mov si, sp                                  ; Set offset

  mov di, [bp - 8]                            ; Get the LBA of the entry
  mov dx, 1                                   ; Set the amount of sectors to write
  call writeDisk                              ; Write out changes to the sector to the hard disk
  test ax, ax                                 ; Check error code of writeDisk
  jnz .end                                    ; If there was an error return with it as the error code

.freeClusters:
  ; When getting here, the files first cluster number should be at *(bp - 18)
  mov di, [bp - 6]                            ; Get the files first cluster number
  cmp di, FAT_CLUSTER_INVALID                 ; Check if its valid
  jae .success                                ; If not, return with 0 because we finished freeing the clusters

  call getNextCluster                         ; Get the next cluster for the current one
  test bx, bx                                 ; Check error code
  jz .gotNextCluster                          ; If there was an error, return with it

  mov ax, bx                                  ; If there was an error, get it in AX
  jmp .end                                    ; Return with the error

.gotNextCluster:
  mov di, [bp - 6]                            ; Get the current cluster number
  mov [bp - 6], ax                            ; Set the current cluster number to the next one
  xor si, si                                  ; The value to set the current cluster to (0 means free)
  call setCluster                             ; Set the current cluster to 0 (mark it as free)
  test ax, ax                                 ; Check error code
  jnz .end                                    ; If there was an error return with it

  jmp .freeClusters                           ; Continue freeing clusters

.success:
  xor ax, ax                                  ; On success, we return 0

.end:
  mov ds, [bp - 2]                            ; Restore used segments
  mov es, [bp - 4]                            ;
  mov sp, bp                                  ; Restore stack frame
  pop bp                                      ;
  ret

%endif