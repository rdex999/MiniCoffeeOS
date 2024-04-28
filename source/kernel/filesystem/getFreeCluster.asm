;
; ---------- [ GET A FREE CLUSTER FROM THE FAT ] ---------
;

%ifndef GET_FREE_CLUSTER_ASM
%define GET_FREE_CLUSTER_ASM

; Get a cluster thats currently unused, starting from a specific cluster
; PARAMS
;   - 0) DI   => The cluster number to start searching from (if u dont care, just say 2)
;                If the given cluster is free, then the function will return the next cluster thats free.
; RETURNS
;   - 0) In AX, the free clusters index, can return 0 on failure
getFreeCluster:
  push bp
  mov bp, sp
  sub sp, 11

  ; *(bp - 2)     - Old ES segment
  ; *(bp - 4)     - Cluster number to start from (the parameter)
  ; *(bp - 6)     - Sector buffer offset (segment is SS)
  ; *(bp - 8)     - Current LBA in FAT
  ; *(bp - 9)     - Sectors left to read in FAT
  ; *(bp - 11)    - The offset in the sector

  mov [bp - 2], es                    ; Store old ES segment
  mov [bp - 4], di                    ; Store first cluster number

  mov bx, KERNEL_SEGMENT              ; Set ES to the kernel segment so we can access things
  mov es, bx                          ;
  
  push ds                             ; Save DS, because were gonna change it for a sec
  mov ds, bx                          ; Set DS to kernel segment so GET_FILE_ALLOCATION_TABLES_SIZE can read correct values
  GET_FILE_ALLOCATION_TABLES_SIZE     ; Get the size of the FAT is sectors, in AL
  pop ds                              ; Restore DS
  mov [bp - 9], al                    ; Store the size of the FAT

  mov bx, es:[bpb_bytesPerSector]     ; Get the size of a sector in BX
  sub sp, bx                          ; Allocate space for 1 sector on the stack
  mov [bp - 6], sp                    ; Store the sector buffer offset

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = AX = cluster / bytesPerSector;
  ; clusterIndex = DX = cluster % bytesPerSector;
  mov ax, [bp - 4]                    ; Get the first cluster number
  inc ax                              ; Increase it by 1 so we skip the given cluster
  xor dx, dx                          ; Zero out remainder
  div bx                              ; Divide the cluster number by the size of a sector
  mov [bp - 11], dx                   ; Store the new FAT index

  mov di, es:[bpb_reservedSectors]    ; Get the first sector of the FAT
  add di, ax                          ; Add to it the sector offset we just calculated
  mov [bp - 8], di                    ; Store the LBA

.nextSector:
  mov di, [bp - 8]                    ; Get the LBA, for readDisk
  mov si, 1                           ; How many sectors to read
  mov bx, ss                          ; Set ES:BX = SS:sectorBufferOffset
  mov es, bx                          ; Set segment, ES = SS
  mov bx, [bp - 6]                    ; Set offset, BX = sectorBufferOffset
  call readDisk                       ; Read 1 sector of FAT into the sector buffer
  test ax, ax                         ; Check error code
  jnz .err                            ; If there was an error then return 0 (which indicates an error)

  mov bx, KERNEL_SEGMENT              ; Set ES to kernel segment so we can access stuff
  mov es, bx                          ;

  mov cx, es:[bpb_bytesPerSector]     ; Get the amount of bytes in a sector
  sub cx, [bp - 11]                   ; Subtract from it the offset
  shr cx, 1                           ; Divide the result by 2, and get the amount of iterations in the loop that searches the empty cluster

  mov di, [bp - 6]                    ; Get a pointer to the sector buffer

  mov ax, [bp - 11]                   ; Get the cluster index in AX
  shl ax, 1                           ; Multiply it by 2, each cluster is 2 bytes
  add di, ax                          ; Add the result to the sector buffer
.searchEmtpy:
  cmp word ss:[di], 0                 ; Check if the current cluster is free
  je .foundEmpty                      ; If it is, then jump

  add di, 2                           ; If its not free, then increase the sector buffer pointer to point to the next cluster
  loop .searchEmtpy                   ; Continue until there are no more clusters to check

  ; Will get here is the current sector in FAT didnt have any free cluster.
  ; In that case we increase the LBA, check if there are any more clusters to check (if not then return 0) and read another sector.
  dec byte [bp - 9]                   ; Decrement the amount of sectors left to read
  jz .err                             ; If its zero then return 0 (to indicate an error)

  mov word [bp - 11], 0               ; Reset the cluster index to 0

  inc word [bp - 8]                   ; Increase the LBA
  jmp .nextSector                     ; Read another sector into memory

.foundEmpty:
  mov bx, KERNEL_SEGMENT              ; If we found an empty cluster, set ES to the kernel segment
  mov es, bx                          ;

  mov ax, [bp - 8]                    ; Get the current LBA
  sub ax, es:[bpb_reservedSectors]    ; Subtract from it the LBA of the first sector of the FAT (get how many sectors we skipped)

  mov bx, es:[bpb_bytesPerSector]     ; Get the size of a sector
  shl bx, 1                           ; Multiply it by 2, because dividing by 2 later (it makes sense)
  mul bx                              ; Multiply the amount of sectors we skipped by the size of a sector*2 Get the FAT index for the sector

  sub di, [bp - 6]                    ; Subtract the beginning of the sector buffer from the location of the current cluster (index in the sector)
  add ax, di                          ; Add the result to the thing we calculated before (which is in AX)
  shr ax, 1                           ; Divide the result by 2, and get the free cluster

.end:
  mov es, [bp - 2]                    ; Restore old ES segment
  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  ret

.err:
  xor ax, ax
  jmp .end

%endif