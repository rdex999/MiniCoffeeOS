;
; --------- [ WRITE A DATA BUFFER INTO A CLUSTER CHAIN ] ----------
;

%ifndef WRITE_CLUSTER_BYTES_ASM
%define WRITE_CLUSTER_BYTES_ASM

; Write a data buffer to a cluster chain on a given offset
; PARAMETERS
;   - 0) DI     => The files first cluster number
;   - 1) DS:SI  => The data buffer
;   - 2) DX     => The offset to write the data on the file (in bytes)
;   - 3) CX     => The amount of bytes to write to the file, from the buffer
; RETURNS
;   - 0) In AX, the amount of bytes written
writeClusterBytes:
  push bp
  mov bp, sp 
  sub sp, 21

  ; *(bp - 2)     - Files first cluster number
  ; *(bp - 4)     - Data buffer to write from (segment)
  ; *(bp - 6)     - Data buffer to write from (offset)
  ; *(bp - 8)     - Bytes offset to write on
  ; *(bp - 10)    - Amount of bytes to write
  ; *(bp - 12)    - Old GS segment
  ; *(bp - 14)    - Sector buffer offset (segment is SS)
  ; *(bp - 16)    - Current LBA address
  ; *(bp - 17)    - Sectors left in cluster
  ; *(bp - 19)    - Bytes written so far
  ; *(bp - 21)    - Old ES segment

  mov [bp - 2], di                          ; Store arguments   // Store first cluster number
  mov [bp - 4], ds                          ; Store buffer segment
  mov [bp - 6], si                          ; Store buffer offset
  mov [bp - 8], dx                          ; Store bytes offset
  mov [bp - 10], cx                         ; Store amount of bytes to write
  mov [bp - 12], gs                         ; Store old GS segment
  mov word [bp - 19], 0                     ; Initialize bytes written so far to 0
  mov [bp - 21], es

  mov bx, KERNEL_SEGMENT                    ; Set GS to kernel segment so we can access kernel variables
  mov gs, bx                                ;

  sub sp, gs:[bpb_bytesPerSector]           ; Allocate space for 1 sector on the stack
  mov [bp - 14], sp                         ; Store sector buffer offset

  ; Calculate new cluster and LBA of the given offset
  ; *The cluster number is already in DI
  mov si, dx                                ; Get the bytes offset
  call skipClusters                         ; Calculate the amount of clusters we can skip with the bytes offset
  test si, si                               ; Check error code of skipClusters
  jnz .err                                  ; If there was an error then return 0 (0 bytes written)

  ; If there was not error then store the return values
  mov [bp - 2], ax                          ; Store new cluster number
  mov [bp - 16], bx                         ; Store new LBA address
  mov [bp - 17], cl                         ; Store amount of sectors left in the current cluster
  mov [bp - 8], dx                          ; Store new bytes offset

.writeLoop:
  ; Here we check if we can write straight into LBA from the buffer, 
  ; and skip reading the sector and then copying and then writting...
  ; If the bytes offset is 0, and the amount of bytes left to write is greater than 512,
  ; then we can skip reading the sector and stuff and we can just write the data straight into the LBA.
  cmp word [bp - 8], 0                      ; Check if the bytes offset is 0
  jne .prepRead                             ; If not, then skip this part and prepare for reading the sector

  mov ax, [bp - 10]                         ; Get the amount of bytes left to write
  sub ax, gs:[bpb_bytesPerSector]           ; Subtract from it the amount of bytes in a sector
  jc .prepRead                              ; If the result is negative then skip this part and prepare for reading the sector

  ; Will get here if we can write directly into the LBA, from the buffer
  mov ds, [bp - 4]                          ; Get source buffer segment
  mov si, [bp - 6]                          ; Get source buffer offset
  mov di, [bp - 16]                         ; Get destination LBA address
  mov dx, 1                                 ; How many sectors to write (1 - 512 bytes)
  call writeDisk                            ; Write 1 sector (512 bytes) from DS:SI into the LBA in DI
  test ax, ax                               ; Check error code
  jnz .retCntBytes                          ; If there was an error then return the amount of bytes read so far

  ; If we wrote successfully to the disk, then increase/decrement pointers and counters, 
  ; get the next LBA (or cluster) and continue reading
  mov ax, gs:[bpb_bytesPerSector]           ; Get amount of bytes in 1 sector
  add [bp - 6], ax                          ; Add it to the source buffer offset
  add [bp - 19], ax                         ; Add it to the amount of bytes we read so far
  sub [bp - 10], ax                         ; Subtract it from the amount of bytes left to read

  jmp .nextLBA                              ; Get the next cluster/LBA and continue writing to the file

