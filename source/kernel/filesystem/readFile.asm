;
; ---------- [ FUNCTION FOR READING A FILE ] -----------
;

%ifndef FILESYSTEM_READFILE_ASM
%define FILESYSTEM_READFILE_ASM

; Searches for a file and loads it to memory at buffer 
; PARAMS
;   - 0) DS:DI     => file name, 11 bytes all capital
;   - 1) ES:BX  => buffer to store data in
; RETURNS
; 0 on success and 1 on failure.
readFile:
  push bp
  mov bp, sp

  sub sp, 10                ; allocate 8 bytes
  mov [bp - 2], di          ; store file name
  mov [bp - 4], bx          ; store buffer pointer offset
  mov [bp - 6], es          ; store buffer pointer segment
  mov [bp - 10], ds         ; Store file name segment

  mov bx, KERNEL_SEGMENT
  mov es, bx 

  sub sp, es:[bpb_bytesPerSector]    ; Allocate memory for 1 sector, for reading the root directory

  mov bx, [bp - 10]               ;
  mov es, bx                      ; File name segment

  mov di, [bp - 2]                ; ES:DI Points to file name string (file name in *(bp - 2))
  mov bx, ss                      ;
  mov ds, bx                      ; Set data segment to stack segment, because the root directory is in the stack segment
  mov si, sp                      ; DS:SI points to root directory location
  call searchInRootDir

  test bx, bx                     ; Check return status of searchInRootDir
  jnz readFile_error              ; If the return status of searchInRootDir is not 0 then return 1, otherwise continue

  mov bx, KERNEL_SEGMENT          ; Make segments point to where the kernel is
  mov ds, bx                      ;
  mov es, bx                      ;
  
  add sp, [bpb_bytesPerSector] ; Free allocated space

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
  ; Set segments to original value
  mov dx, [bp - 6]                ; ES segment original value
  mov es, dx                      ;
  mov dx, [bp - 10]               ; Data segment original value
  mov ds, dx                      ;

  mov sp, bp
  pop bp
  ret

readFile_error:
  mov ax, 1                               ; Read has failed, return 1
  jmp readFile_end


%endif