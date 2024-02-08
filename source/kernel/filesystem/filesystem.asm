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
  push bx                       ; save data buffer
  call lbaToChs                 ; convert LBA from DI to CHS
  mov ax, si                    ; AL = number of sectors to read
  mov ah, 2                     ; read interrupt number
  mov dl, [ebpb_driveNumber]    ; get drive number
  pop bx                        ; restore data buffer
  int 13h                       ; read!
  jc readDisk_error             ; Jump if int13h/AH=2 has failed
  
  xor ax, ax                    ; Read was successful, return 0
  ret

readDisk_error:
  mov ax, 1                     ; Read has failed, return 1
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
  sub sp, 12                            ; Allocate 12 bytes

  mov [bp - 2], di                      ; File name
  mov [bp - 4], si                      ; First entry in root directory
  mov [bp - 6], es                      ; Save segment registers because they will change
  mov [bp - 8], ds                      ;

  ; Get the root directory offset in sectors and store it in *(bp - 12)
  push ds                         ; Save data segment
  mov bx, KERNEL_SEGMENT          ;
  mov ds, bx                      ; Make data segment KERNEL_OFFSET to that GET_ROOT_DIR_OFFSET will read correct values
  GET_ROOT_DIR_OFFSET             ; Get the root directory offset in sectors in AX
  pop ds                          ; Restore data segment
  mov [bp - 12], ax               ; Store offset at *(bp - 12)


searchInRootDir_nextSector:
  mov word [bp - 10], 16                  ; *(bp - 8) // Directory entries counter // Reset entries counter

  ; Set the segment registers for readDIsk 
  mov bx, [bp - 8]                        ; ES:BX points to receiving data buffer
  mov es, bx                              ;
  mov bx, KERNEL_SEGMENT                  ;
  mov ds, bx                              ; Set data segment to KERNEL_OFFSET so readDisk will read correct values

  ; Set parameters for read disk. Going to read the root directory to ES:BX (1 sector)
  mov bx, [bp - 4]                        ; ES:BX points to receiving data buffer
  mov di, [bp - 12]                       ; LBA Address to read from
  mov si, 1                               ; How many sectors to read
  call readDisk

  mov bx, [bp - 6]                        ;
  mov es, bx                              ; Restore segment registers

  mov bx, [bp - 8]                        ;
  mov ds, bx                              ; Restore data segment

  test ax, ax                             ; Check if readDisk succeed
  jnz searchInRootDir_error               ; If readDisk has faild, return 1 in BX

  ; Search for the file directory entry. Increase the SI pointer by 32 each time to point to next entry.
  mov si, [bp - 4]                        ; Get first entry of root directory in SI
searchInRootDir_searchEntry:
  cmp byte ds:[si], 0                     ; If the first byte of the entry is 0 then there are no more entries left to read
  je searchInRootDir_error                ; If zero then return 1 in BX

  push si                                 ; Save current SI because REPE CMPSB will change it
  mov di, [bp - 2]                        ; Get file name in DI
  mov cx, 11                              ; Compare 11 bytes

  ; REPE  => Repeate the following instruction until CX is 0 (and decrement CX each time)
  ; CMPSB => (Compare string bytes) Compare byte at DS:SI to byte at ES:DI. If the direction flag is 0 then increment DI and SI
  repe cmpsb
  je searchInRootDir_found                ; If found then return a pointer to the file entry in AX

  pop si                                  ; Restore directory entry pointer (SI)
  add si, 32                              ; Make SI point to next directory entry

  dec word [bp - 10]                      ; Decrement nunber of entries left to read from current sector
  cmp word [bp - 10], 0                   ; If zero then read a new sector
  jne searchInRootDir_searchEntry         ; If not zero then continue searching for the file

  inc word [bp - 12]                      ; Increase the LBA for the root directory

  jmp searchInRootDir_nextSector          ; Read a new sector into memory

searchInRootDir_error:
  mov bx, 1                               ; Return 1 in BX on error
  jmp searchInRootDir_ret

searchInRootDir_found:
  lea ax, [si - 11]                       ; Return pointer to the file directory entry on success
  xor bx, bx                              ; Return status 0 (Success)
searchInRootDir_ret:
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
  push bp
  mov bp, sp

  sub sp, 8                 ; allocate 8 bytes
  mov [bp - 2], di          ; store file name
  mov [bp - 4], bx          ; store buffer pointer offset
  mov [bp - 6], es          ; store buffer pointer segment

  mov bx, KERNEL_SEGMENT
  mov es, bx 

  mov [bp - 8], es                ; Store ES segment, because changing it soon
  sub sp, es:[bpb_bytesPerSector]    ; Allocate memory for 1 sector, for reading the root directory

  mov di, [bp - 2]                ; ES:DI Points to file name string (file name in *(bp - 2))
  mov bx, ss                      ;
  mov ds, bx                      ; Set data segment to stack segment, because the root directory is in the stack segment
  mov si, sp                      ; DS:SI points to root directory location
  call searchInRootDir

  mov dx, [bp - 8]                ; Set segments to original value
  mov es, dx                      ;
  mov ds, dx                      ;

  add sp, es:[bpb_bytesPerSector] ; Free allocated space
  test bx, bx                     ; Check return status of searchInRootDir
  jnz readFile_error              ; If the return status of searchInRootDir is not 0 then return 1, otherwise continue/

  mov di, ax                      ; searchInRootDir returns pointer to the directory entry in AX
  mov ax, ss:[di + 26]            ; Get the low 16 bits of the first cluster number

  ; Now *(bp - 8) will be used as the cluster number
  mov [bp - 8], ax                ; Store cluster number at *(bp - 8)

  ; Read FAT into memory 
  mov bx, FATs                        ; Buffer for storing the FATs
  mov di, [bpb_reservedSectors]       ; First sector of FATs
  mov si, [bpb_sectorsPerFAT]         ; How much to read
  call readDisk

  ; *(bp - 8) = index in FAT
  mov di, [bp - 8]
readFile_processClusterChain:
  call clusterToLBA                       ; Each time we get here, DI will have the cluster number. Convert it to an LBA address        

  mov di, ax                              ; First argument for readDisk, the LBA address
  xor ah, ah                              ; Because sectorPerCluster is 8 bits
  mov al, [bpb_sectorPerCluster]          ; 
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
  ret

readFile_error:
  mov ax, 1                               ; Read has failed, return 1
  jmp readFile_end

%endif