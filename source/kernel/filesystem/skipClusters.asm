;
; ---------- [ CALCULATE THE NEW CLUSTER & SECTOR FROM A GIVEN BYTES OFFSET ] ----------
;

%ifndef SKIP_CLUSTERS_ASM
%define SKIP_CLUSTERS_ASM


; Calculates the new cluster (if any) for a given offset in a cluster chain
; Also calculates the new LBA (bacause you can also skip sectors) 
; and as well as the amount of sectors left to read in the current cluster
; PARAMS
;   - 0) DI   => Current cluster number
;   - 1) SI   => Bytes offset
; RETURNS
;   - 0) In AX, the new cluster number
;   - 1) In BX, the new LBA
;   - 2) In CX, the amount of sectors left in the current cluster
;   - 3) In DX, the new bytes offset
;   - 4) Error code in SI (0 for success)
skipClusters:
  push bp
  mov bp, sp
  sub sp, 8

  mov [bp - 2], ds                      ; Store old DS segment
  mov [bp - 4], di                      ; Store cluster number
  mov [bp - 6], si                      ; Store bytes offset

  mov bx, KERNEL_SEGMENT                ; Set DS to kernels segment so we can access stuff
  mov ds, bx                            ;

  call clusterToLBA                     ; Convert the current cluster to an LBA address
  mov [bp - 8], ax                      ; Store LBA

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

  mov ax, [bp - 6]                      ; Get requested bytes offset
  xor dx, dx                            ; Zero out remainder register
  
  ; AX = byteOffset / bytesPerCluster = clustersToSkip
  ; DX = byteOffset % bytesPerCluster = newBytesOffset
  div bx                                ; Calculate

  test ax, ax                           ; Check if there are even any clusters to skip
  jz .afterCalcClusterSkip              ; If 0 clusters to skip then skip the part which skips clusters (read it again)

  ; If there are some clusters we can skip, then skip them and store the new bytes offset
  mov [bp - 6], dx                      ; Store the new bytes offset
  mov cx, ax                            ; Loop through the amount of clusters to skip
.skipClustersLoop:
  mov di, [bp - 4]                      ; Get current cluster number
  push cx                               ; Save amount of clusters left to skip
  call getNextCluster                   ; Get the next cluster number, from out current one
  pop cx                                ; Restore amount of clusters left to skip
  test bx, bx                           ; Check if getNextCluster has returned with an error
  jnz .err                              ; If it did, then return 0 to indicate an error

  cmp ax, 0FFF8h                        ; Check if its the end of the cluster chain
  jae .err                              ; If it is, then return 0 because we couldnt even reach the files first byte with the given offset

  mov [bp - 4], ax                      ; If its not the end of the cluster chain, then update the first cluster number variable
  loop .skipClustersLoop                ; Continue skipping clusters until CX (amount of clusters to skip) is 0

.afterCalcClusterSkip:
  ; Get the LBA of the new cluster
  mov di, [bp - 4]                      ; Get first cluster number (updated)
  call clusterToLBA                     ; Get its LBA in AX
  mov [bp - 8], ax                      ; Store LBA

  ; Calculate the amount of sectors to skip
  ; The formula
  ; sectorsToSkip = byteOffset / bytesPerSector
  ; newByteOffset = byteOffset % bytesPerSector
  mov bx, ds:[bpb_bytesPerSector]       ; Get amount of bytes in a sector
  mov ax, [bp - 6]                      ; Get bytes offset
  xor dx, dx                            ; Zero out remainder register
  
  ; AX = sectorsToSkip  = byteOffset{AX} / bytesPerSector{BX}
  ; DX = newBytesOffset = byteOffset{AX} % bytesPerSector{BX}
  div bx                                ; Calculate

  mov [bp - 6], dx                      ; Update the bytes offset
  add [bp - 8], ax                      ; Increase the LBA

  ; sectorsLeftInCluster = sectorsPerCluster - sectorOffset
  mov cl, ds:[bpb_sectorPerCluster]     ; Get amount of sectors in a cluster
  sub cl, al                            ; Subtract from it the cluster offset

  xor ch, ch                            ; Zero out high part of the amount of sectors left in the current cluster

  mov ax, [bp - 4]                      ; Get new cluster number
  mov bx, [bp - 8]                      ; Get new LBA
  mov dx, [bp - 6]                      ; Get new bytes offset
  xor si, si                            ; Zero out error code

.end:
  mov ds, [bp - 2]                      ; Restore old DS segment
  mov sp, bp                            ; Restore stack frame
  pop bp                                ;
  ret

.err:
  mov si, 1                             ; On error we return 1
  jmp .end                              ; Return

%endif