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
  sub sp, 19

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

  mov [bp - 2], di                          ; Store arguments   // Store first cluster number
  mov [bp - 4], ds                          ; Store buffer segment
  mov [bp - 6], si                          ; Store buffer offset
  mov [bp - 8], dx                          ; Store bytes offset
  mov [bp - 10], cx                         ; Store amount of bytes to write
  mov [bp - 12], gs                         ; Store old GS segment
  mov word [bp - 19], 0                     ; Initialize bytes written so far to 0

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

  ;;;;
  jmp .retCntBytes                          ;;;;;;;; DEBUG
  ;;;;

  jmp .nextLBA                              ; Get the next cluster/LBA and continue writing to the file

.prepRead:
  ;;;; TODO


.nextLBA:
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
  mov sp, bp                                ; Restore stack frame
  pop bp                                    ;
  ret

.err:
  xor ax, ax                                ; Return 0 on error (0 bytes written)
  jmp .end

%endif