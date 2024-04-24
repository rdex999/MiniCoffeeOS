;
; ---------- [ READ BYTES FROM A CLUSTER CHAIN ON AN OFFSET ] ---------
;

%ifndef READ_CLUSTER_BYTES
%define READ_CLUSTER_BYTES

; Read N bytes from a cluster chain, from a given offset
; For example there is a cluster chain which data is: "some text idk"
; Reading 4 bytes on offset 3 will give you: "e te"
; PARAMETERS
;   - 0) ES:DI  => Buffer to store data in
;   - 1) SI     => Files first cluster number
;   - 2) DX     => Byte offset
;   - 3) CX     => Amount of bytes to read
; RETURNS
;   - 0) In AX, the amount of bytes read, can be less then the requested amount if an error occurred
readClusterBytes:
  push bp                               ; Save stack frame
  mov bp, sp                            ;
  sub sp, 20                            ; Allocate space for local variables

  ; *(bp - 2)   - Buffer segment
  ; *(bp - 4)   - Buffer offset
  ; *(bp - 6)   - Cluster number
  ; *(bp - 8)   - Byte offset
  ; *(bp - 10)  - Amount of bytes to read
  ; *(bp - 12)  - LBA
  ; *(bp - 14)  - Old DS
  ; *(bp - 15)  - Clusters to read
  ; *(bp - 16)  - Sectors to read
  ; *(bp - 17)  - Bytes to read
  ; *(bp - 18)  - Sectors left in cluster
  ; *(bp - 20)  - Sector buffer offset (segment is SS)
  ; *(bp - 22)  - Bytes read so far

  mov [bp - 2], es                      ; Store buffer pointer
  mov [bp - 4], di                      ; (ES:DI)
  mov [bp - 6], si                      ; Store first cluster number
  mov [bp - 8], dx                      ; Store bytes offset 
  mov [bp - 10], cx                     ; Store amount of bytes to read
  mov [bp - 14], ds                     ; Store old DS segment
  mov word [bp - 22], 0                 ; Initialize bytes read so far to 0

  pusha                                 ;;;;;; DEBUG
  mov di, si                            ;;;;;;
  call clusterToLBA                     ;;;;;;
  PRINTF_M `first clusters LBA %u\n`, ax;;;;;;
  popa                                  ;;;;;;


  mov bx, KERNEL_SEGMENT                ; Set DS segment to kernel segment so we can read kernel variables
  mov ds, bx                            ;

  ; Here we calculate the amount of clusters we can skip (if any)
  ; The formula:
  ; clustersToSkip = byteOffset / bytesPerCluster
  ; newByteOffset  = byteOffset % bytesPerCluster
  ; First we calculate the amount of bytes in a cluster (bytesPerSector * sectorPerCluster)
  mov ax, ds:[bpb_bytesPerSector]       ; Get the amount of bytes in a sector
  mov bl, ds:[bpb_sectorPerCluster]     ; Get amount of sectors in a cluster (8 bits)
  xor bh, bh                            ; Zero out high 8 bits
  mul bx                                ; Get amount of bytes in a cluster in AX
  
  mov bx, ax                            ; Amount of bytes in a cluster in BX

  mov ax, [bp - 8]                      ; Get requested bytes offset
  xor dx, dx                            ; Zero out remainder register
  
  ; AX = byteOffset / bytesPerCluster = clustersToSkip
  ; DX = byteOffset % bytesPerCluster = newBytesOffset
  div bx                                ; Calculate

  test ax, ax                           ; Check if there are even any clusters to skip
  jz .afterCalcClusterSkip              ; If 0 clusters to skip then skip the part which skips clusters (read it again)

  ; If there are some clusters we can skip, then skip them and store the new bytes offset
  mov [bp - 8], dx                      ; Store the new bytes offset
  mov cx, ax                            ; Loop through the amount of clusters to skip
.skipClustersLoop:
  mov di, [bp - 6]                      ; Get current cluster number
  push cx                               ; Save amount of clusters left to skip
  call getNextCluster                   ; Get the next cluster number, from out current one
  pop cx                                ; Restore amount of clusters left to skip
  test bx, bx                           ; Check if getNextCluster has returned with an error
  jnz .err                              ; If it did, then return 0 to indicate an error

  cmp ax, 0FFF8h                        ; Check if its the end of the cluster chain
  jae .err                              ; If it is, then return 0 because we couldnt even reach the files first byte with the given offset

  mov [bp - 6], ax                      ; If its not the end of the cluster chain, then update the first cluster number variable
  loop .skipClustersLoop                ; Continue skipping clusters until CX (amount of clusters to skip) is 0

