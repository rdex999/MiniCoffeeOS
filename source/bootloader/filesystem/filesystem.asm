;
; ---------- [ FUNCTIONS FOR READING/WRITING FILES ] ----------
;

%ifndef FILESYSTEM_ASM
%define FILESYSTEM_ASM

%include "source/bootloader/macros/macros.asm"

; Converts LBA (Logical Block Address) to CHS (Cylinder Head Sector)
; PARAMS
;   - 1) DI => LBA address
; RETURNS
;   - CH => cylinder
;   - CL => sector
;   - DH => head
lbaToChs:
  mov ax, di                      ;
  mov bx, [bpb_sectorsPerTrack]   ; LBA / sectorsPerTrack
  xor dx, dx                      ;
  div bx                          ; AX = AX / BX ;; DX = %

  inc dx                          ;
  mov cl, dl                      ; sector = (LBA % sectorsPerTrack) + 1

  ; AX containes LBA/sectorsPerTrack
  mov bx, [bpb_numberOfHeadsOrSides]    ;
  xor dx, dx                            ;
  div bx                                ;
  mov dh, dl                            ; head = (LBA / sectorsPerTrack) % heads

  mov ch, al                            ; cylinder = (LBA / sectorsPerTrack) / heads
  ret


; Reads sectors from given LBA and stores data in a buffer.
; PARAMS
;   - 0) DI     => LBA
;   - 1) SI     => Amount of sectors to read
;   - 2) ES:BX  => Buffer
readDisk:
  push bx                       ; save data buffer
  call lbaToChs                 ; convert LBA from DI to CHS
  mov ax, si                    ; AL = number of sectors to read
  mov ah, 2                     ; read interrupt number
  mov dl, [ebpb_driveNumber]    ; get drive number
  pop bx                        ; restore data buffer
  int 13h                       ; read!
  ret


; converts a cluster number to LBA address
; PARAMS
;   - 0) DI   => cluster address
; RETURNS
;   returns in AX the LBA address
clusterToLBA:                       ; LBA = dataRegionOffset + (cluster - 2) * sectorsPerCluster
  sub di, 2                         ; DI = cluster - 2
  mov ax, di                        ; AX = cluster - 2
  xor bh, bh
  mov bl, [bpb_sectorPerCluster]    ;
  mul bx                            ; AX *= sectorsPerCluster
  push ax                           ; Save for now
  GET_DATA_REGION_OFFSET            ; Get data region first sector in AX
  pop bx
  add ax, bx                        ; add to result
  ret


; Searches for a file and loads it to memory at buffer 
; PARAMS
;   - 0) DI     => file name, 11 bytes all capital
;   - 1) ES:BX  => buffer to store data in
; RETURNS
; 0 on success and 1 on failure.
readFile:
  push bp
  mov bp, sp

  sub sp, 8                 ; allocate 8 bytes
  mov [bp - 2], di          ; store file name
  mov [bp - 4], bx          ; store buffer pointer offset
  mov [bp - 6], es          ; store buffer pointer segment
  xor bx, bx
  mov es, bx

  GET_ROOT_DIR_OFFSET       ; get the root directory offset (in sectors) in AX
  mov si, ax                ; save for now in SI
  GET_ROOT_DIR_SIZE         ; get the size of the root directory (in sectors) in AX

  mov di, si                ; first argument for readDisk, LBA address
  mov si, ax                ; second argument for readDisk, how many sectors to read
  mov bx, buffer            ; third argument for readDisk, data buffer to store the data in. ES:BX 0000h:7E00h
  call readDisk

  mov ax, [bpb_rootDirectoryEntries]
  xor bx, bx
readFile_searchFileLoop:
  mov di, buffer            ; get the location of the first thing in the root directory ( + 32 to skip the volume name)
  add di, bx                ; offset by BX (which grows by 32 each iteration) to get next entry
  mov si, [bp - 2]          ; get file name
  mov cx, 11                ; compare 11 bytes
  cld                       ; clear direction flag
  
  ; REPE will repeate the following instruction until CX is 0 (it decrements CX each time) 
  ; CMDSB (compare string bytes) compares byte at DS:DI to byte at ES:SI, and increment SI and DI if direction flag is 1
  repe cmpsb
  je readFile_foundFile

  add bx, 32                    ; each directory entry is 32 bytes (yes bytes and not bits)

  dec ax                        ; decrement entries counter
  jnz readFile_searchFileLoop   ; As long as there are any root directories left, continue reading. (AX is a counter for entries left)

  mov ax, 1                     ; Could not find file, return 1
  jmp readFile_end

readFile_foundFile:
  mov di, [di - 11 + 26]              ; get low 16 bits of entries first cluster number (26 is the offset and -11 because filename)
  mov [bp - 8], di

  ; Read FAT into memory at 7E00h
  xor bx, bx                          ; Read at 7E00h (ES:BX)
  mov es, bx                          ;
  mov bx, buffer                      ;
  mov di, [bpb_reservedSectors]       ; First sector of FATs
  mov si, [bpb_sectorsPerFAT]         ; How much to read
  call readDisk

  ; *(bp - 8) = index in FAT
  mov di, [bp - 8]
readFile_processClusterChain:
  call clusterToLBA                       ; Each time we get here, DI will have the cluster number. Convert it to an LBA address        

  mov di, ax                              ; First argument for readDisk, the LBA address
  xor ah, ah                              ; Because sectorPerCluster is 8 bits
  mov al, [bpb_sectorPerCluster] 
  mov si, ax                              ; Read one cluster (the number of sectors in a cluster)

  mov bx, [bp - 6]                        ; ES:BX points to receiving data buffer
  mov es, bx                              ;
  mov bx, [bp - 4]                        ;
  call readDisk

  ; Get number of bytes per cluster
  mov bx, [bpb_bytesPerSector]            ; bytesPerCluster = bytesPerSector * secotrsPerCluster
  xor ah, ah                              ; sectorPerCluster is 8 bits
  mov al, [bpb_sectorPerCluster]          ;
  mul bx                                  ;
  add [bp - 4], ax                        ; Make receivind data buffer point to next location

  ; Increment index of next cluster in FAT
  add word [bp - 8], 2                    ; Each FAT entry is 16 bits
  mov di, [bp - 8]                        ; DI = next cluster index in FAT
  mov di, [buffer + di]                   ; DI = FAT[di]  // Get next cluster number

  cmp di, 0FFF8h                          ; Check for end of cluster chain
  jb readFile_processClusterChain         ; unsigned jump if below

  xor bx, bx
  mov es, bx
  xor ax, ax                              ; Read was successfull, return 0

readFile_end:
  mov sp, bp
  pop bp 
  ret

%endif