.prepRead:
  ; Now we want to read the sector into RAM, then offset it,
  ; copy data from the source buffer into the sector buffer, then write it back into hard disk

  ; Calculate the bytes offset, because were writting sectors and not whole clusters
  mov al, gs:[bpb_sectorPerCluster]         ; Get amount of sectors in a cluster
  sub al, [bp - 17]                         ; Subtract from it the amount of sectors left to write to in the current cluster
  xor ah, ah                                ; Zero out high 8 bits

  mov bx, gs:[bpb_bytesPerSector]           ; Get amoint of bytes in a sector
  mul bx                                    ; Multiply sectorsPerCluster * bytesPerSector = bytesPerCluster

  mov dx, ax                                ; Get bytes offset in DX
  mov si, [bp - 2]                          ; Get current cluster number in SI
  mov cx, gs:[bpb_bytesPerSector]           ; Amount of bytes to read, 1 sector (bytesPerSector)
  
  mov bx, ss                                ; Set destination buffer pointer to the sector buffer ES:DI = sectorBuffer
  mov es, bx                                ; Set segment ES = SS
  mov di, [bp - 14]                         ; Set offset DI = sectorBuffer.offset
  call readClusterBytes                     ; Read 1 sector of the file into the sector buffer
  cmp ax, gs:[bpb_bytesPerSector]           ; Check if the amount of bytes read is less than a sector
  jb .retCntBytes                           ; If it is then return the amount of bytes written so far

  ; If we read 1 sector successfully, then now calculate the amount of bytes to copy from the buffer
  ; (the parameter) into the sector buffer
  ; if(size - (bytesPerSector - offset) < 0){
  ;   copySize = size;
  ; }else{
  ;   copySzie = bytesPerSector - offset;
  ; }
  mov bx, gs:[bpb_bytesPerSector]           ; Get amount of bytes in a sector
  sub bx, [bp - 8]                          ; Subtract from it the bytes offset (parameter)

  mov ax, [bp - 10]                         ; Get the requested write size
  sub ax, bx                                ; Subtract from it the thing we calculated before (which is in BX)
  jc .setSizeLeft                           ; If its negative then set the copy size to the maximum amount of bytes that we can copy

  mov dx, gs:[bpb_bytesPerSector]           ; If not negative, then the copy size is (bytesPerSector - offset)  // Get bytes in 1 sector
  sub dx, [bp - 8]                          ; Subtract the bytes offset from it
  jmp .afterSetSize                         ; Continue and prepare arguments for memcpy

.setSizeLeft:
  mov dx, [bp - 10]                         ; If it is negative (the calculation from before) then the copy size is just the requested size

.afterSetSize:
  ; Prepare arguments for memcpy
  mov bx, ss                                ; Set destination buffer to the sector buffer
  mov es, bx                                ; Set segment ES = SS
  mov di, [bp - 14]                         ; Set offset DI = sectorBuffer.offset
  add di, [bp - 8]                          ; Add the bytes offset to the destination buffers offset

  mov ds, [bp - 4]                          ; Set the source buffer pointer to the given buffer (the parameter)
  mov si, [bp - 6]                          ; Set the source buffer offset to the given buffers offset

  push dx                                   ; Save the amount of bytes were gonna copy (were gonna use it later)
  call memcpy                               ; Copy the given buffers data (+ the offset), into the sector buffer

  ; Now we want to copy out changes of the sector, into the sector in the hard disk
  mov bx, ss                                ; Set source buffer to our sector buffer DS:SI = sectorBuffer
  mov ds, bx                                ; Set segment DS = sectorBuffer.segment = SS
  mov si, [bp - 14]                         ; Set offset SI = sectorBuffer.offset

  mov di, [bp - 16]                         ; Set the LBA to write to   // Out current LBA
  mov dx, 1                                 ; Amount of sectors to write to (1)
  call writeDisk                            ; Write the sector buffer into the sector on the hard disk
  test ax, ax                               ; Check writeDisk error code
  jnz .retCntBytes                          ; If there was an error then return the amount of bytes we have written so far

  pop dx                                    ; Restore amount of bytes we have copied
  add [bp - 6], dx                          ; The size were gonne write it to the source buffer offset
  add [bp - 19], dx                         ; Add it to the amount of bytes we read so far
  sub [bp - 10], dx                         ; Subtract it from the amount of bytes left to read
  jc .retCntBytes                           ; If the amount of bytes left to write is zero or negative, 
  jz .retCntBytes                           ; then return the amount of bytes written so far

.nextLBA:
  mov word [bp - 8], 0                      ; Reset offset to 0   // The first iteration it will be set, but after that its always 0
  inc word [bp - 16]                        ; Increase current LBA address
  dec byte [bp - 17]                        ; Decrement amount of sectors left in the current cluster
  jnz .writeLoop                            ; If its not zero, then continue writting to the file

  ; If the amount of sectors left to write to is 0, then reset it to the amount of sectors in a cluster,
  ; Get the next cluster, and calculate the LBA for it.
  mov al, gs:[bpb_sectorPerCluster]         ; Get amount of sectors in a cluster
  mov [bp - 17], al                         ; Reset sectors counter to the amount of sectors in a cluster

  mov di, [bp - 2]                          ; Get current cluster number
  call getNextCluster                       ; Get the next cluster for it in the cluster chain
  test bx, bx                               ; Check error code
  jnz .retCntBytes                          ; If there was an error then return the amount of bytes written so far

  cmp ax, 0FFF8h                            ; Check if the new cluster is the end of the cluster chain
  jae .retCntBytes                          ; If it is then return the amount of bytes written so far

  mov [bp - 2], ax                          ; If its not the end of the cluster chain, then update the cluster number
  mov di, ax                                ; Get new cluster number in DI (argument for clusterToLBA)
  call clusterToLBA                         ; Get the LBA address for the new cluster
  mov [bp - 16], ax                         ; Update the LBA address to the new one
  jmp .writeLoop                            ; Continue writting to the file

.retCntBytes:
  mov ax, [bp - 19]                         ; Get amount of bytes written

.end:
  mov gs, [bp - 12]                         ; Restore old GS segment
  mov ds, [bp - 4]                          ; Restore old DS segment
  mov es, [bp - 21]
  mov sp, bp                                ; Restore stack frame
  pop bp                                    ;
  ret

.err:
  xor ax, ax                                ; Return 0 on error (0 bytes written)
  jmp .end

%endif