.afterCalcClusterSkip:
  ; Get the LBA of the new cluster
  mov di, [bp - 6]                      ; Get first cluster number (updated)
  call clusterToLBA                     ; Get its LBA in AX
  mov [bp - 12], ax                     ; Store LBA

  ; Calculate the amount of sectors to skip
  ; The formula
  ; sectorsToSkip = byteOffset / bytesPerSector
  ; newByteOffset = byteOffset % bytesPerSector
  mov bx, ds:[bpb_bytesPerSector]       ; Get amount of bytes in a sector
  mov ax, [bp - 8]                      ; Get bytes offset
  xor dx, dx                            ; Zero out remainder register
  
  ; AX = sectorsToSkip  = byteOffset{AX} / bytesPerSector{BX}
  ; DX = newBytesOffset = byteOffset{AX} % bytesPerSector{BX}
  div bx                                ; Calculate

  mov [bp - 8], dx                      ; Update the bytes offset
  add [bp - 12], ax                     ; Increase the LBA

  ; test dx, dx                           ; Check if bytes offset is 0
  ; jz .initWholeSectors                  ; If it is then there is no need to do the offseted copy

  ; Is there is a byte offset, then allocate space for 1 sector (on the stack),
  ; Read 1 sector of the file into it, then copy the data from the sector buffer + the offset, into the argument buffer
  ; memcpy(argumentBuffer, sectorBuffer + offset, bytesPerSector - offset);
  mov bl, al                            ; Get sectors to skip in BL
  mov al, ds:[bpb_sectorPerCluster]     ; Get number of sectors in a cluster in AL
  sub al, bl                            ; Get the amount of sectors left to read in the current cluster
  mov [bp - 18], al                     ; Store it

  ; Allocate space for 1 sector on the stack
  sub sp, ds:[bpb_bytesPerSector]       ; Allocate
  mov [bp - 20], sp                     ; Store sector buffer pointer

  ; Prepare arguments for readDisk, and read a sector of the file into the sector buffer we just allocated space for
  mov bx, ss                            ; Set ES:BX = SS:SP, for the destination (the sector buffer)
  mov es, bx                            ; Set ES = SS
  mov bx, sp                            ; Set BX = SP
  mov di, [bp - 12]                     ; Set LBA to read from
  mov si, 1                             ; Read 1 sector
  call readDisk                         ; Read a sector of the file into the sector buffer
  test ax, ax                           ; Check the error code of readDisk
  jnz .err                              ; If there is an error then return 0

  ; Calculate the amount of bytes to copy to the destination (the parameter)
  ; bytesToCopy;
  ; if(requestedAmount - (bytesPerSector - offset) >= 0) {
  ;   bytesToCopy = bytesPerSector - offset;
  ;   bytesLeftToRead -= bytesToCopy;
  ;   bytesReadSoFat = bytesToCopy;
  ; }else{
  ;   bytesToCopy = requestedAmount;
  ;   bytesReadSoFat = requestedAmount;
  ;   bytesLeftToRead = 0;
  ; }
  mov ax, ds:[bpb_bytesPerSector]       ; Get amount of bytes in 1 sector
  sub ax, [bp - 8]                      ; Subtract from it the bytes offset, to get the max amount of bytes were gonna copy
  mov dx, [bp - 10]                     ; Get the amount of bytes left to read
  sub dx, ax                            ; Subtract from it the max amount of bytes were going to copy
  jc .setSizeBytesToRead                ; If the result is negative then jump

  ; If not negative, then were gonna copy (bytesPerSector - offset) bytes
  sub [bp - 10], ax                     ; Subtract the amount of bytes were gonna read from "bytes left to read"
  mov dx, ax                            ; Get the amount of bytes to copy in DX
  jmp .afterSetSize                     ; Continue and prepare for copying

.setSizeBytesToRead:
  ; If negative, then were gonna copy the amount of bytes left to read (which, we know is less then a sector)
  mov dx, [bp - 10]                     ; Set DX to the amount of bytes left to read
  add [bp - 22], dx                     ; Add to the amount of bytes read so far, the amount of bytes that were going to read
  mov word [bp - 10], 0                 ; Set the amount of bytes left to read to 0

.afterSetSize:
  mov bx, ss                            ; Set DS:SI = SS:sectorBufferOffset   // DS:SI is the source, from where to copy
  mov ds, bx                            ; Set DS = SS
  mov si, [bp - 20]                     ; Set SI = sectorBufferOffset
  add si, [bp - 8]                      ; Add the bytes offset to the buffer pointer

  mov es, [bp - 2]                      ; Set ES:DI = requestedBuffer   // ES:DI is the destination, where to copy the data to
  mov di, [bp - 4]                      ; Set DI = requestedBufferOffset
  call memcpy                           ; Copy DX amount of bytes from DS:SI to ES:DI

  mov bx, KERNEL_SEGMENT                ; Set DS to kernel segment so we can access currect variables
  mov ds, bx                            ;
  
  cmp word [bp - 10], 0
  je .success

  ;;;;; TODO



.success:
  mov ax, [bp - 22]
.end:
  mov ds, [bp - 14]                             ; Restore old DS segment
  mov es, [bp - 2]                              ; Restore old ES segment
  mov sp, bp                                    ; Restore stack frame
  pop bp                                        ;
  ret

.err:
  xor ax, ax                                    ; If there is an error, we return 0 to indicate 0 bytes were read
  jmp .end                                      ; Return

%endif
