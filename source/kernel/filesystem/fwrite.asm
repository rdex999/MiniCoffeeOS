;
; ---------- [ FILE TO AN OPEN FILE ] ---------
;

%ifndef FWRITE_ASM
%define FWRITE_ASM

; Write to the current position in a file.
; PARAMS
;   - 0) ES:DI  => The buffer of data to be written to the file
;   - 1) SI     => The amount of bytes to write to the file
;   - 2) DX     => A handle to the file
; RETURNS
;   - 0) In AX, the amount of bytes written. Can be less than the requested amount if an error occurs
fwrite:
  push bp                                         ; Save stack frame
  mov bp, sp                                      ;
  sub sp, 8                                       ; Allocate space for local stuff

  mov [bp - 2], es                                ; Save data buffer pointer
  mov [bp - 4], di                                ; Save its offset
  mov [bp - 6], si                                ; Save the amount of bytes to write

  mov bx, KERNEL_SEGMENT                          ; Set ES to the kernels segment so we can access the openFiles array
  mov es, bx                                      ;

  ; Check if the handle is valid
  test dx, dx                                     ; Check if the handle is null
  jz .err                                         ; If it is, return 0

  cmp dx, FILE_OPEN_LEN                           ; Check if the handle is greater than the length of the openFiles array
  ja .err                                         ; If it is, return 0

  ; Get a pointer to the file descriptor in the openFiles array
  mov ax, dx                                      ; Get the handle in AX
  dec ax                                          ; Decrement it by one, because handles start from 1 and its actualy an index into openFiles

  mov bx, FILE_OPEN_SIZEOF                        ; Get the size of a single file descriptor
  mul bx                                          ; Multiply the index by it

  lea di, [openFiles]                             ; Get a pointer to the openFiles array
  add di, ax                                      ; Add to it the calculated offset

  cmp word es:[di + FILE_OPEN_ENTRY256 + 26], 0   ; Check if the file is even open
  je .err                                         ; If its not return EOF

  mov al, es:[di + FILE_OPEN_ACCESS8]             ; Get the files access

  cmp al, FILE_OPEN_ACCESS_READ                   ; Check if the files access is READ (which doesnt have WRITE)
  je .err                                         ; If it is, return EOF.

  mov [bp - 8], di                                ; Store the file descriptor pointer in the openFiles array
  
  ; Check the files size, and if we need to add clusters
  mov ax, es:[di + FILE_OPEN_POS16]               ; Get the current position in the file
  add ax, [bp - 6]                                ; Add the requested write size to it
  cmp ax, es:[di + FILE_OPEN_ENTRY256 + 28]       ; Check if its greater than the files size
  jbe .writeToFile                                ; If not, write the buffer into the file

  mov si, ax                                      ; Store final size of the file
  mov ax, es:[bpb_bytesPerSector]                 ; Get the size of a sector
  mov bl, es:[bpb_sectorPerCluster]               ; Get the amount of sectors in a cluster
  xor bh, bh                                      ; Zero out high 8 bits
  mul bx                                          ; Get the size of a cluster in AX

  mov bx, ax                                      ; Size of cluster in BX
  mov ax, si                                      ; Get the size of the final file
  xor dx, dx                                      ; Zero remainder
  div bx                                          ; Divide the size of the final file by the size of a cluster
  test ax, ax                                     ; Check if the amount of clusters to add is 0
  jz .writeToFile                                 ; If it is then just write to the file, and dont add clusters

  push ax                                         ; Save the amount of cluster we need for the final file size
  mov di, es:[di + FILE_OPEN_ENTRY256 + 26]       ; Get the files first cluster number
  call countClusters                              ; Get the amount of cluster we currently have
  pop bx                                          ; Restore amount of clusters we need to have

  cmp ax, bx                                      ; Check if the amount of clusters we currently have is greater than the amount we need to have
  jae .writeToFile                                ; If it is greater/equal to then just write to the file

  mov di, [bp - 8]                                ; Get a pointer to the file descriptor in openFiles
  mov si, bx                                      ; Get the amount of clusters to add in SI (the argument for addClusters)
  mov di, es:[di + FILE_OPEN_ENTRY256 + 26]       ; Get the first cluster number (also an argument)
  call addClusters                                ; Add the calculated amount of clusters to the cluster chain
  test ax, ax                                     ; Check error code
  jz .err                                         ; If there was an error, return 0

.writeToFile:
  push ds                                         ; Save DS because changing it for a sec
  mov di, [bp - 8]                                ; Get a pointer to the file descriptor in the openFiles array
  mov dx, es:[di + FILE_OPEN_POS16]               ; Get the current position in the file
  mov di, es:[di + FILE_OPEN_ENTRY256 + 26]       ; Get the first cluster number of the file
  mov cx, [bp - 6]                                ; Get the requested amount of bytes to write
  mov ds, [bp - 2]                                ; Get a pointer to the data buffer to write to the file
  mov si, [bp - 4]                                ; Get offset
  call writeClusterBytes                          ; Write the buffer at the offset of the current position, to the file.
  pop ds                                          ; Restore DS

  mov di, [bp - 8]                                ; Get a pointer to the file descriptor in the openFiles array
  mov cx, es:[di + FILE_OPEN_POS16]               ; Get the current position in the file, before changing it
  add es:[di + FILE_OPEN_POS16], ax               ; Increase the current position in the file by the amount of bytes written

  mov bx, ax                                      ; Get the amount of bytes written in BX, because we dont wanna modify AX (its the return value register)
  add bx, cx                                      ; Add the current position in the file to it
  cmp bx, es:[di + FILE_OPEN_ENTRY256 + 28]       ; Check if the new file size is greater than the current size
  jbe .end                                        ; If its not, just return the amount of bytes written

  add es:[di + FILE_OPEN_ENTRY256 + 28], ax       ; If it is greater, add the amount of bytes written to the size

.end:
  mov es, [bp - 2]                                ; Restore used segments
  mov sp, bp                                      ; Restore stack frame
  pop bp                                          ;
  ret

.err:
  xor ax, ax                                      ; If there was an error, return null
  jmp .end

%endif