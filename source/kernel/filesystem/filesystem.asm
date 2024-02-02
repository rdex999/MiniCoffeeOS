;
;   ---------- [ FUNCTIONS FOR THE FILESYSTEM ] ----------
;

%ifndef FILESYSTEM_ASM
%define FILESYSTEM_ASM

%include "source/bootloader/macros/getRegions.asm"

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


; Reads sectors from the given LBA and stores data in a buffer.
; PARAMS
;   - 0) DI     => LBA
;   - 1) SI     => Amount of sectors to read
;   - 2) ES:BX  => Buffer
; RETURNS
;   In AH => 0 on success, and 1 on failure.
readDisk:
  pusha                         ; push all registers because BIOS messes them up
  push bx                       ; save data buffer
  call lbaToChs                 ; convert LBA from DI to CHS
  mov ax, si                    ; AL = number of sectors to read
  mov ah, 2                     ; read interrupt number
  mov dl, [ebpb_driveNumber]    ; get drive number
  pop bx                        ; restore data buffer
  int 13h                       ; read!
  popa
  jc readDisk_error
  
  xor ax, ax
  ret

readDisk_error:
  mov ax, 1
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

; Searches for an entry in the root directory.
; PARAMS
;   - 0) ES:DI  => File name. 11 byte string all capital.
;   - 1) DS:SI  => First entry in the root directory.
; RETURNS
;   in AX, the offset to the first byte of the files entry.
;   If not found, BX is 1, if found, BX is 0
searchInRootDir:
  push bp
  mov bp, sp
  sub sp, 4

  mov [bp - 2], di                      ; File name
  mov [bp - 4], si                      ; First entry in root directory

searchInRootDir_searchEntry:
  mov cx, 11
  repe cmpsb
  je searchInRootDir_found

  mov di, [bp - 2]
  add word [bp - 4], 32
  mov si, [bp - 4]
  jmp searchInRootDir_searchEntry

searchInRootDir_found:
  lea ax, [si - 11]
  xor bx, bx 
  mov sp, bp
  pop bp
  ret


; Searches for a file and loads it to memory at buffer 
; PARAMS
;   - 0) DI     => file name, 11 bytes all capital
;   - 1) ES:BX  => buffer to store data in
; RETURNS
; 0 on success and 1 on failure.
readFile:
  pusha
  push bp
  mov bp, sp

  sub sp, 8                 ; allocate 8 bytes
  mov [bp - 2], di          ; store file name
  mov [bp - 4], bx          ; store buffer pointer offset
  mov [bp - 6], es          ; store buffer pointer segment

  mov bx, KERNEL_SEGMENT
  mov es, bx 

  GET_ROOT_DIR_OFFSET       ; get the root directory offset (in sectors) in AX
  mov si, ax                ; save for now in SI
  GET_ROOT_DIR_SIZE         ; get the size of the root directory (in sectors) in AX

  ; Read the root directory

  ; Here *(bp - 8) is used for storing segment registers
  mov [bp - 8], es                ; Store ES segment, because changing it soon
  sub sp, [bpb_bytesPerSector]    ; Allocate memory for 1 sector, for reading the root directory
  
  mov bx, ss                      ;
  mov es, bx                      ; ES:BX points to buffer to store the root directory in

  mov di, si                      ; first argument for readDisk, LBA address
  mov si, 1                       ; second argument for readDisk, how many sectors to read
  mov bx, sp                      ; third argument for readDisk, data buffer to store the data in. ES:BX
  call readDisk

  mov bx, [bp - 8]
  mov es, bx                      ; Restore ES segment

  mov di, [bp - 2]                ; ES:DI Points to file name string (file name in *(bp - 2))
  mov bx, ss                      ;
  mov ds, bx                      ; Set data segment to stack segment, because the root directory is in the stack segment
  mov si, sp                      ; DS:SI points to root directory location
  call searchInRootDir

  mov bx, [bp - 8]                ; Restore ES and DS segments to original value
  mov es, bx                      ;
  mov ds, bx                      ;

  mov di, ax                      ; searchInRootDir returns pointer to the directory entry in AX
  mov ax, ss:[di + 26]            ; Get the low 16 bits of the first cluster number

  ; Now *(bp - 8) will be used as the cluster number
  mov [bp - 8], ax                ; Store cluster number at *(bp - 8)

  ; Read FAT into memory 
  mov bx, FATs                        ;
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
  mov di, [FATs + di]                     ; DI = FAT[di]  // Get next cluster number

  cmp di, 0FFF8h                          ; Check for end of cluster chain
  jb readFile_processClusterChain         ; unsigned jump if below

  xor ax, ax                              ; Read was successfull, return 0

readFile_end:
  mov sp, bp
  pop bp
  popa
  ret


%endif