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
;   - 0) ES:DI      => Buffer to store files data in
;   - 1) DS:SI      => File name, 11 bytes all capital
; RETURNS
; 0 on success and 1 on failure.
readFile:
  push bp
  mov bp, sp

  sub sp, 14                 ; allocate 8 bytes

  mov [bp - 2], es          ; Store buffer segment
  mov [bp - 4], di          ; Store buffer offset
  mov [bp - 6], ds          ; Store file name segment
  mov [bp - 8], si          ; Store file name offset

  sub sp, [bpb_bytesPerSector]        ; Allocate space on the stack for one sector

  GET_ROOT_DIR_OFFSET                 ; Get the first sector of the root directory in AX

  mov [bp - 10], ax                   ; Save the sector number at *(bp - 10)

readFile_searchFileNextSector:
  ; Read one sector from the root directory into the stack, to search for the files entry
  mov di, [bp - 10]                   ; Get sector in root directory
  mov bx, ss                          ; Set buffer segment to stack segment as we will save the data to the stack
  mov es, bx                          ; 
  mov bx, sp                          ; Set buffer offset to the stack pointer as the stack pointer already points to our buffer
  mov si, 1                           ; Read one sector
  call readDisk

  inc word [bp - 10]                  ; Increase the sector number (of the root directory)

; Set segments and counters to prepare for the file entry search loop
  mov bx, [bp - 6]                    ; Set data segment to the file path segment
  mov ds, bx                          ;

  ; Will subtract 32 from DX each iteration, as each entry is 32 bits.
  ; DX is used as a counter for how many file entries are left to read in the current loaded sector
  mov dx, [bpb_bytesPerSector]        ; Get the number of bytes in a sector in DX

  mov di, sp                          ; Make DI point to the sector in which there are file entries

readFile_searchFileLoop:
  mov si, [bp - 8]                    ; Set SI to the file path string

  mov cx, 11                          ; Compare 11 bytes
  cld                                 ; Clear direction flag so cmpsb will increase DI and SI
  mov ax, di                          ; Save DI in AX
  rep cmpsb
  je readFile_foundFile               ; If found the file then jump

  ; Will get here if the current entry isnt the file
  mov di, ax                          ; Restore buffer pointer, of the root directories entries

  sub dx, 32                          ; Decrement entries counter 
  jz readFile_searchFileNextSector    ; If its zero then load a new sector of the root directory into memory

  add di, 32                          ; Increase root directory buffer pointer
  jmp readFile_searchFileLoop         ; Continue searching for the files entry

readFile_foundFile:
  mov di, es:[di - 11 + 26]           ; Get the first cluster number of the file
  mov word [bp - 12], 0FFFFh          ; *(bp - 12) is the sector offset, set it to 0FFFFH so the first iteration will load the FAT

; Every time we get here the cluster number must be in DI
readFile_processClusterChain:
  mov [bp - 10], di                   ; Save the cluster number at *(bp - 10)
  call clusterToLBA                   ; Convert the cluster number to an LBA address which will be in AX

  mov di, ax                          ; Set DI to the LBA address as its the first argument for readDisk
  mov bx, [bp - 2]                    ; Set ES to the buffer segment, second argument for readDisk
  mov es, bx                          ;
  mov bx, [bp - 4]                    ; Set BX to the buffer offset, second argument for readDisk
  mov al, [bpb_sectorPerCluster]      ; How many sectors to read, in this case one cluster. (the number of sectors in a cluster)
  xor ah, ah                          ; bpb_sectorPerCluster is 8 bits (1 byte)
  mov si, ax                          ; Number of sectors to read
  call readDisk

; Calculate the amount of bytes in a cluster and add it to the buffer so it points to the next location
  mov al, [bpb_sectorPerCluster]      ; Get the number of sectors in a cluster
  xor ah, ah                          ; 
  mov bx, [bpb_bytesPerSector]        ; Get the number of bytes in a sector
  mul bx                              ; Multiply them 
  add [bp - 4], ax                    ; Add the result to the buffer pointer so it points to the next location

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;
  mov ax, [bp - 10]                   ; Get the cluster number
  mov bx, [bpb_bytesPerSector]        ; Get the number of bytes in a sector
  xor dx, dx                          ; Zero out remainder register
  div bx                              ; Divibe the cluster number by the amount of bytes in a sector

  mov [bp - 14], dx                   ; Store the new index in FAT

  cmp ax, [bp - 12]                   ; Compare the cluster offset to the old one, 
  je readFile_afterReadFAT            ; if they are the same there is no need to read the same FAT sector once again

  ; If not the same then prepare arguments for readDisk and read the FAT sector. Also save the new FAT sector offset
  mov [bp - 12], ax                   ; Save FAT sector offset

  mov di, ax                          ; Set DI to the FAT sector offset
  add di, [bpb_reservedSectors]       ; Add to it the number of reserved sectors to get the first sector of the FAT (with the offset)
  mov si, 1                           ; How many sectors to read, 1 in this case

  mov bx, ss                          ; Read the sector to the stack (space already allocated)
  mov es, bx                          ; Set buffer segment to stack segment
  mov bx, sp                          ; Set buffer offset to the stack pointer as it points to the beginning of the buffer
  call readDisk

  mov dx, [bp - 14]                   ; Restore the index in FAT

; When getting here the index in FAT is in DX
readFile_afterReadFAT:
  mov di, dx                          ; Set DI to the index in FAT
  shl di, 1                           ; Multiply the index by 2 as each fat entry is 2 bytes
  add di, sp                          ; Add the buffer pointer to the index so it points to the cluster number
  mov di, ss:[di]                     ; Get the cluster number in DI
  cmp di, 0FFF8h                      ; Check for the end of the cluster chain
  jb readFile_processClusterChain     ; If not the end then continue reading clusters

readFile_end:
  mov sp, bp                          ; Restore stack frame
  pop bp                              ;
  ret

%endif