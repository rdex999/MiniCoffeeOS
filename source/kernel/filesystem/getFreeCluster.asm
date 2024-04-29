;
; ---------- [ GET A FREE CLUSTER FROM THE FAT ] ---------
;

%ifndef GET_FREE_CLUSTER_ASM
%define GET_FREE_CLUSTER_ASM

; Get a cluster thats currently unused, starting from a specific cluster
; PARAMS
;   - 0) DI   => The value to set the free cluster to
; RETURNS
;   - 0) In AX, the free clusters index, can return 0 on failure
getFreeCluster:
  push bp
  mov bp, sp
  sub sp, 9

  ; *(bp - 2)     - Old ES segment
  ; *(bp - 4)     - The value to set the free cluster to
  ; *(bp - 6)     - Sector buffer offset (segment is SS)
  ; *(bp - 8)     - Current LBA in FAT
  ; *(bp - 9)     - Sectors left to read in FAT

  mov [bp - 2], es                    ; Store old ES segment
  mov [bp - 4], di                    ; Store free cluster requested value

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

  mov di, es:[bpb_reservedSectors]    ; Get the first sector of FAT
  mov [bp - 8], di                    ; Store it as the current LBA in FAT

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
  shr cx, 1                           ; Divide the result by 2, and get the amount of iterations in the loop that searches the empty cluster

  mov bx, ss                          ; Set ES:DI = sectorBuffer    // Because SCASW will compare AX to a word at ES:DI
  mov es, bx                          ; Set ES = SS   // Because the sector buffer is on the stack
  mov di, [bp - 6]                    ; Get a pointer to the sector buffer offset

  xor ax, ax                          ; Zero AX, because SCASW will compare AX to ES:DI, and we want to check for a free cluster
  cld                                 ; Clear direction flag so SCASW will increase DI each time
.searchEmtpy:
  ; As long as *(uint16_t*)(ES:DI) != 0, continue checking clusters until CX is 0
  ; Will exit from it only if CX has hit 0, or we found an empty cluster
  repnz scasw                         ; Check for empty clusters, in the current FAT sector
  je .foundEmpty                      ; If we did found an empty cluster, calculate its cluster number, and set its value.

  ; cmp word ss:[di], 0               ; Check if the current cluster is free

  ; add di, 2                           ; If its not free, then increase the sector buffer pointer to point to the next cluster
  ; loop .searchEmtpy                   ; Continue until there are no more clusters to check

  ; Will get here is the current sector in FAT didnt have any free cluster.
  ; In that case we increase the LBA, check if there are any more clusters to check (if not then return 0) and read another sector.
  dec byte [bp - 9]                   ; Decrement the amount of sectors left to read
  jz .err                             ; If its zero then return 0 (to indicate an error)

  inc word [bp - 8]                   ; Increase the LBA
  jmp .nextSector                     ; Read another sector into memory

.foundEmpty:
  sub di, 2                           ; SCASW is incrementing DI by 2 each time, even after AX is equal to *(ES:DI)
  push di                             ; Save the pointer to the cluster in the current sector of FAT
  mov ax, [bp - 4]                    ; Get the requested value to set the cluster to (the parameter)
  mov ss:[di], ax                     ; Set the free cluster to the requested value

  ; Prepare arguments for writeDisk, because we will write out changes to the disk
  push ds                             ; Save DS, because were gonna change it for a sec
  mov bx, ss                          ; Set DS:SI = sectorBuffer    // The data source, from where to write
  mov ds, bx                          ; Set segment, DS = SS    // Sector buffer is stored on the stack
  mov si, [bp - 6]                    ; Set SI = sectorBuffer.offset

  mov dx, 1                           ; Amount of sectors to read     // Read 1 sector
  mov di, [bp - 8]                    ; The LBA to write into
  call writeDisk                      ; Write the changes we made to the sector, to the hard disk
  pop ds                              ; Restore DS segment
  pop di                              ; Restore cluster pointer (a pointer to the free cluster in the sector buffer)
  test ax, ax                         ; Check error code of writeDisk
  jnz .err                            ; If there was an error then return 0

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
  xor ax, ax                          ; If there is an error, we return null (which is an invalid cluster number)
  jmp .end

%endif