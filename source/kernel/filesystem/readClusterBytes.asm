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
  sub sp, 19                            ; Allocate space for local variables

  ; *(bp - 2)   - Buffer segment
  ; *(bp - 4)   - Buffer offset
  ; *(bp - 6)   - Cluster number
  ; *(bp - 8)   - Byte offset
  ; *(bp - 10)  - Amount of bytes to read
  ; *(bp - 12)  - LBA
  ; *(bp - 14)  - Old DS
  ; *(bp - 16)  - Bytes read so far
  ; *(bp - 18)  - Sector buffer offset (segment is SS)
  ; *(bp - 19)  - Sectors left in cluster


  mov [bp - 2], es                      ; Store buffer pointer
  mov [bp - 4], di                      ; (ES:DI)
  mov [bp - 6], si                      ; Store first cluster number
  mov [bp - 8], dx                      ; Store bytes offset 
  mov [bp - 10], cx                     ; Store amount of bytes to read
  mov [bp - 14], ds                     ; Store old DS segment
  mov word [bp - 16], 0

  pusha                                 ;;;;;; DEBUG
  mov di, si                            ;;;;;;
  call clusterToLBA                     ;;;;;;
  PRINTF_M `first clusters LBA %u\n`, ax;;;;;;
  popa                                  ;;;;;;


  mov bx, KERNEL_SEGMENT                ; Set DS segment to kernel segment so we can read kernel variables
  mov ds, bx                            ;

  sub sp, ds:[bpb_bytesPerSector]
  mov [bp - 18], sp

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

  ; sectorsLeftInCluster = sectorsPerCluster - sectorOffset
  mov bl, ds:[bpb_sectorPerCluster]     ; Get amount of sectors in a cluster
  sub bl, al                            ; Subtract from it the cluster offset
  mov [bp - 19], bl                     ; Save the amount of sectors left in current cluster

.readSectorsLoop:
  ; Prepare arguments for readDisk and read a sector of the file into the sector buffer
  mov di, [bp - 12]                     ; Get current LBA address
  mov si, 1                             ; Amount of sectors to read
  
  mov bx, ss                            ; Set ES:BX = SS:sectorBuffer   // Where to save the data to, out sector buffer
  mov es, bx                            ; Set ES = SS
  mov bx, [bp - 18]                     ; Set BX = sectorBufferOffset
  call readDisk                         ; Read a sector of the file into the sector buffer
  test ax, ax                           ; Check if readDisk has returned an error
  jnz .retBytesRead                     ; If it did then return the amount of bytes read so far

  ; if(bytesLeftToRead - (bytesPerSector - bytesOffset) < 0) { 
  ;   bytesToCopy = bytesLeftToRead;
  ; } else {
  ;   bytesToCopy = bytesPerSector - bytesOffset;
  ; } 
  mov ax, ds:[bpb_bytesPerSector]       ; Get amount of bytes in a sector
  sub ax, [bp - 8]                      ; Subtract from it the bytes offset, result in AX
  mov bx, [bp - 10]                     ; Get the amount of bytes left to read from the file
  sub bx, ax                            ; Subtract from it the thing we calculated before (which is in AX)
  jc .setCopySizeLast                   ; If negative then set the amount of bytes to copy to the amount of bytes left to read

  mov dx, ax                            ; If not negative, set the amount of bytes to copy to the amount of bytes in a sector minus the offset
  jmp .afterSetSize                     ; Continue and prepare arguments for memcpy

.setCopySizeLast:
  mov dx, [bp - 10]                     ; If negative then set the amount of bytes to copy to the amount of bytes left to read from the file

.afterSetSize:
  ; When getting here the amount of bytes to copy will be in DX
  add [bp - 16], dx                     ; Add the amount of bytes were gonna copy to the amount of bytes we read so far
  sub [bp - 10], dx                     ; Subtract the amount of bytes were gonna copy from the amount of bytes left to read from the file

  ; Prepare arguments for memcpy
  mov es, [bp - 2]                      ; Set ES:DI = requestedDataBuffer   // ES:DI is the destination, where to copy the tada to
  mov di, [bp - 4]                      ; Set DI = bufferOffset

  mov bx, ss                            ; Set DS:SI = SS:sectorBufferOffset   // DS:SI is the source, from where to copy the data
  mov ds, bx                            ; Set DS = SS   // We want to copy from the sector buffer to the requested buffer (the parameter)
  mov si, [bp - 18]                     ; Set SI = sectorBufferOffset
  add si, [bp - 8]                      ; Add the the offset, the bytes offset (the bytes offset is always 0, but not in the first iteration)
  push dx                               ; Save the amount of bytes to copy (we will use it)
  call memcpy                           ; Copy the files data into the requested buffer
  pop dx                                ; Restore amount of bytes we just copied

  mov bx, KERNEL_SEGMENT                ; Set DS to kernel segment
  mov ds, bx                            ; so we can read correct values

  cmp word [bp - 10], 0                 ; Check if the amount of bytes left to read is below/equal to 0
  jle .retBytesRead                     ; If it is then return with the amount of bytes we read so far

  add [bp - 4], dx                      ; Add the amount of bytes we just read, to the buffer pointer (the parameter)
  mov word [bp - 8], 0                  ; Set the bytes offset to 0

  dec byte [bp - 19]                    ; Decrement the amount of sectors left in the current cluster
  jz .resetLBAgetCluster                ; If its zero then reset it, get the next cluster and get the new LBA to the new cluster

  inc word [bp - 12]                    ; If its not zero, then increase the current LBA address
  jmp .readSectorsLoop                  ; Continue reading the file

.resetLBAgetCluster:
  ; If the amount of sectors left to read in the current cluster is 0,
  ; then set it to the amount of sectors in a cluster,
  ; get the next cluster in the cluster chain, and get the new LBA address for the new cluster
  mov al, ds:[bpb_sectorPerCluster]     ; Get amount of sectors in a cluster
  mov [bp - 19], al                     ; Reset the amount of sectors left to read in the current cluster to it

  mov di, [bp - 6]                      ; Get the previous cluster number 
  call getNextCluster                   ; Get the next cluster in the cluster chain

  cmp ax, 0FFF8h                        ; Check if its the end of the cluster chain
  jae .retBytesRead                     ; If it is then return the amount of bytes we read so far

  mov [bp - 6], ax                      ; If its not the end of the cluster chain then update the cluster number

  mov di, ax                            ; Set argument for clusterToLBA, the cluster number
  call clusterToLBA                     ; Get the new cluster`s LBA address in AX
  mov [bp - 12], ax                     ; Update the LBA address to the new one we just got
  jmp .readSectorsLoop                  ; Continue reading the file

.retBytesRead:
  mov ax, [bp - 16]                     ; Get the amount of bytes we read so far, and return with it

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