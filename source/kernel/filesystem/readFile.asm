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

  sub sp, 12                ; allocate 8 bytes
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
  
  mov di, ax                      ; searchInRootDir returns pointer to the directory entry in AX
  mov ax, ss:[di + 26]            ; Get the low 16 bits of the first cluster number

  ; *(bp - 12) is the previous cluster number. Set it to 0 so that at the first iteration of the cluster chain
  ; It will load fat into memory (it loads fat into memory only when the previous cluster != newCluster)
  mov word [bp - 12], 0                 ; Set previous cluster number to 0
  mov [bp - 8], ax                      ; Store cluster number at *(bp - 8)
  mov di, ax                            ; DI = cluster number, its for the call to clusterToLBA
readFile_processClusterChain:
  call clusterToLBA
  mov di, ax                            ; Set DI to the LBA, for readDisk

  ; Set segments/pointers for readDisk
  mov bx, [bp - 6]                      ; ES:BX points to receiving data buffer. 
  mov es, bx                            ; *(bp - 6) is the buffer segment
  mov bx, [bp - 4]                      ; *(bp - 4) is the buffer

  ; Read a cluster of the file into memory
  xor ah, ah                            ; Because bpb_sectorPerCluster is 8 bits
  mov al, [bpb_sectorPerCluster]        ;
  mov si, ax                            ; Second argument for readDisk, how many sectors to read. The number of sectors in a cluster
  call readDisk
  test ax, ax                           ; Check if read had failed
  jnz readFile_error                    ; If failed then return 1

  ; Increment buffer pointer to point to the next location.
  ; buffer += bytesPerSector * sectorsPerCluster;
  mov ax, [bpb_bytesPerSector]          ; Set AX to the number of bytes in a sector
  xor bh, bh                            ; Because sectorPerCluster is 8 bits
  mov bl, [bpb_sectorPerCluster]        ; Set BX to the number of sectors in a cluster
  mul bx                                ; Multiply AX (bytesPerSector) by BX (secotrsPerCluster) and get result in AX
  add [bp - 4], ax                      ; Increase buffer by the result

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;
  mov ax, [bp - 8]                      ; Set AX to the cluster number
  mov bx, [bpb_bytesPerSector]          ; Set BX to the number of bytes in a sector
  xor dx, dx                            ; Zero out remainder
  div bx                                ; Divibe the cluster number by the number of bytes in a sector

  mov di, [bpb_reservedSectors]         ; DI = reservedSectors  // first sector of FAT
  add di, ax                            ; Offset the first cluster of FAT by the result of the division. 
                                        ; Using DI as argument for readDIsk

  mov [bp - 2], dx                      ; Store the FAT index at *(bp - 2)

  ; Check if the new calculated LBA is the same as the previouse one.
  ; If its not the same then load a new FAT sector into memory. Doing this check prevents reading the same FAT each time
  cmp di, [bp - 12]                           ; DI is the new LBA, *(bp - 12) is the previous one
  je readFile_getCluster                      ; If they are the same then skip loading a new sector

  ; Read a new sector of FAT into memory
  mov [bp - 12], di                           ; Update the previous LBA
  mov si, 1                                   ; Read 1 sector
  mov bx, ss                                  ; ES:BX points to receiving data buffer
  mov es, bx                                  ; SS because using the stack to store the data
  mov bx, sp                                  ; Stack pointer is at allocated space
  call readDisk
  test ax, ax                                 ; Check if read has failed
  jnz readFile_error                          ; If failed then return 1

  ; Get the next cluster number
readFile_getCluster:
  mov di, sp                                  ; SP points to FAT
  mov si, [bp - 2]                            ; *(bp - 2) is the FAT index
  shl si, 1                                   ; Because each cluster number is 2 bytes, multiply by 2
  add di, si                                  ; Make DI point to next cluster number
  mov di, ss:[di]                             ; DI = Next cluster number
  mov [bp - 8], di                            ; Store the cluster number at *(bp - 8)
  cmp di, 0FFF8h                              ; Check for end of cluster chain
  jb readFile_processClusterChain             ; If its not the end of the cluster chain then continue reading clusters
  
  xor ax, ax                                  ; Read was successful, return 0
readFile_end:
  ; Set segments to original value
  mov dx, [bp - 6]                            ; ES segment original value
  mov es, dx                                  ;
  mov dx, [bp - 10]                           ; Data segment original value
  mov ds, dx                                  ;

  mov sp, bp
  pop bp
  ret

readFile_error:
  mov ax, 1                               ; Read has failed, return 1
  jmp readFile_end


%endif