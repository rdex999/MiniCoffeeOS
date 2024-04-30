;
; ---------- [ SET THE VALUE OF A CLUSTER IN FAT ] ---------
;

%ifndef SET_CLUSTER_ASM
%define SET_CLUSTER_ASM

; Set a clusters value in FAT.
; PARAMS
;   - 0) DI   => The current cluster
;   - 1) SI   => The value to set the cluster to
; RETURNS
;   - 0) In AX, the error code
setCluster:
  push bp                                 ; Save stack frame
  mov bp, sp                              ;
  sub sp, 8                               ; Allocate space for local stuff

  mov [bp - 2], es                        ; Save old ES
  mov [bp - 6], si                        ; Save value to set the cluster to

  mov bx, KERNEL_SEGMENT                  ; Set DS to kernel segment so we can access stuff
  mov es, bx                              ;

  ; Calculate the sector offset to read. Basically means that instead of reading lots of sectors, just read the one that is needed.
  ; sectorOffset = cluster / bytesPerSector;
  ; clusterIndex = cluster % bytesPerSector;
  mov ax, di                              ; Get cluster in AX
  mov bx, es:[bpb_bytesPerSector]         ; Size of a sector
  xor dx, dx                              ; Zero out remainder
  div bx                                  ; Divide the cluster number by the size of a sector

  sub sp, bx                              ; BX is set to the size of a sector, allocate space for 1 sector
  mov [bp - 4], sp                        ; Save the sector buffer offset

  mov di, es:[bpb_reservedSectors]        ; Get the LBA of the FAT
  add di, ax                              ; Add to it the sector offset
  mov [bp - 8], di                        ; Save the LBA of the sector containing the cluster number

  mov si, 1                               ; Set amount of sectors to read

  mov bx, ss                              ; Set ES to the stack segment, because the sector buffer is stored on the stack
  mov es, bx                              ; 
  mov bx, sp                              ; Set sector buffer offset
  push dx                                 ; Save cluster index in sector
  call readDisk                           ; Read the sector from FAT into the sector buffer
  pop dx                                  ; Restore cluster index in sector

  test ax, ax                             ; Check error code of readDisk
  jnz .end                                ; If there was an error, return with it as the error code

  shl dx, 1                               ; Multiply cluster index by 2, because each cluster is 2 bytes
  mov si, [bp - 4]                        ; Get a pointer to the sector buffer
  add si, dx                              ; Add to it the index

  mov ax, [bp - 6]                        ; Get the requested value for the cluster
  mov ss:[si], ax                         ; Set it

  push ds
  mov bx, ss                              ; Set DS:SI to point to the sector buffer (the source, from where to write the data)
  mov ds, bx                              ; Set segment
  mov si, [bp - 4]                        ; Set offset

  mov di, [bp - 8]                        ; Get the LBA off the sector we want to write into

  mov dx, 1                               ; Set amount of sectors to write
  call writeDisk                          ; Write out changes to the sector into the hard disk
  pop ds
  ; If writeDisk has returned an error, we return it as the error code

.end:
  mov es, [bp - 2]
  mov sp, bp
  pop bp
  ret


%endif