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
  sub sp, 14                            ; Allocate space for local variables

  ; *(bp - 2)   - Buffer segment
  ; *(bp - 4)   - Buffer offset
  ; *(bp - 6)   - Cluster number
  ; *(bp - 8)   - Byte offset
  ; *(bp - 10)  - Amount of bytes to read
  ; *(bp - 12)  - LBA
  ; *(bp - 14)  - Old DS

  mov [bp - 2], es                      ; Store buffer pointer
  mov [bp - 4], di                      ; (ES:DI)
  mov [bp - 6], si                      ; Store first cluster number
  mov [bp - 8], dx                      ; Store bytes offset 
  mov [bp - 10], cx                     ; Store amount of bytes to read
  mov [bp - 14], ds                     ; Store old DS segment

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

  pusha                                                                   ;;;;;;;; DEBUG
  mov bx, [bp - 8]                                                        ;;;;;;;;
  mov ax, [bp - 6]                                                        ;;;;;;;;
  PRINTF_M `starting on cluster 0x%x with bytes offset of %u\n`, ax, bx   ;;;;;;;;
  popa                                                                    ;;;;;;;;

.afterCalcClusterSkip:



.end:
  mov ds, [bp - 14]                             ; Restore old DS segment
  mov sp, bp                                    ; Restore stack frame
  pop bp                                        ;
  ret

.err:
  xor ax, ax                                    ; If there is an error, we return 0 to indicate 0 bytes were read
  jmp .end                                      ; Return

%endif
