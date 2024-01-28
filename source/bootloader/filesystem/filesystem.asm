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
  pusha                         ; push all registers because BIOS messes them up
  push bx                       ; save data buffer
  call lbaToChs                 ; convert LBA from DI to CHS
  mov ax, si                    ; AL = number of sectors to read
  mov ah, 2                     ; read interrupt number
  mov dl, [ebpb_driveNumber]    ; get drive number
  pop bx                        ; restore data buffer
  int 13h                       ; read!
  popa                          ; restore all registers
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
  ;mov si, ax                        ; save in SI for now
  push ax 
  GET_DATA_REGION_OFFSET            ; get data region first sector in AX
  ;add ax, si                        ; add to result
  pop bx
  add ax, bx 
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

  sub sp, 6                 ; allocate 4 bytes
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

  add bx, 32

  dec ax                              ; decrement entries counter
  jnz readFile_searchFileLoop

  mov ax, 1                           ; could not find file
  mov sp, bp
  pop bp
  ret

readFile_foundFile:
  mov di, [di - 11 + 26]              ; get low 16 bits of entries first cluster number (26 is the offset and -11 because filename)


end:
  mov sp, bp
  pop bp 
  ret

%endif