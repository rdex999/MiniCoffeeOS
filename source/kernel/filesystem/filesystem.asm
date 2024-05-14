;
;   ---------- [ FUNCTIONS FOR THE FILESYSTEM ] ----------
;

%ifndef FILESYSTEM_ASM
%define FILESYSTEM_ASM

%include "bootloader/macros/getRegions.asm"
%include "kernel/filesystem/getFileEntry.asm"
%include "kernel/filesystem/getNextCluster.asm"
%include "kernel/filesystem/getFreeCluster.asm"
%include "kernel/filesystem/skipClusters.asm"
%include "kernel/filesystem/addClusters.asm"
%include "kernel/filesystem/setCluster.asm"
%include "kernel/filesystem/createFile.asm"
%include "kernel/filesystem/fopen.asm"
%include "kernel/filesystem/fclose.asm"
%include "kernel/filesystem/fread.asm"
%include "kernel/filesystem/fwrite.asm"
%include "kernel/filesystem/remove.asm"
%include "kernel/filesystem/readClusterBytes.asm"
%include "kernel/filesystem/writeClusterBytes.asm"
%include "kernel/filesystem/readRootDirBytes.asm"
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
  push ds                               ; Set DS to kernel segment so we can read correct values
  mov bx, KERNEL_SEGMENT                ;
  mov ds, bx                            ;

  mov ax, di                            ; Get LBA
  mov bx, ds:[bpb_sectorsPerTrack]      ; LBA / sectorsPerTrack
  xor dx, dx                            ;
  div bx                                ; AX = AX / BX ;; DX = %

  inc dx                                ;
  mov cl, dl                            ; sector = (LBA % sectorsPerTrack) + 1

  ; AX containes LBA/sectorsPerTrack
  mov bx, ds:[bpb_numberOfHeadsOrSides] ;
  xor dx, dx                            ;
  div bx                                ;
  mov dh, dl                            ; head = (LBA / sectorsPerTrack) % heads

  mov ch, al                            ; cylinder = (LBA / sectorsPerTrack) / heads

  pop ds                                ; Restore old DS
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


; Write sectors to an LBA address
; PARAMS
;   - 0) DI     => LBA address to write to
;   - 1) DS:SI  => Buffer, the data to write to the LBA
;   - 2) DX     => Amount of sectors to write
writeDisk:
  push gs                           ; Save used segments
  push es                           ; ES is used as the buffer for INT13h/AH=3
  mov bx, KERNEL_SEGMENT            ; Set GS to the kernel segment so we read correct values
  mov gs, bx                        ;

  mov bx, ds                        ; ES is used as the buffer for INT13h/AH=3
  mov es, bx                        ; So set it to the arguments buffer segment

  push si                           ; Save arguments buffer offset
  push dx                           ; Save amount of sectors to write
  call lbaToChs                     ; Convert the LBA address (which is in DI) to a CHS address
  pop ax                            ; Restore amount of sectors to write, into AL
  pop bx                            ; Restore argument buffer offset, into BX
  mov dl, gs:[ebpb_driveNumber]     ; Get the drive number

  mov ah, 3                         ; Interrupt number 
  int 13h                           ; Write sectors from ES:BX into the CHS address
  jc .err                           ; If there was an error then we set AX to ERR_WRITE_DISK and return

  xor ax, ax
.end:
  pop es                            ; Restore used segments
  pop gs                            ;
  ret

.err:
  mov ax, ERR_WRITE_DISK            ; Set error code
  jmp .end                          ; Return


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



; Get the amountof clusters in a cluster chain
; PARAMS
;   - 0) DI   => First cluster number
; RETURNS
;   - 0) In AX, the amount of clusters in the cluster chain. Can return 0 if an error occurs
countClusters:
  push bp                       ; Save stack frame
  mov bp, sp                    ;

  xor ax, ax                    ; Zero out clusters counter
.cntLoop:
  cmp di, FAT_CLUSTER_INVALID   ; Check if the current cluster is valid
  jae .end                      ; If not, return with the clusters counter

  push ax                       ; Save clusters counter
  call getNextCluster           ; Get the next cluster in the chain
  test bx, bx                   ; Check error code
  jnz .err                      ; If there was an error, return 0

  mov di, ax                    ; Get the next cluster in DI
  pop ax                        ; Restore clusters counter
  inc ax                        ; Increment it
  jmp .cntLoop                  ; Continue counting clusters

.end:
  mov sp, bp                    ; Restore stack frame
  pop bp                        ;
  ret

.err:
  xor ax, ax                    ; If there is an error, return 0
  jmp .end                      ; Return

%endif