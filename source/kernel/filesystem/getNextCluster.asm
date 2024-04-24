;
; ---------- [ GET THE CLUSTERS NEXT CLUSTER ] ---------
;

%ifndef GET_NEXT_CLUSTER_ASM
%define GET_NEXT_CLUSTER_ASM


; Get the next cluster number in a cluster chain
; PARAMS
;   - 0) DI   => Current cluster number
; RETURNS
;   - 0) In AX, the next cluster number. BX is the error code.
getNextCluster:
  push bp                                 ; Save stack frame
  mov bp, sp                              ;
  sub sp, 6                               ; Allocate space for local variables

  ; *(bp - 2)     - Old DS segment
  ; *(bp - 4)     - Stack sector buffer offset
  ; *(bp - 6)     - Old ES segment

  mov [bp - 2], ds                        ; Save used segments
  mov [bp - 6], es                        ;

  mov bx, KERNEL_SEGMENT                  ; Set DS to kernel segment 
  mov ds, bx                              ; so we can access kernel variables

  mov bx, ds:[bpb_bytesPerSector]         ; Get amount of bytes in a sector
  sub sp, bx                              ; Allocate space for 1 sector on the stack
  mov [bp - 4], sp                        ; Store sector buffer offset

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;
  mov ax, di                              ; Get cluster number in AX
  xor dx, dx                              ; Zero out remainder register
  div bx                                  ; Divide cluster number by the amount of bytes in a sector
  push dx                                 ; Save new cluster index

  mov di, ds:[bpb_reservedSectors]        ; Get first sector of FAT in DI
  add di, ax                              ; Add to it the sector offset we just calculated
  mov si, 1                               ; Read 1 sector

  mov bx, ss                              ; Set ES:BX to SS:SP (the sector buffer)
  mov es, bx                              ; Set ES = SS
  mov bx, [bp - 4]                        ; Set BX = sectorBufferOffset
  call readDisk                           ; Read 1 sector of FAT into the sector buffer
  pop di                                  ; Restore new cluster index
  test ax, ax                             ; Check if readDisk returned an error
  jnz .err                                ; If it did then return with its error code

  ; If readDisk didnt return an error then we multiply the index by 2 (each cluster is 2 bytes) and get the next cluster number
  shl di, 1                               ; Multiply index by 2
  add di, [bp - 4]                        ; Add the new index to the sector buffer offset, so SS:DI points to our new cluster number
  mov ax, ss:[di]                         ; Get new cluster number
  xor bx, bx                              ; Return with error 0 (no error)

.end:
  mov ds, [bp - 2]                        ; Restore DS segment
  mov es, [bp - 6]                        ; Restore ES segment
  mov sp, bp                              ; Restore stack frame
  pop bp                                  ;
  ret

.err:
  mov bx, ax                              ; Assume error code is in AX, so put it in BX
  jmp .end                                ; Return
%endif