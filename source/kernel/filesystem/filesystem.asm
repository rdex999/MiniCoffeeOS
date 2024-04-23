;
;   ---------- [ FUNCTIONS FOR THE FILESYSTEM ] ----------
;

%ifndef FILESYSTEM_ASM
%define FILESYSTEM_ASM

%include "bootloader/macros/getRegions.asm"
%include "kernel/filesystem/getFileEntry.asm"
%include "kernel/filesystem/fopen.asm"
%include "kernel/filesystem/fclose.asm"
%include "kernel/filesystem/fread.asm"
%include "kernel/filesystem/readClusterBytes.asm"
; %include "kernel/filesystem/readFile.asm"
; %include "kernel/filesystem/searchInRootDir.asm"
%include "kernel/filesystem/parsePath.asm"
%include "kernel/filesystem/getFullPath.asm"
; %include "kernel/filesystem/readClusterChain.asm"

; Converts LBA (Logical Block Address) to CHS (Cylinder Head Sector)
; PARAMS
;   - 1) DI => LBA address
; RETURNS
;   - CH => cylinder
;   - CL => sector
;   - DH => head
lbaToChs:
  mov ax, di                      ;
  mov bx, ds:[bpb_sectorsPerTrack]   ; LBA / sectorsPerTrack
  xor dx, dx                      ;
  div bx                          ; AX = AX / BX ;; DX = %

  inc dx                          ;
  mov cl, dl                      ; sector = (LBA % sectorsPerTrack) + 1

  ; AX containes LBA/sectorsPerTrack
  mov bx, ds:[bpb_numberOfHeadsOrSides]    ;
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
;   In AX => 0 on success, and an error code otherwise
readDisk:
  push ds
  mov ax, KERNEL_SEGMENT
  mov ds, ax

  push bx                       ; save data buffer
  call lbaToChs                 ; convert LBA from DI to CHS
  mov ax, si                    ; AL = number of sectors to read
  mov ah, 2                     ; read interrupt number
  mov dl, ds:[ebpb_driveNumber]    ; get drive number
  pop bx                        ; restore data buffer
  pop ds
  int 13h                       ; read!
  jc readDisk_error             ; Jump if int13h/AH=2 has failed
  
  xor ax, ax                    ; Read was successful, return 0
  ret

readDisk_error:
  mov ax, ERR_READ_DISK         ; Read has failed, return error
  ret


; converts a cluster number to LBA address
; PARAMS
;   - 0) DI   => cluster address
; RETURNS
;   returns in AX the LBA address
clusterToLBA:                       ; LBA = dataRegionOffset + (cluster - 2) * sectorsPerCluster
  push ds
  mov bx, KERNEL_SEGMENT
  mov ds, bx 
  
  sub di, 2                         ; DI = cluster - 2
  mov ax, di                        ; AX = cluster - 2
  xor bh, bh
  mov bl, ds:[bpb_sectorPerCluster]    ;
  mul bx                            ; AX *= sectorsPerCluster
  push ax                           ; Save for now
  GET_DATA_REGION_OFFSET            ; Get data region first sector in AX
  pop bx
  add ax, bx                        ; add to result

  pop ds
  ret


%endif