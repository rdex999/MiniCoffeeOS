;
; ---------- [ READS FROM THE CLUSTERS AND STORES DATA IN BUFFER ] ----------
;

; Read each cluster and write data to buffer
; PARAMS
;   - 0) DI     => First cluster number
;   - 1) ES:BX  => Buffer to store data in
; RETURNS
;   - In AX, the error code. 0 for no error.
ReadClusterChain:
  push bp
  mov bp, sp
  sub sp, 12

  ; Save arguments
  mov word [bp - 2], 0FFFFh       ; Store cluster sector offset from fat. Set to FFFF so the first iteration it will read FAT
  mov [bp - 4], es                ; Store buffer segment
  mov [bp - 6], bx                ; Store buffer offset
  mov [bp - 8], di                ; cluster number

  mov ax, KERNEL_SEGMENT          ; Set data segment to KERNEL_SEGMENT, we dont know what is DS when the function was called.
  mov ds, ax                      ;

  sub sp, [bpb_bytesPerSector]    ; Allocate space for 1 sector
  mov [bp - 12], sp               ; Save FAT sector pointer 

  ; When getting here the cluster number is allways in DI
ReadClusterChain_readCluster:
  call clusterToLBA               ; Convert the cluster number to an LBA address
  mov di, ax                      ; DI = LBA address. As first argument for readDisk

  ; Set arguments for readDisk and read a cluster of the file into buffer 
  mov al, [bpb_sectorPerCluster]  ; Because sectorPerCluster is 8 bits
  xor ah, ah                      ;
  mov si, ax                      ; How many sectors to read, the number of sectors in a cluster

  mov bx, [bp - 4]                ; ES:BX points to receiving data buffer
  mov es, bx                      ;
  mov bx, [bp - 6]                ; Set buffer offset
  call readDisk
  test ax, ax                     ; Checl exit code of readDisk
  jnz ReadClusterChain_end        ; If its not 0 then return, and return it in AX

  ; Calculate the number of bytes in a sector and add it to the buffer.
  ; buffer += bytesPerSector * sectorsPerCluster;
  mov ax, [bpb_bytesPerSector]    ; AX = bytes in 1 sector 
  mov bx, [bpb_sectorPerCluster]  ; BX = number of sectors in a cluster
  mul bx                          ; AX *= BX
  add [bp - 6], ax                ; Increase buffer to point to next location

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;
  mov ax, [bp - 8]                ; AX = cluster number
  mov bx, [bpb_bytesPerSector]    ; BX = bytes in 1 sector
  xor dx, dx                      ; Zero out remainder register before division
  div bx                          ; Divibe the cluster number by the amount of bytes in 1 sector
  mov [bp - 10], dx               ; Store relative index at *(bp - 10)

  cmp ax, [bp - 2]                ; Check if the new sector offset is the same as the old one
  je ReadClusterChain_skipNewFat  ; If the same then there is no need to read again the same FAT sector. Skip the FAT read

  ; Prepare arguments for readDisk and read a new sector of FAT into memory
  mov [bp - 2], ax                ; Store new custer sector offset
  mov di, [bpb_reservedSectors]   ; Get the first sector of FAT in DI
  add di, ax                      ; AX is an offset, so add the first sector of FAT to it to get the sector that we need

  mov si, 1                       ; Read 1 sector

  mov bx, ss                      ; ES:BX points to receiving data buffer. Store it on the stack
  mov es, bx                      ; Set Segment
  mov bx, [bp - 12]               ; Set buffer offset, stored on *(bp - 12)

  call readDisk                   ; Read a sector of fat into memory
  test ax, ax                     ; Check exit code of readDisk
  jnz ReadClusterChain_end        ; If its not zero then return and return it as the exit code

ReadClusterChain_skipNewFat:
  mov si, [bp - 10]               ; Get index in FAT in SI
  shl si, 1                       ; Because each FAT entry is 2 bytes, multiply the index by 2
  add si, [bp - 12]               ; Add to the index a pointer to FAT, so SI points to the cluster number
  mov di, ss:[si]                 ; Set DI to the next cluster number
  mov [bp - 8], di                ; Store the next cluster number
  cmp di, 0FFF8h                  ; Check if its the end of the cluster chain
  jb ReadClusterChain_readCluster ; If not the end then continue reading clusters

  xor ax, ax                      ; Read was successful, return 0
ReadClusterChain_end:
  mov sp, bp
  pop bp
  ret